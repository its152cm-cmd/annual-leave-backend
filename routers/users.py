import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field

from auth import get_current_user_id
from database import supabase
from queries import accepted_trip_ids, display_name

router = APIRouter(prefix="/api/me", tags=["account"])

PROFILE_COLUMNS = (
    "id,full_name,email,avatar_url,display_user_code,"
    "countries_visited,cities_explored,distance_travelled_km"
)


def _display_code(profile: dict) -> str:
    """The 16-digit code shown on the profile, e.g. '5574 5687 1125 5115'."""
    if profile.get("display_user_code"):
        return profile["display_user_code"]
    digits = f"{uuid.UUID(profile['id']).int % 10**16:016d}"
    return " ".join(digits[i : i + 4] for i in range(0, 16, 4))


def _profile_json(profile: dict) -> dict:
    """AccountProfile JSON (lib/models/account_profile.dart)."""
    completed = 0
    ids = accepted_trip_ids(profile["id"])
    if ids:
        completed = len(
            supabase.table("trips").select("id").in_("id", ids).eq("status", "completed").execute().data
        )
    return {
        "name": display_name(profile),
        "user_id": _display_code(profile),
        "avatar_url": profile.get("avatar_url") or "",
        "countries_visited": profile.get("countries_visited") or 0,
        "cities_explored": profile.get("cities_explored") or 0,
        "trips_completed": completed,
        "distance_travelled_km": profile.get("distance_travelled_km") or 0,
        # extras the Flutter model ignores
        "id": profile["id"],
        "email": profile.get("email") or "",
    }


def _get_profile(user_id: str) -> dict:
    rows = supabase.table("profiles").select(PROFILE_COLUMNS).eq("id", user_id).execute().data
    if not rows:
        raise HTTPException(
            status_code=404,
            detail="No profile found for this user. Check DEV_USER_ID in .env.",
        )
    return rows[0]


class ProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="ignore")
    name: str | None = Field(default=None, min_length=1, max_length=80)
    avatar_url: str | None = None


@router.get("")
def get_me(user_id: str = Depends(get_current_user_id)):
    """AccountService.getCurrentUser. Also the quickest check that DEV_USER_ID works."""
    return _profile_json(_get_profile(user_id))


@router.patch("")
def update_me(body: ProfileUpdate, user_id: str = Depends(get_current_user_id)):
    """AccountService.updateProfile."""
    _get_profile(user_id)
    changes = {}
    if body.name is not None:
        changes["full_name"] = body.name.strip()
    if body.avatar_url is not None:
        changes["avatar_url"] = body.avatar_url
    if changes:
        supabase.table("profiles").update(changes).eq("id", user_id).execute()
    return _profile_json(_get_profile(user_id))


class AvatarIn(BaseModel):
    mimeType: str = "image/jpeg"
    dataBase64: str


AVATAR_BUCKET = "avatars"
AVATAR_TYPES = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


def _avatar_bucket():
    storage = supabase.storage
    try:  # the public bucket is created on first use
        storage.create_bucket(AVATAR_BUCKET, options={"public": True})
    except Exception:
        pass
    return storage.from_(AVATAR_BUCKET)


@router.post("/avatar")
def upload_avatar(body: AvatarIn, user_id: str = Depends(get_current_user_id)):
    """Saves the profile picture so it is still there after signing out and in."""
    import base64
    import binascii
    import time

    _get_profile(user_id)
    mime = body.mimeType.strip().lower()
    if mime not in AVATAR_TYPES:
        raise HTTPException(status_code=422, detail="Please use a JPG, PNG or WebP photo")
    try:
        data = base64.b64decode(body.dataBase64, validate=False)
    except (binascii.Error, ValueError):
        raise HTTPException(status_code=422, detail="The photo could not be read")
    if not data:
        raise HTTPException(status_code=422, detail="The photo is empty")
    if len(data) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="The photo is too large (5 MB max)")
    path = f"{user_id}/{int(time.time())}.{AVATAR_TYPES[mime]}"
    bucket = _avatar_bucket()
    try:
        bucket.upload(path, data, {"content-type": mime})
    except Exception:
        raise HTTPException(status_code=502, detail="The photo could not be uploaded. Please try again.")
    url = bucket.get_public_url(path)
    if isinstance(url, dict):
        url = url.get("publicURL") or url.get("publicUrl") or ""
    url = str(url).rstrip("?")
    supabase.table("profiles").update({"avatar_url": url}).eq("id", user_id).execute()
    return _profile_json(_get_profile(user_id))


# ---------- settings: currency, notifications, comfort -------------------
class Notifications(BaseModel):
    model_config = ConfigDict(extra="ignore")
    trip_updates: bool | None = None
    group_chat: bool | None = None
    reminders: bool | None = None
    promotions: bool | None = None


class Comfort(BaseModel):
    model_config = ConfigDict(extra="ignore")
    max_walking_minutes: int | None = Field(default=None, ge=5, le=30)
    max_activities_per_day: int | None = Field(default=None, ge=1, le=6)
    rest_break_frequency: int | None = Field(default=None, ge=1, le=3)
    accessible_transport_only: bool | None = None
    nearby_restrooms_priority: bool | None = None
    minimize_stairs: bool | None = None


class TravelDefaults(BaseModel):
    model_config = ConfigDict(extra="ignore")
    dietary: list[str] | None = None
    pace: str | None = None
    interests: list[str] | None = None
    hotel_stars: int | None = None


class SettingsUpdate(BaseModel):
    model_config = ConfigDict(extra="ignore")
    currency_code: str | None = Field(default=None, min_length=3, max_length=3)
    notifications: Notifications | None = None
    comfort: Comfort | None = None
    travel: TravelDefaults | None = None


PACES = ("", "Relaxed", "Moderate", "Fast-paced")
HOTEL_STARS = (0, 3, 4, 5)  # 0 = no preference


def clean_travel(data: dict | None) -> dict:
    """{'dietary': [...], 'pace': '...', 'interests': [...]} with short, plain values only."""
    data = data or {}

    def items(key):
        out = []
        for v in (data.get(key) or [])[:12]:
            v = " ".join(str(v).split())[:40]
            if v and v not in out:
                out.append(v)
        return out

    pace = str(data.get("pace") or "")
    try:
        stars = int(data.get("hotel_stars") or 0)
    except (TypeError, ValueError):
        stars = 0
    return {"dietary": items("dietary"), "pace": pace if pace in PACES else "", "interests": items("interests"),
            "hotel_stars": stars if stars in HOTEL_STARS else 0}


NOTIFY_COLUMNS = {
    "trip_updates": "notify_trip_updates",
    "group_chat": "notify_group_chat",
    "reminders": "notify_reminders",
    "promotions": "notify_promotions",
}


def _settings_json(row: dict) -> dict:
    return {
        "currency_code": row["currency_code"],
        "notifications": {k: row[col] for k, col in NOTIFY_COLUMNS.items()},
        "comfort": {
            "max_walking_minutes": row["max_walking_minutes"],
            "max_activities_per_day": row["max_activities_per_day"],
            "rest_break_frequency": row["rest_break_frequency"],
            "accessible_transport_only": row["accessible_transport_only"],
            "nearby_restrooms_priority": row["nearby_restrooms_priority"],
            "minimize_stairs": row["minimize_stairs"],
        },
        "travel": clean_travel(row.get("travel_defaults")),
    }


def _get_settings(user_id: str) -> dict:
    rows = supabase.table("user_settings").select("*").eq("user_id", user_id).execute().data
    if rows:
        return rows[0]
    _get_profile(user_id)  # 404 if the user itself does not exist
    return supabase.table("user_settings").insert({"user_id": user_id}).execute().data[0]


@router.get("/settings")
def get_settings(user_id: str = Depends(get_current_user_id)):
    """AccountService.getCurrency / getNotifications / getComfortSettings in one call."""
    return _settings_json(_get_settings(user_id))


@router.put("/settings")
def update_settings(body: SettingsUpdate, user_id: str = Depends(get_current_user_id)):
    """AccountService.setCurrency / setNotifications / setComfortSettings.
    Send only what changed; everything else is kept."""
    _get_settings(user_id)
    changes: dict = {}
    if body.currency_code:
        changes["currency_code"] = body.currency_code.upper()
    if body.notifications:
        for key, value in body.notifications.model_dump(exclude_none=True).items():
            changes[NOTIFY_COLUMNS[key]] = value
    if body.comfort:
        changes.update(body.comfort.model_dump(exclude_none=True))
    if body.travel:
        current = clean_travel(_get_settings(user_id).get("travel_defaults"))
        current.update(body.travel.model_dump(exclude_none=True))
        changes["travel_defaults"] = clean_travel(current)
    if changes:
        supabase.table("user_settings").update(changes).eq("user_id", user_id).execute()
    return _settings_json(_get_settings(user_id))
