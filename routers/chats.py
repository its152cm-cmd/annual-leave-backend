import base64
import binascii
import re
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

import push
from auth import get_current_user_id
from database import supabase
from formatting import group_id_for
from queries import display_name, fetch_profiles, require_accepted_member, require_uuid

router = APIRouter(prefix="/api/chats", tags=["chats"])


def _preview(msg: dict, user_id: str, profiles: dict) -> str:
    text = (msg["text"] or "").strip().replace("\n", " ")
    if msg.get("is_ai_response") or not msg.get("sender_id"):
        prefix = ""
    elif msg["sender_id"] == user_id:
        prefix = "You: "
    else:
        name = display_name(profiles.get(msg["sender_id"], {}))
        prefix = f"{name.split()[0]}: "
    preview = prefix + text
    return preview if len(preview) <= 50 else preview[:47].rstrip() + "..."


@router.get("")
def list_chats(user_id: str = Depends(get_current_user_id)):
    """ChatListService.getConversations: one row per group trip the user has joined.
    groupId is 'trip_<tripId>', exactly how the Flutter app builds it."""
    memberships = (
        supabase.table("trip_members")
        .select("trip_id,last_read_at")
        .eq("user_id", user_id)
        .eq("status", "accepted")
        .execute()
        .data
    )
    if not memberships:
        return []
    last_read = {m["trip_id"]: m["last_read_at"] for m in memberships}

    trips = (
        supabase.table("trips")
        .select("id,title,destination,image_url,created_at")
        .in_("id", list(last_read))
        .eq("trip_type", "group")
        .execute()
        .data
    )

    latest: dict[str, dict | None] = {}
    unread: dict[str, int] = {}
    for t in trips:
        tid = t["id"]
        newest = (
            supabase.table("chat_messages")
            .select("text,sender_id,is_ai_response,created_at")
            .eq("trip_id", tid)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
            .data
        )
        latest[tid] = newest[0] if newest else None

        since = (
            supabase.table("chat_messages")
            .select("sender_id")
            .eq("trip_id", tid)
            .gt("created_at", last_read[tid])
            .limit(500)
            .execute()
            .data
        )
        unread[tid] = sum(1 for m in since if m["sender_id"] != user_id)

    profiles = fetch_profiles([m["sender_id"] for m in latest.values() if m])

    chats = []
    for t in trips:
        tid = t["id"]
        msg = latest[tid]
        chats.append(
            {
                "groupId": group_id_for(tid),
                "tripId": tid,
                "title": t["title"] or t["destination"],
                "destination": t["destination"],
                "lastMessage": _preview(msg, user_id, profiles) if msg else "",
                "lastMessageTime": msg["created_at"] if msg else t["created_at"],
                "unreadCount": unread[tid],
                "avatarUrl": t["image_url"] or "",
                "isLiveSync": True,
            }
        )

    chats.sort(key=lambda c: c["lastMessageTime"], reverse=True)
    return chats


# ------------------------------------------------------------------ messages
class MessageIn(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    is_ai: bool = False


ATTACH_BUCKET = "trip-docs"
ATTACH_MAX = 10 * 1024 * 1024
IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
BLOCKED_EXT = {"exe", "bat", "cmd", "com", "scr", "msi", "js", "vbs", "jar", "sh", "ps1", "apk", "dll"}


def _chat_bucket():
    return supabase.storage.from_(ATTACH_BUCKET)


def _attachment_json(row: dict) -> dict:
    path = row.get("attachment_path")
    if not path:
        return {}
    url = ""
    try:
        signed = _chat_bucket().create_signed_url(path, 3600)
        url = (signed or {}).get("signedURL") or (signed or {}).get("signedUrl") or ""
    except Exception:
        url = ""
    return {"attachmentUrl": url, "attachmentSize": row.get("attachment_size")}


def _message_json(row: dict, me: str, profiles: dict) -> dict:
    ai = bool(row.get("is_ai_response")) or not row.get("sender_id")
    sender = row.get("sender_id")
    profile = profiles.get(sender, {}) if sender else {}
    return {
        "id": row["id"],
        "senderId": "ai_planner" if ai else sender,
        "senderName": "AI PLANNER \u2022 LIVE" if ai else display_name(profile),
        "senderAvatar": profile.get("avatar_url"),
        "text": row.get("text") or "",
        "timestamp": str(row.get("created_at")),
        "type": row.get("type") if row.get("type") in ("image", "file") else "text",
        "isAiResponse": ai,
        "isMine": (not ai) and sender == me,
        **_attachment_json(row),
    }


@router.get("/{trip_id}/messages")
def list_messages(trip_id: str, me: str = Depends(get_current_user_id)):
    """The group chat's saved messages, oldest first (last 500)."""
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    rows = (
        supabase.table("chat_messages")
        .select("*")
        .eq("trip_id", trip_id)
        .order("created_at", desc=True)
        .limit(500)
        .execute()
        .data
    )
    rows.reverse()
    profiles = fetch_profiles({r["sender_id"] for r in rows if r.get("sender_id")})
    return [_message_json(r, me, profiles) for r in rows]


@router.post("/{trip_id}/messages")
def send_message(trip_id: str, body: MessageIn, me: str = Depends(get_current_user_id)):
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=422, detail="Message is empty")
    row = (
        supabase.table("chat_messages")
        .insert(
            {
                "trip_id": trip_id,
                "sender_id": None if body.is_ai else me,
                "text": text,
                "type": "text",
                "is_ai_response": body.is_ai,
                "created_at": datetime.now(timezone.utc).isoformat(),
            }
        )
        .execute()
        .data[0]
    )
    # what you send is read by you
    supabase.table("trip_members").update({"last_read_at": row["created_at"]}).eq("trip_id", trip_id).eq("user_id", me).execute()
    if not body.is_ai:
        _push_message(trip_id, me, text)
    return _message_json(row, me, fetch_profiles([me]))


def _push_message(trip_id: str, me: str, text: str) -> None:
    """Tells the other members about a new message (only when Firebase is set up)."""
    if not push.configured():
        return
    try:
        others = [
            r["user_id"]
            for r in supabase.table("trip_members").select("user_id").eq("trip_id", trip_id).eq("status", "accepted").execute().data
            if r["user_id"] != me
        ]
        if not others:
            return
        trip = supabase.table("trips").select("title,destination").eq("id", trip_id).execute().data
        name = display_name(fetch_profiles([me]).get(me, {}))
        chat = (trip[0].get("title") or trip[0].get("destination") or "Group chat") if trip else "Group chat"
        push.notify(others, f"{name} · {chat}", text, kind="chat", trip_id=trip_id)
    except Exception as e:
        print(f"[push] {e}")


@router.get("/{trip_id}/unread")
def unread_count(trip_id: str, me: str = Depends(get_current_user_id)):
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    mine = supabase.table("trip_members").select("last_read_at").eq("trip_id", trip_id).eq("user_id", me).execute().data
    since = mine[0].get("last_read_at") if mine else None
    q = supabase.table("chat_messages").select("sender_id").eq("trip_id", trip_id)
    if since:
        q = q.gt("created_at", since)
    rows = q.limit(500).execute().data
    return {"unread": sum(1 for r in rows if r["sender_id"] != me)}


@router.post("/{trip_id}/read")
def mark_read(trip_id: str, me: str = Depends(get_current_user_id)):
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    supabase.table("trip_members").update({"last_read_at": datetime.now(timezone.utc).isoformat()}).eq("trip_id", trip_id).eq("user_id", me).execute()
    return {"ok": True}


class AttachmentIn(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    mimeType: str = ""
    dataBase64: str


@router.post("/{trip_id}/attachments")
def send_attachment(trip_id: str, body: AttachmentIn, me: str = Depends(get_current_user_id)):
    """Shares a photo or file with the group: stored privately, then posted as a chat message."""
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    name = re.sub(r"[^\w.\- ]", "_", body.name.strip().split("/")[-1].split("\\")[-1])[:120] or "file"
    ext = name.rsplit(".", 1)[-1].lower() if "." in name else ""
    if ext in BLOCKED_EXT:
        raise HTTPException(status_code=422, detail="This type of file cannot be shared")
    try:
        data = base64.b64decode(body.dataBase64, validate=False)
    except (binascii.Error, ValueError):
        raise HTTPException(status_code=422, detail="The file could not be read")
    if not data:
        raise HTTPException(status_code=422, detail="The file is empty")
    if len(data) > ATTACH_MAX:
        raise HTTPException(status_code=413, detail="The file is too large (10 MB max)")
    mime = body.mimeType.strip().lower()
    kind = "image" if mime in IMAGE_TYPES else "file"
    path = f"chat/{trip_id}/{uuid.uuid4().hex}-{name}"
    try:
        _chat_bucket().upload(path, data, {"content-type": mime or "application/octet-stream"})
    except Exception:
        raise HTTPException(status_code=502, detail="The file could not be uploaded. Please try again.")
    row = (
        supabase.table("chat_messages")
        .insert(
            {
                "trip_id": trip_id,
                "sender_id": me,
                "text": name,
                "type": kind,
                "is_ai_response": False,
                "attachment_path": path,
                "attachment_size": len(data),
                "created_at": datetime.now(timezone.utc).isoformat(),
            }
        )
        .execute()
        .data[0]
    )
    supabase.table("trip_members").update({"last_read_at": row["created_at"]}).eq("trip_id", trip_id).eq("user_id", me).execute()
    return _message_json(row, me, fetch_profiles([me]))


# ------------------------------------------------------------ members and name
@router.get("/{trip_id}/members")
def chat_members(trip_id: str, me: str = Depends(get_current_user_id)):
    """People on the trip. status is 'accepted' or 'invited' (waiting for an answer)."""
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    rows = (
        supabase.table("trip_members")
        .select("user_id,role,status,joined_at")
        .eq("trip_id", trip_id)
        .in_("status", ["accepted", "invited"])
        .execute()
        .data
    )
    rows.sort(key=lambda r: (r.get("role") != "Host", str(r.get("joined_at"))))
    profiles = fetch_profiles([r["user_id"] for r in rows])
    trip = supabase.table("trips").select("title,destination").eq("id", trip_id).execute().data
    title = ((trip[0].get("title") or trip[0].get("destination") or "") if trip else "")
    return {
        "title": title,
        "members": [
            {
                "id": r["user_id"],
                "name": display_name(profiles.get(r["user_id"], {})),
                "role": r.get("role") or "Member",
                "avatarUrl": (profiles.get(r["user_id"]) or {}).get("avatar_url"),
                "isMe": r["user_id"] == me,
                "status": r["status"],
            }
            for r in rows
        ]
    }


class RenameIn(BaseModel):
    title: str = Field(min_length=1, max_length=80)


@router.patch("/{trip_id}")
def rename_chat(trip_id: str, body: RenameIn, me: str = Depends(get_current_user_id)):
    """Any member can rename the group chat. The name is saved, so it stays after refreshing or signing out."""
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    title = " ".join(body.title.split())
    if not title:
        raise HTTPException(status_code=422, detail="Please type a name")
    supabase.table("trips").update({"title": title}).eq("id", trip_id).execute()
    return {"title": title}


@router.delete("/{trip_id}/members/{member_id}")
def remove_member(trip_id: str, member_id: str, me: str = Depends(get_current_user_id)):
    """The host removes a member (or cancels an invitation)."""
    trip_id = require_uuid(trip_id, "trip id")
    member_id = require_uuid(member_id, "member id")
    require_accepted_member(trip_id, me)
    host = supabase.table("trips").select("host_id").eq("id", trip_id).execute().data
    if not host or host[0]["host_id"] != me:
        raise HTTPException(status_code=403, detail="Only the host can remove members")
    if member_id == me:
        raise HTTPException(status_code=400, detail="The host cannot be removed")
    supabase.table("trip_members").delete().eq("trip_id", trip_id).eq("user_id", member_id).execute()
    return {"success": True}
