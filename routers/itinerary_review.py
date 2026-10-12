"""Group itinerary review: everyone can view, react (agree/disagree), comment and ask the group; only the host edits."""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from auth import get_current_user_id
from database import supabase
from queries import fetch_profiles, display_name, require_accepted_member, require_uuid
from routers.chat_polls import create_poll, open_polls

router = APIRouter(prefix="/api/itinerary/{trip_id}/review", tags=["itinerary-review"])

OPTIONS = ["Keep it", "Change it", "Remove it"]


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _trip(trip_id: str, me: str) -> tuple[str, dict, list[dict]]:
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    rows = supabase.table("trips").select("*").eq("id", trip_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Trip not found")
    members = supabase.table("trip_members").select("user_id,role").eq("trip_id", trip_id).eq("status", "accepted").execute().data
    return trip_id, rows[0], members


def current_items(trip_id: str) -> dict[str, dict]:
    """item key (the id the app sees) -> {title, day}"""
    its = supabase.table("itineraries").select("id").eq("trip_id", trip_id).execute().data
    if not its:
        return {}
    days = supabase.table("itinerary_days").select("id,day_number").eq("itinerary_id", its[0]["id"]).execute().data
    out = {}
    for d in days:
        for r in supabase.table("itinerary_items").select("*").eq("day_id", d["id"]).execute().data:
            key = (r.get("source_data") or {}).get("client_id") or r["id"]
            out[str(key)] = {"title": r.get("title") or "", "day": d["day_number"]}
    return out


def _require_item(trip_id: str, key: str) -> dict:
    item = current_items(trip_id).get(key)
    if not item:
        raise HTTPException(status_code=404, detail="That item is no longer in the itinerary")
    return item


@router.get("")
def get_review(trip_id: str, me: str = Depends(get_current_user_id)):
    trip_id, trip, members = _trip(trip_id, me)
    keys = set(current_items(trip_id))
    out = {}
    for r in supabase.table("itinerary_reactions").select("*").eq("trip_id", trip_id).execute().data:
        if r["item_key"] in keys:
            out.setdefault(r["item_key"], {"agree": [], "disagree": [], "comments": 0})[r["vote"]].append(r["user_id"])
    for c in supabase.table("itinerary_comments").select("item_key").eq("trip_id", trip_id).execute().data:
        if c["item_key"] in keys:
            out.setdefault(c["item_key"], {"agree": [], "disagree": [], "comments": 0})["comments"] += 1
    profiles = fetch_profiles({m["user_id"] for m in members})
    return {
        "isHost": trip.get("host_id") == me,
        "isGroup": len(members) > 1,
        "status": trip.get("status"),
        "me": me,
        "members": [
            {"id": m["user_id"], "name": display_name(profiles.get(m["user_id"]) or {}) if profiles.get(m["user_id"]) else "Member"}
            for m in members
        ],
        "items": out,
    }


class VoteIn(BaseModel):
    vote: str


@router.post("/items/{key}/vote")
def vote(trip_id: str, key: str, body: VoteIn, me: str = Depends(get_current_user_id)):
    trip_id, _, _ = _trip(trip_id, me)
    if body.vote not in ("agree", "disagree"):
        raise HTTPException(status_code=422, detail="vote must be agree or disagree")
    _require_item(trip_id, key)
    mine = supabase.table("itinerary_reactions").select("vote").eq("trip_id", trip_id).eq("item_key", key).eq("user_id", me).execute().data
    if mine and mine[0]["vote"] == body.vote:  # same tap again removes the vote
        supabase.table("itinerary_reactions").delete().eq("trip_id", trip_id).eq("item_key", key).eq("user_id", me).execute()
        return {"vote": None}
    supabase.table("itinerary_reactions").upsert(
        {"trip_id": trip_id, "item_key": key, "user_id": me, "vote": body.vote, "updated_at": _now()},
        on_conflict="trip_id,item_key,user_id",
    ).execute()
    return {"vote": body.vote}


class CommentIn(BaseModel):
    text: str


def _comment_json(c: dict, profiles: dict, me: str, host_id) -> dict:
    p = profiles.get(c["user_id"])
    return {
        "id": c["id"], "userId": c["user_id"], "name": display_name(p) if p else "Member",
        "text": c["text"], "createdAt": str(c["created_at"]),
        "canDelete": c["user_id"] == me or host_id == me,
    }


@router.get("/items/{key}/comments")
def list_comments(trip_id: str, key: str, me: str = Depends(get_current_user_id)):
    trip_id, trip, _ = _trip(trip_id, me)
    rows = supabase.table("itinerary_comments").select("*").eq("trip_id", trip_id).eq("item_key", key).execute().data
    rows.sort(key=lambda c: str(c["created_at"]))
    profiles = fetch_profiles({c["user_id"] for c in rows})
    return [_comment_json(c, profiles, me, trip.get("host_id")) for c in rows]


@router.post("/items/{key}/comments")
def add_comment(trip_id: str, key: str, body: CommentIn, me: str = Depends(get_current_user_id)):
    trip_id, trip, _ = _trip(trip_id, me)
    text = " ".join(body.text.split())
    if not text:
        raise HTTPException(status_code=422, detail="Write a comment first")
    if len(text) > 500:
        raise HTTPException(status_code=422, detail="Comments can be up to 500 characters")
    _require_item(trip_id, key)
    row = supabase.table("itinerary_comments").insert(
        {"trip_id": trip_id, "item_key": key, "user_id": me, "text": text, "created_at": _now()}
    ).execute().data[0]
    return _comment_json(row, fetch_profiles({me}), me, trip.get("host_id"))


@router.delete("/comments/{comment_id}")
def delete_comment(trip_id: str, comment_id: str, me: str = Depends(get_current_user_id)):
    trip_id, trip, _ = _trip(trip_id, me)
    rows = supabase.table("itinerary_comments").select("*").eq("trip_id", trip_id).eq("id", comment_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Comment not found")
    if rows[0]["user_id"] != me and trip.get("host_id") != me:
        raise HTTPException(status_code=403, detail="You can only delete your own comments")
    supabase.table("itinerary_comments").delete().eq("id", comment_id).execute()
    return {"ok": True}


@router.post("/items/{key}/poll")
def ask_group(trip_id: str, key: str, me: str = Depends(get_current_user_id)):
    """Pins a poll in the group chat about one itinerary item."""
    trip_id, _, members = _trip(trip_id, me)
    if len(members) < 2:
        raise HTTPException(status_code=422, detail="Polls are for group trips")
    item = _require_item(trip_id, key)
    title = " ".join(item["title"].split())[:60] or "this stop"
    question = f'Keep "{title}" on Day {item["day"]}?'
    existing = open_polls(trip_id)
    if any(p["question"].strip().lower() == question.lower() for p in existing):
        raise HTTPException(status_code=409, detail="The group is already voting on this item")
    poll = create_poll(trip_id, question, OPTIONS, "decision",
                       f'I pinned a poll in the chat: {question}')
    return {"pollId": poll["id"], "question": question}
