"""Small database lookups shared by several routers."""
import uuid

from fastapi import HTTPException

from database import supabase


def require_uuid(value: str, what: str = "id") -> str:
    """Return the value if it is a valid UUID, otherwise answer 404 (not a 500)."""
    try:
        return str(uuid.UUID(str(value)))
    except ValueError:
        raise HTTPException(status_code=404, detail=f"Invalid {what}")


def accepted_trip_ids(user_id: str) -> list[str]:
    rows = (
        supabase.table("trip_members")
        .select("trip_id")
        .eq("user_id", user_id)
        .eq("status", "accepted")
        .execute()
        .data
    )
    return [r["trip_id"] for r in rows]


def require_accepted_member(trip_id: str, user_id: str) -> None:
    rows = (
        supabase.table("trip_members")
        .select("user_id")
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .eq("status", "accepted")
        .execute()
        .data
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Trip not found")


def fetch_profiles(user_ids) -> dict[str, dict]:
    ids = list({i for i in user_ids if i})
    if not ids:
        return {}
    rows = (
        supabase.table("profiles")
        .select("id,full_name,email,avatar_url")
        .in_("id", ids)
        .execute()
        .data
    )
    return {r["id"]: r for r in rows}


def display_name(profile: dict) -> str:
    return profile.get("full_name") or profile.get("email") or "Unknown"
