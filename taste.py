"""A person's food habits and hotel star preference.

Their own setting for a trip wins; otherwise their account's Default Travel Preferences apply.
Used to tailor the suggestions each person sees (every member sees their own).
"""
from database import supabase

FOOD_HABITS = ("Vegetarian", "Vegan", "Halal", "Gluten-Free", "No Seafood")
HOTEL_STARS = (0, 3, 4, 5)  # 0 = no preference


def clean(raw: dict | None) -> dict:
    raw = raw or {}
    out: dict = {}
    if raw.get("dietary") is not None:
        items = []
        for v in list(raw.get("dietary") or [])[:12]:
            v = " ".join(str(v).split())[:40]
            if v and v not in items:
                items.append(v)
        out["dietary"] = items
    if raw.get("hotel_stars") is not None:
        try:
            s = int(raw["hotel_stars"])
        except (TypeError, ValueError):
            s = 0
        out["hotel_stars"] = s if s in HOTEL_STARS else 0
    return out


def account(uid: str) -> dict:
    rows = supabase.table("user_settings").select("travel_defaults").eq("user_id", uid).execute().data
    base = clean((rows[0].get("travel_defaults") if rows else None) or {})
    return {"dietary": base.get("dietary", []), "hotel_stars": base.get("hotel_stars", 0)}


def trip_override(trip_id: str, uid: str) -> dict | None:
    rows = supabase.table("trip_member_prefs").select("taste").eq("trip_id", trip_id).eq("user_id", uid).execute().data
    return (rows[0].get("taste") if rows else None) or None


def effective(uid: str, trip_id: str | None = None) -> dict:
    base = account(uid)
    own = trip_override(trip_id, uid) if trip_id else None
    return {**base, **clean(own)} if own else base


DIET_KEYWORDS = (
    ("vegan", "Vegan"),
    ("vegetarian", "Vegetarian"),
    ("halal", "Halal"),
    ("gluten", "Gluten-Free"),
    ("seafood", "No Seafood"),
)


def diets_for(uid: str, trip_id: str | None) -> list[str]:
    """Their food habits plus anything of the kind they wrote in their trip preferences (e.g. "Vegetarian")."""
    found = list(effective(uid, trip_id)["dietary"])
    if trip_id:
        rows = supabase.table("trip_member_prefs").select("preferences").eq("trip_id", trip_id).eq("user_id", uid).execute().data
        for text in (rows[0].get("preferences") if rows else None) or []:
            low = str(text).lower()
            for key, label in DIET_KEYWORDS:
                if key in low and label not in found:
                    found.append(label)
    return found
