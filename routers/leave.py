import os
import re
from datetime import date, timedelta

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field

from auth import get_current_user_id
from database import supabase
from formatting import long_range, parse_date
from queries import accepted_trip_ids, display_name, require_accepted_member, require_uuid

router = APIRouter(prefix="/api/leave", tags=["leave"])

UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I
)
STATUSES = {"normal", "busy", "holiday", "annual_leave", "recommended"}
DEFAULT_BALANCE = 14
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

_holiday_cache: dict[int, dict[str, str]] = {}


def _holidays_from_nager(year: int, country: str) -> dict[str, str]:
    resp = httpx.get(
        f"https://date.nager.at/api/v3/PublicHolidays/{year}/{country}", timeout=8.0
    )
    # 204 / empty body = Nager has no data for this country
    if resp.status_code != 200 or not resp.content.strip():
        return {}
    return {
        h["date"]: h.get("name") or h.get("localName") or "Public holiday"
        for h in resp.json()
    }


def parse_ics_holidays(text: str, year: int) -> dict[str, str]:
    """Reads an iCalendar holiday feed -> {'2026-01-01': "New Year's Day"}.

    Entries marked as observances (not public holidays) are skipped.
    """
    lines: list[str] = []
    for raw in text.replace("\r\n", "\n").split("\n"):
        if raw.startswith((" ", "\t")) and lines:
            lines[-1] += raw[1:]  # folded line continues the previous one
        else:
            lines.append(raw)

    result: dict[str, str] = {}
    event: dict[str, str] | None = None
    for line in lines:
        if line.startswith("BEGIN:VEVENT"):
            event = {}
        elif line.startswith("END:VEVENT") and event is not None:
            start, end = event.get("DTSTART"), event.get("DTEND")
            summary = event.get("SUMMARY", "").replace("\\,", ",").strip()
            if start and summary and "observance" not in event.get("DESCRIPTION", "").lower():
                try:
                    first = date(int(start[:4]), int(start[4:6]), int(start[6:8]))
                    last = (
                        date(int(end[:4]), int(end[4:6]), int(end[6:8])) - timedelta(days=1)
                        if end
                        else first
                    )
                except ValueError:
                    first = last = None
                if first:
                    day = first
                    while day <= max(first, last):
                        if day.year == year:
                            result.setdefault(day.isoformat(), summary)
                        day += timedelta(days=1)
            event = None
        elif event is not None and ":" in line:
            name, _, value = line.partition(":")
            event[name.split(";")[0].upper()] = value.strip()
    return result


# Public holiday calendar used when Nager.Date has no data for the country.
# Google's public holiday feed for Malaysia; override with HOLIDAY_ICS_URL.
DEFAULT_ICS = {
    "MY": "https://calendar.google.com/calendar/ical/en.malaysia%23holiday%40group.v.calendar.google.com/public/basic.ics"
}


def public_holidays(year: int) -> dict[str, str]:
    """{'2026-10-05': 'Labour Day', ...}, cached per year.

    Tries Nager.Date first, then an iCalendar feed. If neither works the result
    is empty and is NOT cached, so it is tried again on the next request.
    """
    if year in _holiday_cache:
        return _holiday_cache[year]
    country = os.getenv("HOLIDAY_COUNTRY", "MY").upper()
    data: dict[str, str] = {}
    try:
        data = _holidays_from_nager(year, country)
    except Exception as e:
        print(f"[leave] Nager.Date failed for {year}/{country}: {e}")
    if not data:
        url = os.getenv("HOLIDAY_ICS_URL") or DEFAULT_ICS.get(country)
        if url:
            try:
                resp = httpx.get(url, timeout=10.0, follow_redirects=True)
                resp.raise_for_status()
                data = parse_ics_holidays(resp.text, year)
            except Exception as e:
                print(f"[leave] could not load public holidays for {year}: {e}")
    if not data:
        print(f"[leave] no public holidays found for {year}/{country}")
        return {}
    _holiday_cache[year] = data
    return data


def _stored_balance(user_id: str, year: int) -> int:
    rows = (
        supabase.table("leave_balances")
        .select("leave_balance")
        .eq("user_id", user_id)
        .eq("year", year)
        .execute()
        .data
    )
    return rows[0]["leave_balance"] if rows else DEFAULT_BALANCE


def _trip_days(user_id: str) -> set[str]:
    """Every day of every confirmed (or finished) trip this person has accepted.

    Individual on purpose: each traveller's own calendar and leave balance follow
    the trips they are on. Deleting a trip frees its days again automatically.
    """
    ids = accepted_trip_ids(user_id)
    if not ids:
        return set()
    rows = (
        supabase.table("trips")
        .select("start_date,end_date,status")
        .in_("id", ids)
        .in_("status", ["upcoming", "completed"])
        .execute()
        .data
    )
    days: set[str] = set()
    for r in rows:
        start, end = parse_date(r.get("start_date")), parse_date(r.get("end_date"))
        if not start or not end or end < start or (end - start).days > 400:
            continue
        for i in range((end - start).days + 1):
            days.add((start + timedelta(days=i)).isoformat())
    return days


def _trip_leave_used(user_id: str, year: int) -> int:
    """Working days inside the person's confirmed trips that cost one leave day each.

    Weekends, public holidays and days they already tagged "Leave taken" are free.
    """
    prefix = f"{year}-"
    mine = {d for d in _trip_days(user_id) if d.startswith(prefix)}
    if not mine:
        return 0
    holidays = public_holidays(year)
    stored = _stored_statuses(user_id, year)
    used = 0
    for d in mine:
        if parse_date(d).weekday() >= 5 or d in holidays or stored.get(d) == "annual_leave":
            continue
        used += 1
    return used


def _balance(user_id: str, year: int) -> int:
    """Leave days still free = what the person set, minus what their trips use."""
    return max(0, _stored_balance(user_id, year) - _trip_leave_used(user_id, year))


def _stored_statuses(user_id: str, year: int) -> dict[str, str]:
    rows = (
        supabase.table("leave_dates")
        .select("date,status")
        .eq("user_id", user_id)
        .gte("date", f"{year}-01-01")
        .execute()
        .data
    )
    prefix = f"{year}-"
    return {str(r["date"]): r["status"] for r in rows if str(r["date"]).startswith(prefix)}


def _statuses(user_id: str, year: int) -> dict[str, str]:
    """Public holidays first, then the user's own marks on top."""
    result = {d: "holiday" for d in public_holidays(year)}
    result.update({d: s for d, s in _stored_statuses(user_id, year).items() if s != "normal"})
    # days of a confirmed trip show as "trip" and are never offered again
    result.update({d: "trip" for d in _trip_days(user_id) if d.startswith(f"{year}-")})
    return result


def _shares_trip(a: str, b: str) -> bool:
    return bool(set(accepted_trip_ids(a)) & set(accepted_trip_ids(b)))


def _resolve_member(me: str, member_id: str | None) -> str:
    if not member_id or member_id == me:
        return me
    if not UUID_RE.match(member_id):
        raise HTTPException(status_code=404, detail="Unknown member")
    # Calendars are private: the group dates are worked out on the server from
    # everyone's busy days, but nobody can open someone else's calendar.
    raise HTTPException(status_code=403, detail="You can only see your own calendar")


@router.get("")
def get_leave(year: int | None = None, member_id: str | None = None, me: str = Depends(get_current_user_id)):
    """LeaveService.getUserLeaveData -> LeaveData JSON."""
    target = _resolve_member(me, member_id)
    year = year or date.today().year
    return {
        "selected_year": year,
        "leave_balance": _balance(target, year),
        # a tag the user added (busy / annual leave) shows on top of a holiday
        "date_statuses": _statuses(target, year),
        # public holidays always stay listed, even when the user tagged the day
        "holiday_dates": sorted(public_holidays(year)),
    }


class DateIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    date: date
    status: str


@router.put("/dates")
def set_date(body: DateIn, me: str = Depends(get_current_user_id)):
    """LeaveService.updateDateStatus. 'normal' clears the user's own mark."""
    if body.status not in STATUSES:
        raise HTTPException(status_code=422, detail=f"status must be one of {sorted(STATUSES)}")
    day = body.date.isoformat()
    if body.status == "normal":
        supabase.table("leave_dates").delete().eq("user_id", me).eq("date", day).execute()
    else:
        supabase.table("leave_dates").upsert(
            {"user_id": me, "date": day, "status": body.status},
            on_conflict="user_id,date",
        ).execute()
    return {"ok": True}


class BalanceIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    year: int | None = None
    leave_balance: int = Field(ge=0, le=365)


@router.put("/balance")
def set_balance(body: BalanceIn, me: str = Depends(get_current_user_id)):
    """LeaveService.updateLeaveBalance."""
    year = body.year or date.today().year
    # the person types the days they have LEFT; trips already take their share
    stored = min(365, body.leave_balance + _trip_leave_used(me, year))
    supabase.table("leave_balances").upsert(
        {"user_id": me, "year": year, "leave_balance": stored},
        on_conflict="user_id,year",
    ).execute()
    return {"ok": True, "leave_balance": body.leave_balance}


# ---------------------------------------------------------------- combos

def _label(d: date) -> str:
    return f"{MONTHS[d.month - 1]} {d.day}"


def compute_combos(
    year: int,
    month: int,
    balance: int,
    statuses: dict[str, str],
    holiday_names: dict[str, str],
    today: date,
    limit: int = 3,
) -> list[dict]:
    """Best ways to turn a few leave days into a long break around the month.

    A break is a run of consecutive days. Weekends, public holidays and days the
    user already booked as annual leave are free; every other working day inside
    the run costs one leave day. Runs with a 'busy' day are skipped.
    """
    first = date(year, month, 1)
    last = (date(year + (month == 12), month % 12 + 1, 1)) - timedelta(days=1)

    def key(d: date) -> str:
        return d.isoformat()

    def holiday(d: date) -> bool:
        return statuses.get(key(d)) == "holiday" or key(d) in holiday_names

    def free(d: date) -> bool:
        return d.weekday() >= 5 or holiday(d) or statuses.get(key(d)) == "annual_leave"

    def busy(d: date) -> bool:
        return statuses.get(key(d)) in ("busy", "trip")

    candidates = []
    start = first - timedelta(days=9)
    while start <= last:
        for length in range(3, 11):
            end = start + timedelta(days=length - 1)
            # must touch the chosen month and lie in the future
            if end < first or start > last or start < today:
                continue
            # a maximal break: the days just outside it are ordinary working days
            if free(start - timedelta(days=1)) or free(end + timedelta(days=1)):
                continue
            days = [start + timedelta(days=i) for i in range(length)]
            if any(busy(d) for d in days):
                continue
            used = [d for d in days if not free(d)]
            if not 1 <= len(used) <= balance:
                continue
            if length < len(used) + 3:  # not worth it unless it gains at least 3 free days
                continue
            candidates.append((start, end, length, used, days))
        start += timedelta(days=1)

    candidates.sort(key=lambda c: (-(c[2] / len(c[3])), -c[2], c[0]))

    chosen, taken = [], []
    for start, end, length, used, days in candidates:
        if any(not (end < s or start > e) for s, e in taken):
            continue
        taken.append((start, end))
        ratio = round(length / len(used), 1)
        ratio_text = f"{ratio:g}x Return"
        names = [holiday_names[key(d)] for d in days if key(d) in holiday_names]
        used_text = ", ".join(_label(d) for d in used)
        desc = f"Book off {used_text} ({len(used)} leave day{'s' if len(used) != 1 else ''})"
        if names:
            desc += f" to join {', '.join(dict.fromkeys(names))}"
        else:
            desc += " to join the weekend"
        desc += f" for a {length}-day break."
        chosen.append(
            {
                "id": f"COMBO_{key(start)}",
                "days_off": length,
                "return_multiplier": ratio_text,
                "leave_days_used": len(used),
                "date_range": f"{_label(start)} - {_label(end)}",
                "start_date": key(start),
                "end_date": key(end),
                "description": desc,
            }
        )
        if len(chosen) == limit:
            break
    return chosen


@router.get("/combos")
def get_combos(year: int | None = None, month: int | None = None, me: str = Depends(get_current_user_id)):
    """LeaveService.getLeaveCombos -> list of LeaveCombo JSON."""
    today = date.today()
    year = year or today.year
    month = month or today.month
    if not 1 <= month <= 12:
        raise HTTPException(status_code=422, detail="month must be 1-12")
    names = {}
    for y in {year - 1 if month == 1 else year, year + 1 if month == 12 else year, year}:
        names.update(public_holidays(y))
    statuses = {}
    for y in {year - 1 if month == 1 else year, year, year + 1 if month == 12 else year}:
        statuses.update(_statuses(me, y))
    return compute_combos(year, month, _balance(me, year), statuses, names, today)


# ------------------------------------------------------------ group dates

def compute_group_windows(
    members: list[dict],
    holiday_names: dict[str, str],
    today: date,
    balance_for,
    horizon_days: int = 180,
    min_len: int = 3,
    max_len: int = 9,
    limit: int = 4,
    exact_len: int | None = None,
) -> list[dict]:
    """Date ranges when EVERY member is free, cheapest in leave days first.

    members: [{"id", "name", "statuses": {"2026-10-05": "busy" | "annual_leave" | "holiday"}}]
    A range is skipped when anyone marked a day in it as busy. Weekends, public
    holidays and days a member already booked as annual leave cost that member
    nothing; every other day costs one leave day, and nobody may go over their
    leave balance. The ranges returned do not overlap.
    exact_len: the host asked for a trip of exactly this many days; then only
    that length is offered (and the "at least 2 free days" rule is dropped).
    """
    if exact_len:
        min_len = max_len = exact_len

    def key(d: date) -> str:
        return d.isoformat()

    def free(m: dict, d: date) -> bool:
        return d.weekday() >= 5 or key(d) in holiday_names or m["statuses"].get(key(d)) in ("holiday", "annual_leave")

    def busy(m: dict, d: date) -> bool:
        return m["statuses"].get(key(d)) in ("busy", "trip")

    candidates = []
    first = today + timedelta(days=1)
    for offset in range(horizon_days):
        start = first + timedelta(days=offset)
        days: list[date] = []
        for length in range(1, max_len + 1):
            day = start + timedelta(days=length - 1)
            if any(busy(m, day) for m in members):
                break  # every longer range from this start contains the busy day too
            days.append(day)
            if length < min_len:
                continue
            used = {m["id"]: sum(1 for d in days if not free(m, d)) for m in members}
            if any(used[m["id"]] > balance_for(m["id"], start.year) for m in members):
                continue
            most = max(used.values(), default=0)
            if not exact_len and length < most + 2:  # not worth it unless the break has at least 2 free days
                continue
            candidates.append((start, days[-1], length, most, used))

    candidates.sort(key=lambda c: (-(c[2] / max(1, c[3])), -c[2], c[0]))

    chosen, taken = [], []
    for start, end, length, most, used in candidates:
        if any(not (end < s or start > e) for s, e in taken):
            continue
        taken.append((start, end))
        people = [
            {"id": m["id"], "name": m["name"], "leave_days_needed": used[m["id"]], "balance": balance_for(m["id"], start.year)}
            for m in members
        ]
        if most == 0:
            note = "Nobody needs to take leave."
        else:
            who = [p["name"] for p in people if p["leave_days_needed"] == most]
            note = f"Most leave needed: {most} day{'s' if most != 1 else ''} ({', '.join(who)})."
        chosen.append(
            {
                "id": f"GROUP_{key(start)}",
                "start_date": key(start),
                "end_date": key(end),
                "date_range": long_range(start, end),
                "days_off": length,
                "max_leave_days": most,
                "members": people,
                "description": f"{length}-day break when everyone is free. {note}",
            }
        )
        if len(chosen) == limit:
            break
    return chosen


def _group_context(trip_id: str, me: str):
    from routers.expenses import _members  # same "who is on this trip" rule as expenses

    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    people = _members(trip_id)
    today = date.today()
    years = {today.year, today.year + 1}
    names: dict[str, str] = {}
    for y in years:
        names.update(public_holidays(y))
    members = []
    for p in people:
        statuses: dict[str, str] = {}
        for y in years:
            statuses.update(_statuses(p["id"], y))
        members.append({"id": p["id"], "name": display_name(p["profile"]), "statuses": statuses})
    balances = {(m["id"], y): _balance(m["id"], y) for m in members for y in years}
    return members, names, today, (lambda uid, y: balances.get((uid, y), DEFAULT_BALANCE))


def check_group_range(members, holiday_names, start: date, end: date, balance_for) -> dict:
    """How a hand-picked range works for everyone: who is busy, who needs how much leave."""
    days = [start + timedelta(days=i) for i in range((end - start).days + 1)]
    people, problems = [], []
    for m in members:
        st = m["statuses"]
        busy_days = [d.isoformat() for d in days if st.get(d.isoformat()) in ("busy", "trip")]
        needed = sum(
            1
            for d in days
            if not (d.weekday() >= 5 or d.isoformat() in holiday_names or st.get(d.isoformat()) in ("holiday", "annual_leave"))
        )
        bal = balance_for(m["id"], start.year)
        people.append({"id": m["id"], "name": m["name"], "leave_days_needed": needed, "balance": bal, "busy_days": len(busy_days)})
        if busy_days:
            problems.append(f"{m['name']} marked {len(busy_days)} of these days as busy.")
        if needed > bal:
            problems.append(f"{m['name']} needs {needed} leave days but has {bal}.")
    return {
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "date_range": long_range(start, end),
        "days": len(days),
        "members": people,
        "problems": problems,
        "ok": not problems,
    }


@router.get("/group-check")
def group_check(trip_id: str, start_date: str, end_date: str, me: str = Depends(get_current_user_id)):
    """Check a range the host picked by hand against everyone's calendar and leave balance."""
    try:
        start, end = parse_date(start_date), parse_date(end_date)
    except ValueError:
        start = end = None
    if not start or not end or end < start or (end - start).days > 60:
        raise HTTPException(status_code=422, detail="Choose a valid date range (60 days at most)")
    members, names, _today, balance_for = _group_context(trip_id, me)
    return check_group_range(members, names, start, end, balance_for)


@router.get("/group-dates")
def group_dates(trip_id: str, length: int | None = None, me: str = Depends(get_current_user_id)):
    """Date options for a group trip, from everyone's busy days and leave balance.

    `length` (optional) = the number of days the host wants.
    """
    if length is not None and not 1 <= length <= 30:
        raise HTTPException(status_code=422, detail="Trip length must be between 1 and 30 days")
    members, names, today, balance_for = _group_context(trip_id, me)
    options = compute_group_windows(members, names, today, balance_for, exact_len=length)
    busy_counts = [
        {"id": m["id"], "name": m["name"], "busy_days": sum(1 for d, s in m["statuses"].items() if s in ("busy", "trip") and d >= today.isoformat())}
        for m in members
    ]
    reason = ""
    if not options:
        reason = (
            f"No {length}-day dates in the next 6 months where everyone is free. "
            if length
            else "No dates in the next 6 months where everyone is free. "
        ) + "Ask people to clear some busy days, check their leave balances, or pick dates yourself."
    return {"options": options, "members": busy_counts, "reason": reason}
