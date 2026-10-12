"""Budget control: keeps an eye on what the trip has cost so far and warns before (and when) the budget is passed.

Levels: near = 80% of the budget used, risk = at the current pace the trip will end over budget,
over = already over budget. Each level is announced in the group chat only once (until spending drops
back below it); the same status is also returned to the app so it can show a banner."""
from datetime import date, datetime, timezone

import push
from database import supabase
from formatting import CURRENCY_SYMBOLS, parse_date

NEAR = 0.8


def spent_total(trip_id: str) -> float:
    receipts = supabase.table("receipts").select("id").eq("trip_id", trip_id).execute().data
    if not receipts:
        return 0.0
    items = supabase.table("receipt_items").select("price,quantity").in_("receipt_id", [r["id"] for r in receipts]).execute().data
    return round(sum(float(i.get("price") or 0) * int(i.get("quantity") or 1) for i in items), 2)


def _money(trip: dict, amount: float) -> str:
    cur = trip.get("currency") or "MYR"
    return f"{CURRENCY_SYMBOLS.get(cur, cur)} {amount:,.0f}"


def evaluate(trip: dict, spent: float, today: date | None = None) -> dict:
    """Pure: the status for one trip. level is None when all is fine (or no budget is set)."""
    budget = float(trip.get("budget_max") or 0)
    today = today or datetime.now(timezone.utc).date()
    out = {"budget": budget, "spent": spent, "percent": 0, "projected": None, "levels": [], "level": None, "message": ""}
    if budget <= 0:
        return out
    out["percent"] = round(spent / budget * 100)
    start, end = parse_date(trip.get("start_date")), parse_date(trip.get("end_date"))
    if start and end and end >= start and start <= today <= end and spent > 0:
        total_days = (end - start).days + 1
        elapsed = (today - start).days + 1
        out["projected"] = round(spent / elapsed * total_days, 2)
    levels = []
    if spent >= budget * NEAR:
        levels.append("near")
    if out["projected"] is not None and out["projected"] > budget and spent <= budget:
        levels.append("risk")
    if spent > budget:
        levels.append("over")
    out["levels"] = levels
    if "over" in levels:
        out["level"] = "over"
        out["message"] = f"Budget exceeded: {_money(trip, spent)} spent of {_money(trip, budget)} (over by {_money(trip, spent - budget)})."
    elif "risk" in levels:
        out["level"] = "risk"
        out["message"] = (f"At this pace the trip may cost about {_money(trip, out['projected'])}, above your {_money(trip, budget)} budget. "
                          f"{_money(trip, spent)} spent so far.")
    elif "near" in levels:
        out["level"] = "near"
        out["message"] = f"Heads up: {out['percent']}% of the budget is used ({_money(trip, spent)} of {_money(trip, budget)})."
    return out


def check(trip_id: str, announce: bool = False) -> dict:
    """Works out the status; announce=True posts any NEW warning in the group chat. Always syncs the alert markers."""
    rows = supabase.table("trips").select("*").eq("id", trip_id).execute().data
    if not rows:
        return {"level": None, "message": "", "levels": []}
    trip = rows[0]
    status = evaluate(trip, spent_total(trip_id))
    try:
        known = {r["level"] for r in supabase.table("trip_budget_alerts").select("level").eq("trip_id", trip_id).execute().data}
        for gone in known - set(status["levels"]):  # spending dropped back: allow the warning to come again
            supabase.table("trip_budget_alerts").delete().eq("trip_id", trip_id).eq("level", gone).execute()
        fresh = [lv for lv in status["levels"] if lv not in known]
        if fresh and announce:
            for lv in fresh:
                supabase.table("trip_budget_alerts").upsert({"trip_id": trip_id, "level": lv}, on_conflict="trip_id,level").execute()
            members = supabase.table("trip_members").select("user_id").eq("trip_id", trip_id).eq("status", "accepted").execute().data
            push.notify([m["user_id"] for m in members], "Budget alert", status["message"], kind="trip", trip_id=trip_id)
            if len(members) > 1:
                supabase.table("chat_messages").insert({
                    "trip_id": trip_id, "sender_id": None, "is_ai_response": True, "type": "text",
                    "text": "Budget alert: " + status["message"],
                    "created_at": datetime.now(timezone.utc).isoformat(),
                }).execute()
    except Exception as e:  # a warning must never break saving a receipt
        print(f"[budget] could not record alert: {e}")
    return status
