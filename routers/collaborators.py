import re

from fastapi import APIRouter, Depends

from auth import get_current_user_id
from database import supabase
from queries import accepted_trip_ids, display_name, fetch_profiles, require_uuid

router = APIRouter(prefix="/api/collaborators", tags=["collaborators"])


def _to_json(profile: dict, is_added: bool) -> dict:
    return {
        "id": profile["id"],
        "name": display_name(profile),
        "email": profile["email"],
        "avatarUrl": profile["avatar_url"],
        "isAdded": is_added,
    }


def _member_ids(trip_id: str) -> set[str]:
    rows = (
        supabase.table("trip_members")
        .select("user_id")
        .eq("trip_id", trip_id)
        .execute()
        .data
    )
    return {r["user_id"] for r in rows}


@router.get("")
def list_collaborators(
    trip_id: str | None = None, user_id: str = Depends(get_current_user_id)
):
    """CollaboratorService.getCollaborators.

    With ?trip_id=...  -> the people already on that trip (isAdded = true).
    Without trip_id    -> people the user has travelled with before (isAdded = false).
    """
    if trip_id:
        ids = _member_ids(require_uuid(trip_id, "trip id")) - {user_id}
        added = True
    else:
        mine = accepted_trip_ids(user_id)
        ids = set()
        if mine:
            rows = (
                supabase.table("trip_members")
                .select("user_id")
                .in_("trip_id", mine)
                .eq("status", "accepted")
                .execute()
                .data
            )
            ids = {r["user_id"] for r in rows} - {user_id}
        added = False

    profiles = fetch_profiles(ids)
    return [_to_json(p, added) for p in profiles.values()]


@router.get("/search")
def search_collaborators(
    q: str = "",
    trip_id: str | None = None,
    user_id: str = Depends(get_current_user_id),
):
    """CollaboratorService.searchCollaborators: find users by name or email."""
    # strip characters that have a special meaning inside the filter string
    q = re.sub(r"[,()%*\\]", " ", q).strip()
    if not q:
        return []

    rows = (
        supabase.table("profiles")
        .select("id,full_name,email,avatar_url")
        .or_(f"full_name.ilike.*{q}*,email.ilike.*{q}*")
        .neq("id", user_id)
        .limit(20)
        .execute()
        .data
    )
    on_trip = _member_ids(require_uuid(trip_id, "trip id")) if trip_id else set()
    return [_to_json(p, p["id"] in on_trip) for p in rows]
