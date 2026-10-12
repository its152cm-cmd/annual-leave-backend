"""Group planning: everyone's budget, favourites shared to the group (voting),
and the host's final choice for Accommodation / Transport."""
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

import comfort
import taste
from auth import get_current_user_id
from database import supabase
from queries import display_name, fetch_profiles, require_accepted_member, require_uuid

router = APIRouter(prefix="/api/trips", tags=["planning"])

SECTIONS = ("Accommodation", "Flights", "Food", "Activities")
DECISIONS = {"Accommodation": "Accommodation", "Transport": "Flights"}  # decision -> poll section


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _check(trip_id: str, me: str) -> tuple[str, str]:
    """Validate the trip id, require an accepted member, return (trip_id, host_id)."""
    trip_id = require_uuid(trip_id, "trip")
    require_accepted_member(trip_id, me)
    rows = supabase.table("trips").select("host_id").eq("id", trip_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip_id, rows[0]["host_id"]


def _member_ids(trip_id: str) -> list[str]:
    rows = (
        supabase.table("trip_members").select("user_id").eq("trip_id", trip_id).eq("status", "accepted").execute().data
    )
    return [r["user_id"] for r in rows]


# ------------------------------------------------------------------ budget
class BudgetIn(BaseModel):
    budget_min: float = Field(ge=0, le=10_000_000)
    budget_max: float = Field(ge=0, le=10_000_000)


def combine_budgets(entries: list[tuple[float, float]]) -> dict | None:
    """Group range = highest minimum .. lowest maximum (what everyone can afford).
    If the ranges do not overlap, the lowest maximum is used for both ends."""
    if not entries:
        return None
    low = max(e[0] for e in entries)
    high = min(e[1] for e in entries)
    conflict = low > high
    if conflict:
        low = high
    return {"min": low, "max": high, "conflict": conflict}


def _budget_state(trip_id: str, me: str) -> dict:
    ids = _member_ids(trip_id)
    rows = supabase.table("trip_budgets").select("user_id,budget_min,budget_max").eq("trip_id", trip_id).execute().data
    by_user = {r["user_id"]: r for r in rows if r["user_id"] in ids}
    profiles = fetch_profiles(ids)
    members = []
    for uid in ids:
        r = by_user.get(uid)
        members.append(
            {
                "id": uid,
                "name": display_name(profiles.get(uid, {})),
                "isMe": uid == me,
                "min": float(r["budget_min"]) if r else None,
                "max": float(r["budget_max"]) if r else None,
            }
        )
    members.sort(key=lambda m: (not m["isMe"], m["name"]))
    entries = [(m["min"], m["max"]) for m in members if m["min"] is not None]
    return {"members": members, "combined": combine_budgets(entries), "entered": len(entries), "total": len(ids)}


def _sync_trip_budget(trip_id: str, state: dict) -> None:
    c = state["combined"]
    if c:
        supabase.table("trips").update({"budget_min": c["min"], "budget_max": c["max"]}).eq("id", trip_id).execute()
    else:
        supabase.table("trips").update({"budget_min": None, "budget_max": None}).eq("id", trip_id).execute()


@router.get("/{trip_id}/budget")
def get_budget(trip_id: str, me: str = Depends(get_current_user_id)):
    trip_id, _ = _check(trip_id, me)
    return _budget_state(trip_id, me)


@router.put("/{trip_id}/budget")
def put_budget(trip_id: str, body: BudgetIn, me: str = Depends(get_current_user_id)):
    trip_id, _ = _check(trip_id, me)
    low, high = sorted((body.budget_min, body.budget_max))
    supabase.table("trip_budgets").upsert(
        {"trip_id": trip_id, "user_id": me, "budget_min": low, "budget_max": high, "updated_at": _now()},
        on_conflict="trip_id,user_id",
    ).execute()
    state = _budget_state(trip_id, me)
    _sync_trip_budget(trip_id, state)
    return state


# ------------------------------------------------------------------ shares
class ShareIn(BaseModel):
    section: str
    item_key: str = Field(min_length=1, max_length=200)
    title: str = Field(min_length=1, max_length=200)
    subtitle: str = Field(default="", max_length=300)
    image_url: str = Field(default="", max_length=1000)
    item_id: str = Field(default="", max_length=200)


def _shares_json(trip_id: str, me: str, section: str | None = None) -> list[dict]:
    q = supabase.table("trip_shares").select("*").eq("trip_id", trip_id)
    if section:
        q = q.eq("section", section)
    shares = q.execute().data
    ids = [s["id"] for s in shares]
    votes = supabase.table("trip_votes").select("share_id,user_id").in_("share_id", ids).execute().data if ids else []
    members = set(_member_ids(trip_id))
    picked = {
        r["share_id"]
        for r in supabase.table("trip_activity_picks").select("share_id").eq("trip_id", trip_id).execute().data
    }
    voters: dict[str, list[str]] = {i: [] for i in ids}
    for v in votes:
        if v["user_id"] in members:
            voters[v["share_id"]].append(v["user_id"])
    # An item nobody is voting for any more leaves the poll (this also cleans
    # up older leftovers).
    empty = [i for i in ids if not voters[i]]
    if empty:
        supabase.table("trip_votes").delete().in_("share_id", empty).execute()
        supabase.table("trip_activity_picks").delete().in_("share_id", empty).execute()
        supabase.table("trip_shares").delete().in_("id", empty).execute()
        shares = [x for x in shares if x["id"] not in empty]
    profiles = fetch_profiles({s["shared_by"] for s in shares})
    out = []
    for s in shares:
        v = voters[s["id"]]
        out.append(
            {
                "id": s["id"],
                "section": s["section"],
                "title": s["title"],
                "subtitle": s.get("subtitle") or "",
                "imageUrl": s.get("image_url") or "",
                "itemId": (s.get("payload") or {}).get("item_id", ""),
                "sharedBy": display_name(profiles.get(s["shared_by"], {})),
                "sharedById": s["shared_by"],
                "votes": len(v),
                "voterIds": v,
                "votedByMe": me in v,
                "picked": s["id"] in picked,
                "createdAt": str(s.get("created_at") or ""),
            }
        )
    out.sort(key=lambda x: (-x["votes"], x["createdAt"]))
    return out


@router.get("/{trip_id}/shares")
def list_shares(trip_id: str, section: str | None = None, me: str = Depends(get_current_user_id)):
    trip_id, _ = _check(trip_id, me)
    return _shares_json(trip_id, me, section)


@router.post("/{trip_id}/shares")
def share_item(trip_id: str, body: ShareIn, me: str = Depends(get_current_user_id)):
    trip_id, _ = _check(trip_id, me)
    if body.section not in SECTIONS:
        raise HTTPException(status_code=422, detail="Unknown section")
    existing = supabase.table("trip_shares").select("id").eq("trip_id", trip_id).eq("item_key", body.item_key).execute().data
    if existing:
        share_id = existing[0]["id"]
    else:
        share_id = str(uuid.uuid4())
        supabase.table("trip_shares").insert(
            {
                "id": share_id,
                "trip_id": trip_id,
                "section": body.section,
                "item_key": body.item_key,
                "title": body.title.strip(),
                "subtitle": body.subtitle.strip(),
                "image_url": body.image_url,
                "payload": {"item_id": body.item_id},
                "shared_by": me,
                "created_at": _now(),
            }
        ).execute()
    mine = supabase.table("trip_votes").select("user_id").eq("share_id", share_id).eq("user_id", me).execute().data
    if not mine:  # sharing counts as the sharer's own vote
        supabase.table("trip_votes").insert({"share_id": share_id, "user_id": me}).execute()
    return next(s for s in _shares_json(trip_id, me) if s["id"] == share_id)


class UnshareIn(BaseModel):
    item_key: str = Field(min_length=1, max_length=200)


@router.post("/{trip_id}/shares/unshare")
def unshare_item(trip_id: str, body: UnshareIn, me: str = Depends(get_current_user_id)):
    """The person un-favourited an item: take back only THEIR vote. The item
    leaves the poll when nobody is left voting for it."""
    trip_id, _ = _check(trip_id, me)
    rows = supabase.table("trip_shares").select("id").eq("trip_id", trip_id).eq("item_key", body.item_key).execute().data
    if not rows:
        return {"ok": True, "removed": False}
    share_id = rows[0]["id"]
    supabase.table("trip_votes").delete().eq("share_id", share_id).eq("user_id", me).execute()
    left = [
        v for v in supabase.table("trip_votes").select("user_id").eq("share_id", share_id).execute().data
        if v["user_id"] in set(_member_ids(trip_id))
    ]
    if not left:
        supabase.table("trip_votes").delete().eq("share_id", share_id).execute()
        supabase.table("trip_activity_picks").delete().eq("share_id", share_id).execute()
        supabase.table("trip_shares").delete().eq("id", share_id).execute()
        return {"ok": True, "removed": True}
    return {"ok": True, "removed": False}


def _share(trip_id: str, share_id: str) -> dict:
    share_id = require_uuid(share_id, "share")
    rows = supabase.table("trip_shares").select("*").eq("id", share_id).eq("trip_id", trip_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Item not found")
    return rows[0]


@router.post("/{trip_id}/shares/{share_id}/vote")
def toggle_vote(trip_id: str, share_id: str, me: str = Depends(get_current_user_id)):
    trip_id, _ = _check(trip_id, me)
    share = _share(trip_id, share_id)
    mine = supabase.table("trip_votes").select("user_id").eq("share_id", share["id"]).eq("user_id", me).execute().data
    if mine:
        supabase.table("trip_votes").delete().eq("share_id", share["id"]).eq("user_id", me).execute()
    else:
        supabase.table("trip_votes").insert({"share_id": share["id"], "user_id": me}).execute()
    return next((s for s in _shares_json(trip_id, me) if s["id"] == share["id"]), {"id": share["id"], "removed": True})


@router.delete("/{trip_id}/shares/{share_id}")
def remove_share(trip_id: str, share_id: str, me: str = Depends(get_current_user_id)):
    trip_id, host = _check(trip_id, me)
    share = _share(trip_id, share_id)
    if me not in (share["shared_by"], host):
        raise HTTPException(status_code=403, detail="Only who shared it, or the host, can remove it")
    supabase.table("trip_votes").delete().eq("share_id", share["id"]).execute()
    supabase.table("trip_activity_picks").delete().eq("share_id", share["id"]).execute()
    supabase.table("trip_shares").delete().eq("id", share["id"]).execute()
    return {"ok": True}


# --------------------------------------------------------------- decisions
class DecisionIn(BaseModel):
    share_id: str | None = None
    title: str | None = Field(default=None, max_length=200)  # typed by hand


MULTI = {"Accommodation": 6}  # sections where several choices are allowed (value = max)


def _decisions_json(trip_id: str) -> dict:
    """Every section maps to a list of choices (empty = the AI will suggest)."""
    rows = supabase.table("trip_decisions").select("*").eq("trip_id", trip_id).execute().data
    rows = sorted(rows, key=lambda r: r.get("updated_at") or "")
    out = {k: [] for k in DECISIONS}
    for r in rows:
        if r["section"] in out:
            out[r["section"]].append(
                {"title": r["title"], "subtitle": r.get("subtitle") or "", "itemId": r.get("item_id") or ""}
            )
    return out


@router.get("/{trip_id}/decisions")
def get_decisions(trip_id: str, me: str = Depends(get_current_user_id)):
    trip_id, host = _check(trip_id, me)
    return {"isHost": me == host, "decisions": _decisions_json(trip_id)}


@router.put("/{trip_id}/decisions/{section}")
def set_decision(trip_id: str, section: str, body: DecisionIn, me: str = Depends(get_current_user_id)):
    """Adds a choice. Accommodation can have several (up to 6); Transport keeps one."""
    trip_id, host = _check(trip_id, me)
    if me != host:
        raise HTTPException(status_code=403, detail="Only the host can decide this")
    if section not in DECISIONS:
        raise HTTPException(status_code=422, detail="Unknown section")
    if body.share_id:
        share = _share(trip_id, body.share_id)
        if share["section"] != DECISIONS[section]:
            raise HTTPException(status_code=422, detail="That option belongs to another section")
        row = {"title": share["title"], "subtitle": share.get("subtitle") or "", "item_id": (share.get("payload") or {}).get("item_id", "")}
    else:
        title = (body.title or "").strip()
        if not title:
            raise HTTPException(status_code=422, detail="Choose an option or type one")
        row = {"title": title, "subtitle": "", "item_id": ""}
    current = _decisions_json(trip_id)[section]
    if section in MULTI:
        if any(c["title"] == row["title"] and c["itemId"] == row["item_id"] for c in current):
            return {"isHost": True, "decisions": _decisions_json(trip_id)}
        if len(current) >= MULTI[section]:
            raise HTTPException(status_code=422, detail=f"You can choose up to {MULTI[section]}")
    else:
        supabase.table("trip_decisions").delete().eq("trip_id", trip_id).eq("section", section).execute()
    supabase.table("trip_decisions").insert(
        {"trip_id": trip_id, "section": section, "decided_by": me, "updated_at": _now(), **row}
    ).execute()
    return {"isHost": True, "decisions": _decisions_json(trip_id)}


@router.delete("/{trip_id}/decisions/{section}")
def clear_decision(trip_id: str, section: str, title: str | None = None, item_id: str = "", me: str = Depends(get_current_user_id)):
    """Removes one choice (when `title` is given) or all choices of the section."""
    trip_id, host = _check(trip_id, me)
    if me != host:
        raise HTTPException(status_code=403, detail="Only the host can decide this")
    if section not in DECISIONS:
        raise HTTPException(status_code=422, detail="Unknown section")
    q = supabase.table("trip_decisions").delete().eq("trip_id", trip_id).eq("section", section)
    if title is not None:
        q = q.eq("title", title).eq("item_id", item_id)
    q.execute()
    return {"isHost": True, "decisions": _decisions_json(trip_id)}


# --------------------------------------------------------------- activities
class ActivitiesIn(BaseModel):
    share_ids: list[str] = Field(default_factory=list, max_length=60)


@router.get("/{trip_id}/activities")
def get_activities(trip_id: str, me: str = Depends(get_current_user_id)):
    """The shared Activities, most votes first, with the host's ticks."""
    trip_id, host = _check(trip_id, me)
    return {"isHost": me == host, "activities": _shares_json(trip_id, me, "Activities")}


@router.put("/{trip_id}/activities")
def set_activities(trip_id: str, body: ActivitiesIn, me: str = Depends(get_current_user_id)):
    """Host ticks which shared activities go into the itinerary (replaces the ticks)."""
    trip_id, host = _check(trip_id, me)
    if me != host:
        raise HTTPException(status_code=403, detail="Only the host can choose the activities")
    valid = {s["id"] for s in supabase.table("trip_shares").select("id").eq("trip_id", trip_id).eq("section", "Activities").execute().data}
    chosen = [require_uuid(i, "activity") for i in dict.fromkeys(body.share_ids)]
    if any(i not in valid for i in chosen):
        raise HTTPException(status_code=422, detail="One of those activities is not in the poll any more")
    supabase.table("trip_activity_picks").delete().eq("trip_id", trip_id).execute()
    if chosen:
        supabase.table("trip_activity_picks").insert([{"trip_id": trip_id, "share_id": i} for i in chosen]).execute()
    return {"isHost": True, "activities": _shares_json(trip_id, me, "Activities")}


# -------------------------------------------------------------- preferences
class PrefsIn(BaseModel):
    preferences: list[str] = Field(default_factory=list, max_length=20)


def _clean_prefs(items: list[str]) -> list[str]:
    seen, out = set(), []
    for t in items:
        t = " ".join(str(t).split())[:120]
        if t and t.lower() not in seen:
            seen.add(t.lower())
            out.append(t)
    return out


def member_preferences(trip_id: str) -> list[dict]:
    """[{id, name, preferences}] for everybody on the trip (empty list when none)."""
    ids = _member_ids(trip_id)
    rows = supabase.table("trip_member_prefs").select("user_id,preferences").eq("trip_id", trip_id).execute().data
    by_user = {r["user_id"]: r.get("preferences") or [] for r in rows}
    profiles = fetch_profiles(ids)
    return [
        {"id": uid, "name": display_name(profiles.get(uid, {})), "preferences": [p for p in by_user.get(uid, []) if isinstance(p, str)]}
        for uid in ids
    ]


@router.get("/{trip_id}/preferences")
def get_preferences(trip_id: str, me: str = Depends(get_current_user_id)):
    trip_id, _ = _check(trip_id, me)
    members = member_preferences(trip_id)
    for m in members:
        m["isMe"] = m["id"] == me
    combined = _clean_prefs([p for m in members for p in m["preferences"]])
    return {"members": members, "combined": combined}


@router.put("/{trip_id}/preferences")
def put_preferences(trip_id: str, body: PrefsIn, me: str = Depends(get_current_user_id)):
    """Saves YOUR preferences for this trip (everyone else's stay as they are)."""
    trip_id, _ = _check(trip_id, me)
    supabase.table("trip_member_prefs").upsert(
        {"trip_id": trip_id, "user_id": me, "preferences": _clean_prefs(body.preferences), "updated_at": _now()},
        on_conflict="trip_id,user_id",
    ).execute()
    return get_preferences(trip_id, me)


class ComfortIn(BaseModel):
    max_walking_minutes: int | None = Field(default=None, ge=5, le=30)
    max_activities_per_day: int | None = Field(default=None, ge=1, le=10)
    rest_break_frequency: int | None = Field(default=None, ge=1, le=3)
    accessible_transport_only: bool | None = None
    nearby_restrooms_priority: bool | None = None
    minimize_stairs: bool | None = None


def comfort_state(trip_id: str, me: str) -> dict:
    ids = _member_ids(trip_id)
    profiles = fetch_profiles(ids)
    members, rows = [], []
    for uid in ids:
        eff = comfort.effective(uid, trip_id)
        rows.append(eff)
        members.append({"id": uid, "name": display_name(profiles.get(uid, {})), "isMe": uid == me,
                        "custom": comfort.trip_override(trip_id, uid) is not None, "comfort": eff})
    members.sort(key=lambda m: (not m["isMe"], m["name"]))
    return {"members": members, "combined": comfort.strictest(rows)}


@router.get("/{trip_id}/comfort")
def get_comfort(trip_id: str, me: str = Depends(get_current_user_id)):
    trip_id, _ = _check(trip_id, me)
    return comfort_state(trip_id, me)


@router.put("/{trip_id}/comfort")
def put_comfort(trip_id: str, body: ComfortIn, me: str = Depends(get_current_user_id)):
    """Saves YOUR comfort settings for this trip."""
    trip_id, _ = _check(trip_id, me)
    mine = {**comfort.effective(me, trip_id), **comfort.clean(body.model_dump(exclude_none=True))}
    supabase.table("trip_member_prefs").upsert(
        {"trip_id": trip_id, "user_id": me, "comfort": mine, "updated_at": _now()}, on_conflict="trip_id,user_id"
    ).execute()
    return comfort_state(trip_id, me)


@router.delete("/{trip_id}/comfort")
def reset_comfort(trip_id: str, me: str = Depends(get_current_user_id)):
    """Back to your account settings for this trip."""
    trip_id, _ = _check(trip_id, me)
    supabase.table("trip_member_prefs").update({"comfort": None}).eq("trip_id", trip_id).eq("user_id", me).execute()
    return comfort_state(trip_id, me)


class TasteIn(BaseModel):
    dietary: list[str] | None = None
    hotel_stars: int | None = Field(default=None, ge=0, le=5)


def taste_state(trip_id: str, me: str) -> dict:
    ids = _member_ids(trip_id)
    profiles = fetch_profiles(ids)
    members = []
    for uid in ids:
        eff = taste.effective(uid, trip_id)
        members.append({"id": uid, "name": display_name(profiles.get(uid, {})), "isMe": uid == me,
                        "custom": taste.trip_override(trip_id, uid) is not None, **eff})
    members.sort(key=lambda m: (not m["isMe"], m["name"]))
    return {"members": members}


@router.get("/{trip_id}/taste")
def get_taste(trip_id: str, me: str = Depends(get_current_user_id)):
    """Everyone's food habits and hotel star preference for this trip."""
    trip_id, _ = _check(trip_id, me)
    return taste_state(trip_id, me)


@router.put("/{trip_id}/taste")
def put_taste(trip_id: str, body: TasteIn, me: str = Depends(get_current_user_id)):
    """Saves YOUR food habits and hotel stars for this trip."""
    trip_id, _ = _check(trip_id, me)
    mine = {**taste.effective(me, trip_id), **taste.clean(body.model_dump(exclude_none=True))}
    supabase.table("trip_member_prefs").upsert(
        {"trip_id": trip_id, "user_id": me, "taste": mine, "updated_at": _now()}, on_conflict="trip_id,user_id"
    ).execute()
    return taste_state(trip_id, me)


@router.delete("/{trip_id}/taste")
def reset_taste(trip_id: str, me: str = Depends(get_current_user_id)):
    """Back to your account's Default Travel Preferences for this trip."""
    trip_id, _ = _check(trip_id, me)
    supabase.table("trip_member_prefs").update({"taste": None}).eq("trip_id", trip_id).eq("user_id", me).execute()
    return taste_state(trip_id, me)


def group_inputs(trip_id: str) -> dict:
    """Everything the group decided, for the itinerary AI."""
    picks = {r["share_id"] for r in supabase.table("trip_activity_picks").select("share_id").eq("trip_id", trip_id).execute().data}
    shares = supabase.table("trip_shares").select("id,title,subtitle,section").eq("trip_id", trip_id).eq("section", "Activities").execute().data
    activities = [{"title": s["title"], "subtitle": s.get("subtitle") or ""} for s in shares if s["id"] in picks]
    decisions = _decisions_json(trip_id)
    foods = supabase.table("trip_shares").select("title,subtitle").eq("trip_id", trip_id).eq("section", "Food").execute().data
    food = [{"title": f["title"], "subtitle": f.get("subtitle") or ""} for f in foods][:12]
    return {"members": member_preferences(trip_id), "activities": activities, "decisions": decisions, "food": food}
