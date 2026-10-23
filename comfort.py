"""Comfort settings (walking, activities per day, rest breaks, accessibility).

Each person can set their own for a group trip (saved with their trip preferences). Anyone who has not
falls back to their account settings. The group plans for the strictest of everybody."""
from database import supabase

DEFAULTS = {
    "max_walking_minutes": 15, "max_activities_per_day": 3, "rest_break_frequency": 1,
    "accessible_transport_only": True, "nearby_restrooms_priority": True, "minimize_stairs": False,
}
INT_RANGES = {"max_walking_minutes": (5, 30), "max_activities_per_day": (1, 6), "rest_break_frequency": (1, 3)}
BOOLS = ("accessible_transport_only", "nearby_restrooms_priority", "minimize_stairs")


def clean(raw: dict) -> dict:
    """Only known fields, inside their ranges (values outside are pulled in)."""
    out = {}
    for k, (lo, hi) in INT_RANGES.items():
        if raw.get(k) is not None:
            out[k] = max(lo, min(hi, int(raw[k])))
    for k in BOOLS:
        if raw.get(k) is not None:
            out[k] = bool(raw[k])
    return out


def _account(uid: str) -> dict:
    rows = supabase.table("user_settings").select("*").eq("user_id", uid).execute().data
    return rows[0] if rows else {}


def trip_override(trip_id: str, uid: str) -> dict | None:
    rows = supabase.table("trip_member_prefs").select("comfort").eq("trip_id", trip_id).eq("user_id", uid).execute().data
    c = rows[0].get("comfort") if rows else None
    return clean(c) if isinstance(c, dict) and c else None


def effective(uid: str, trip_id: str | None = None) -> dict:
    """What applies to this person: their setting for this trip, else their account, else the defaults."""
    own = trip_override(trip_id, uid) if trip_id else None
    base = {**DEFAULTS}
    acct = _account(uid)
    for k in DEFAULTS:
        if acct.get(k) is not None:
            base[k] = acct[k]
    out = {**base, **(own or {})}
    lo, hi = INT_RANGES["max_activities_per_day"]  # older saved values above the limit are pulled in
    out["max_activities_per_day"] = max(lo, min(hi, int(out["max_activities_per_day"])))
    return out


def strictest(rows: list[dict]) -> dict:
    rows = rows or [dict(DEFAULTS)]
    return {
        "max_walking_minutes": min(int(r["max_walking_minutes"]) for r in rows),
        "max_activities_per_day": min(int(r["max_activities_per_day"]) for r in rows),
        "rest_break_frequency": min(int(r["rest_break_frequency"]) for r in rows),
        "accessible_transport_only": any(r["accessible_transport_only"] for r in rows),
        "nearby_restrooms_priority": any(r["nearby_restrooms_priority"] for r in rows),
        "minimize_stairs": any(r["minimize_stairs"] for r in rows),
    }


def group_comfort(member_ids: list[str], trip_id: str | None = None) -> dict:
    return strictest([effective(u, trip_id) for u in member_ids])


def for_trip(trip_id: str) -> dict:
    """The comfort rules for a whole trip (one person or a group)."""
    ids = [r["user_id"] for r in supabase.table("trip_members").select("user_id").eq("trip_id", trip_id).eq("status", "accepted").execute().data]
    return group_comfort(ids, trip_id)


def describe(c: dict) -> str:
    """One line for AI prompts."""
    parts = [f"walk at most {c['max_walking_minutes']} minutes between places", f"at most {c['max_activities_per_day']} sightseeing activities a day",
             f"a rest break at least every {c['rest_break_frequency']} hour(s)"]
    if c["accessible_transport_only"]: parts.append("step-free, accessible transport only")
    if c["nearby_restrooms_priority"]: parts.append("restrooms nearby")
    if c["minimize_stairs"]: parts.append("avoid stairs and steep climbs")
    return "; ".join(parts)
