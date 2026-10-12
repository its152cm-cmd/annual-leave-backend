from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException

import push
from auth import get_current_user_id
from database import supabase
from formatting import group_id_for, invitation_range, parse_date
from queries import display_name, fetch_profiles, require_uuid

router = APIRouter(prefix="/api/invitations", tags=["invitations"])


@router.get("")
def list_invitations(user_id: str = Depends(get_current_user_id)):
    """ChatListService.getPendingInvitations. The invitation id is the trip's id."""
    rows = (
        supabase.table("trip_members")
        .select("trip_id")
        .eq("user_id", user_id)
        .eq("status", "invited")
        .execute()
        .data
    )
    trip_ids = [r["trip_id"] for r in rows]
    if not trip_ids:
        return []

    trips = (
        supabase.table("trips")
        .select("id,title,destination,start_date,end_date,host_id")
        .in_("id", trip_ids)
        .execute()
        .data
    )
    hosts = fetch_profiles([t["host_id"] for t in trips])

    result = []
    for t in trips:
        host = hosts.get(t["host_id"])
        result.append(
            {
                "id": t["id"],
                "groupId": group_id_for(t["id"]),
                "hostName": display_name(host) if host else "",
                "hostAvatar": (host or {}).get("avatar_url") or "",
                "tripTitle": t["title"] or t["destination"],
                "destination": t["destination"],
                "dates": invitation_range(parse_date(t["start_date"]), parse_date(t["end_date"])),
            }
        )
    return result


def _respond(trip_id: str, user_id: str, changes: dict):
    trip_id = require_uuid(trip_id, "invitation id")
    updated = (
        supabase.table("trip_members")
        .update(changes)
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .eq("status", "invited")
        .execute()
        .data
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if push.configured() and changes.get("status") in ("accepted", "declined"):
        try:
            trip = supabase.table("trips").select("host_id,title,destination").eq("id", trip_id).execute().data
            if trip:
                who = display_name(fetch_profiles([user_id]).get(user_id, {}))
                place = trip[0].get("title") or trip[0].get("destination") or "the trip"
                verb = "joined" if changes["status"] == "accepted" else "declined the invitation to"
                push.notify([trip[0]["host_id"]], "Trip update", f"{who} {verb} {place}.", kind="trip", trip_id=trip_id)
        except Exception as e:
            print(f"[push] {e}")
    return {"success": True}


@router.post("/{invitation_id}/accept")
def accept_invitation(invitation_id: str, user_id: str = Depends(get_current_user_id)):
    return _respond(
        invitation_id,
        user_id,
        {"status": "accepted", "joined_at": datetime.now(timezone.utc).isoformat()},
    )


@router.post("/{invitation_id}/decline")
def decline_invitation(invitation_id: str, user_id: str = Depends(get_current_user_id)):
    return _respond(invitation_id, user_id, {"status": "declined"})
