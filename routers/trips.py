from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field

import push
from auth import get_current_user_id
from database import supabase
from formatting import (
    budget_amounts,
    budget_text,
    duration_text,
    group_id_for,
    is_uuid,
    long_range,
    parse_date,
    parse_date_range,
)
from queries import (
    accepted_trip_ids,
    display_name,
    fetch_profiles,
    require_accepted_member,
    require_uuid,
)

router = APIRouter(prefix="/api/trips", tags=["trips"])


class TripIn(BaseModel):
    """The Trip JSON the Flutter app sends (see lib/models/trip.dart -> toJson)."""

    model_config = ConfigDict(extra="ignore")

    id: str | None = None
    destination: str = ""
    date_range: str = ""
    duration: str = ""
    budget: str = ""
    image_url: str = ""
    status: str | None = None
    generated_from_group_chat: bool = False
    traveller_count: int = Field(default=1, ge=1)
    minimum_budget: float | None = None
    planned_budget: float | None = None
    origin_city: str | None = None
    estimated_budget: float | None = None
    budget_breakdown: dict[str, float] | None = None
    booked_item_ids: list[str] = []
    collaborators: list[dict] = []


class BookedItemsIn(BaseModel):
    item_ids: list[str] = []


# ---------- helpers ------------------------------------------------------
def trip_json(t: dict, collaborators: list[dict] | None = None) -> dict:
    """One trips row -> the Trip JSON the Flutter model reads."""
    start, end = parse_date(t.get("start_date")), parse_date(t.get("end_date"))
    low, high = t.get("budget_min"), t.get("budget_max")
    return {
        "id": t["id"],
        "destination": t["destination"],
        "date_range": long_range(start, end),
        "duration": duration_text(start, end),
        "budget": budget_text(high, t.get("currency")),
        "image_url": t.get("image_url") or "",
        "status": t["status"],
        "generated_from_group_chat": t.get("generated_from_group_chat", False),
        "traveller_count": t.get("traveller_count") or 1,
        "minimum_budget": float(low if low is not None else (high or 0)),
        "planned_budget": float(high if high is not None else (low or 0)),
        "origin_city": t.get("origin_city"),
        "estimated_budget": float(t["estimated_budget"]) if t.get("estimated_budget") is not None else None,
        "budget_breakdown": t.get("budget_breakdown"),
        "booked_item_ids": t.get("booked_item_ids") or [],
        "collaborators": collaborators or [],
    }


def _collaborators_by_trip(trip_ids: list[str], me: str) -> dict[str, list[dict]]:
    """People on each trip other than the signed-in user (Trip.collaborators)."""
    if not trip_ids:
        return {}
    members = (
        supabase.table("trip_members")
        .select("trip_id,user_id")
        .in_("trip_id", trip_ids)
        .execute()
        .data
    )
    profiles = fetch_profiles([m["user_id"] for m in members])
    result: dict[str, list[dict]] = {tid: [] for tid in trip_ids}
    for m in members:
        p = profiles.get(m["user_id"])
        if p and m["user_id"] != me:
            result[m["trip_id"]].append(
                {
                    "id": p["id"],
                    "name": display_name(p),
                    "email": p["email"],
                    "avatarUrl": p["avatar_url"],
                    "isAdded": True,
                }
            )
    return result


def _load_trip(trip_id: str, me: str) -> dict:
    """A trip the user belongs to, as Trip JSON, or 404."""
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    rows = supabase.table("trips").select("*").eq("id", trip_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip_json(rows[0], _collaborators_by_trip([trip_id], me)[trip_id])


def _row_from_body(body: TripIn) -> dict:
    start, end = parse_date_range(body.date_range)
    amounts = budget_amounts(body.budget)
    low = body.minimum_budget
    high = body.planned_budget
    if high is None and amounts:
        high = amounts[-1]
    if low is None and amounts:
        low = amounts[0]
    row = {
        "destination": body.destination,
        "start_date": start.isoformat() if start else None,
        "end_date": end.isoformat() if end else None,
        "budget_min": low,
        "budget_max": high,
        "image_url": body.image_url,
        "traveller_count": body.traveller_count,
        "generated_from_group_chat": body.generated_from_group_chat,
        "origin_city": body.origin_city,
        "estimated_budget": body.estimated_budget,
        "budget_breakdown": body.budget_breakdown,
        "booked_item_ids": body.booked_item_ids,
    }
    return row


def _invite_collaborators(trip_id: str, collaborators: list[dict]) -> bool:
    """Adds each collaborator as an invited member. Returns True if the trip has any."""
    wanted = [c.get("id") for c in collaborators if is_uuid(c.get("id"))]
    if not wanted:
        return False
    known = fetch_profiles(wanted)
    existing = {
        r["user_id"]
        for r in supabase.table("trip_members").select("user_id").eq("trip_id", trip_id).execute().data
    }
    new_rows = [
        {"trip_id": trip_id, "user_id": uid, "role": "Member", "status": "invited"}
        for uid in known
        if uid not in existing
    ]
    if new_rows:
        supabase.table("trip_members").insert(new_rows).execute()
        _push_invites(trip_id, [r["user_id"] for r in new_rows])
    return True


def _push_invites(trip_id: str, invited: list[str]) -> None:
    if not push.configured():
        return
    try:
        trip = supabase.table("trips").select("host_id,title,destination").eq("id", trip_id).execute().data
        if not trip:
            return
        host = display_name(fetch_profiles([trip[0]["host_id"]]).get(trip[0]["host_id"], {}))
        place = trip[0].get("title") or trip[0].get("destination") or "a trip"
        push.notify(invited, "Trip invitation", f"{host} invited you to {place}.", kind="trip", trip_id=trip_id)
    except Exception as e:
        print(f"[push] {e}")


def _save_trip(body: TripIn, me: str, new_status: str) -> dict:
    """Create or update a trip from the Flutter Trip JSON (shared by draft and confirm)."""
    row = _row_from_body(body)
    has_collaborators = bool(body.collaborators)

    existing = []
    if body.id and is_uuid(body.id):
        existing = supabase.table("trips").select("*").eq("id", body.id).eq("host_id", me).execute().data

    if existing:
        trip_id = existing[0]["id"]
        # a draft save must never demote a trip that is already confirmed or finished
        status = new_status if new_status == "upcoming" or existing[0]["status"] == "draft" else existing[0]["status"]
        if has_collaborators or body.generated_from_group_chat:
            row["trip_type"] = "group"
        supabase.table("trips").update({**row, "status": status}).eq("id", trip_id).execute()
    else:
        row.update(
            {
                "host_id": me,
                "status": new_status,
                "trip_type": "group" if (has_collaborators or body.generated_from_group_chat) else "solo",
                "title": "",
            }
        )
        trip_id = supabase.table("trips").insert(row).execute().data[0]["id"]
        supabase.table("trip_members").upsert(
            {"trip_id": trip_id, "user_id": me, "role": "Host", "status": "accepted"},
            on_conflict="trip_id,user_id",
        ).execute()

    _invite_collaborators(trip_id, body.collaborators)
    return _load_trip(trip_id, me)


# ---------- endpoints ----------------------------------------------------
@router.get("")
def list_trips(user_id: str = Depends(get_current_user_id)):
    """TripService.getTrips: every trip the user is on (drafts, upcoming, completed)."""
    ids = accepted_trip_ids(user_id)
    if not ids:
        return []
    trips = supabase.table("trips").select("*").in_("id", ids).order("created_at", desc=True).execute().data
    collabs = _collaborators_by_trip([t["id"] for t in trips], user_id)
    return [trip_json(t, collabs[t["id"]]) for t in trips]


@router.get("/upcoming")
def get_upcoming_trip(user_id: str = Depends(get_current_user_id)):
    """TripService.getUpcomingTrip: the next confirmed trip that has not ended."""
    ids = accepted_trip_ids(user_id)
    rows = []
    if ids:
        rows = (
            supabase.table("trips")
            .select("*")
            .in_("id", ids)
            .eq("status", "upcoming")
            .gte("end_date", date.today().isoformat())
            .order("start_date")
            .limit(1)
            .execute()
            .data
        )
    if not rows:
        raise HTTPException(status_code=404, detail="No upcoming trip")
    return trip_json(rows[0], _collaborators_by_trip([rows[0]["id"]], user_id)[rows[0]["id"]])


@router.post("/draft")
def save_draft(body: TripIn, user_id: str = Depends(get_current_user_id)):
    """TripService.saveDraft. Returns the saved trip, including its real id."""
    return _save_trip(body, user_id, "draft")


@router.post("/confirm")
def confirm_trip(body: TripIn, user_id: str = Depends(get_current_user_id)):
    """TripService.confirmTrip: saves the trip and marks it 'upcoming'."""
    return _save_trip(body, user_id, "upcoming")


@router.get("/{trip_id}")
def get_trip(trip_id: str, user_id: str = Depends(get_current_user_id)):
    """TripService.getTrip."""
    return _load_trip(trip_id, user_id)


@router.delete("/{trip_id}")
def delete_trip(trip_id: str, user_id: str = Depends(get_current_user_id)):
    """Deletes a trip that will not go ahead (draft or upcoming), for everyone.
    Only the host can. Members, chat, polls, votes, expenses, itinerary and every
    other row that belongs to the trip are removed with it (database cascade)."""
    trip_id = require_uuid(trip_id, "trip id")
    rows = supabase.table("trips").select("host_id,status").eq("id", trip_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Trip not found")
    if rows[0]["host_id"] != user_id:
        raise HTTPException(status_code=403, detail="Only the host can delete this trip")
    if rows[0]["status"] == "completed":
        raise HTTPException(status_code=409, detail="A completed trip is kept for its memories")
    supabase.table("trips").delete().eq("id", trip_id).execute()
    return {"ok": True}


@router.put("/{trip_id}/booked-items")
def save_booked_items(trip_id: str, body: BookedItemsIn, user_id: str = Depends(get_current_user_id)):
    """TripService.saveBookedItemIds."""
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, user_id)
    supabase.table("trips").update({"booked_item_ids": body.item_ids}).eq("id", trip_id).execute()
    return _load_trip(trip_id, user_id)


class GroupChatIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    memberIds: list[str] = Field(default_factory=list, max_length=50)


@router.post("/{trip_id}/group-chat")
def create_group_chat(
    trip_id: str, body: GroupChatIn | None = None, user_id: str = Depends(get_current_user_id)
):
    """ChatListService.createTripGroupChat: turns a trip into a group trip with a chat.

    memberIds (optional): people picked in "Add member"; they are invited to the trip.
    """
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, user_id)
    if body and body.memberIds:
        _invite_collaborators(trip_id, [{"id": m} for m in body.memberIds if m != user_id])
    rows = supabase.table("trips").select("destination,title").eq("id", trip_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Trip not found")
    changes = {"trip_type": "group"}
    if not rows[0].get("title"):
        dest = (rows[0].get("destination") or "").strip()
        changes["title"] = f"{dest} Group Chat" if dest else "New Group Trip"
    supabase.table("trips").update(changes).eq("id", trip_id).execute()
    return {"groupId": group_id_for(trip_id), "tripId": trip_id}


class DetailsIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    destination: str | None = None
    date_range: str | None = None
    budget_min: float | None = Field(default=None, ge=0, le=10_000_000)
    budget_max: float | None = Field(default=None, ge=0, le=10_000_000)


@router.patch("/{trip_id}/details")
def update_details(trip_id: str, body: DetailsIn, user_id: str = Depends(get_current_user_id)):
    """The group settles destination, dates and budget in the chat's Trip Summary.

    Only the host can change destination and dates, and only while it is a draft.
    The budget comes from each member's own input (see routers/planning.py).
    """
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, user_id)
    rows = supabase.table("trips").select("status,host_id").eq("id", trip_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Trip not found")
    if rows[0]["host_id"] != user_id:
        raise HTTPException(status_code=403, detail="Only the host can change the trip details")
    if rows[0]["status"] != "draft":
        raise HTTPException(status_code=409, detail="This trip is already confirmed, so its details are locked")
    changes: dict = {}
    if body.destination is not None:
        dest = " ".join(body.destination.split())
        if len(dest) > 80:
            raise HTTPException(status_code=422, detail="Destination is too long (80 characters max)")
        changes["destination"] = dest
    if body.date_range is not None:
        text = body.date_range.strip()
        if text:
            start, end = parse_date_range(text)
            if not start or not end:
                raise HTTPException(status_code=422, detail="Could not read those dates")
            changes["start_date"], changes["end_date"] = start.isoformat(), end.isoformat()
        else:
            changes["start_date"] = changes["end_date"] = None
    if changes:
        supabase.table("trips").update(changes).eq("id", trip_id).execute()
    return _load_trip(trip_id, user_id)
