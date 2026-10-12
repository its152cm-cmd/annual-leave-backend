"""Trip budget line items (flights, hotels, food...) with a status, plus booking documents.

Lines start from the itinerary and the AI budget breakdown, then the host can edit them, add manual lines
and attach booking documents. Gemini reads each document and the backend checks it against the trip dates."""
import base64
import binascii
import re
import uuid
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

import gemini
from auth import get_current_user_id
from database import supabase
from formatting import CURRENCY_SYMBOLS, parse_date
from queries import require_accepted_member, require_uuid

router = APIRouter(prefix="/api/trips/{trip_id}/lines", tags=["budget-lines"])

CATEGORIES = ["Transport", "Accommodation", "Food", "Activities", "Other Expenses"]
STATUSES = ["estimated", "planned", "pending", "booked"]
BUCKET = "trip-docs"
MAX_BYTES = 8 * 1024 * 1024
DOC_TYPES = {"application/pdf", "image/jpeg", "image/png", "image/webp"}
DEFAULT_SHARE = {"Transport": 0.3, "Accommodation": 0.35, "Food": 0.15, "Activities": 0.15, "Other Expenses": 0.05}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _bucket():
    return supabase.storage.from_(BUCKET)


def _ctx(trip_id: str, me: str) -> tuple[str, dict, bool]:
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    rows = supabase.table("trips").select("*").eq("id", trip_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip_id, rows[0], rows[0].get("host_id") == me


def _host(trip_id: str, me: str) -> tuple[str, dict]:
    trip_id, trip, is_host = _ctx(trip_id, me)
    if not is_host:
        raise HTTPException(status_code=403, detail="Only the host can change the trip budget lines")
    return trip_id, trip


# ---------------------------------------------------------------- seeding
def _canon(cat: str) -> str:
    c = (cat or "").strip().lower()
    return {"transport": "Transport", "flights": "Transport", "accommodation": "Accommodation", "food": "Food",
            "activities": "Activities", "activity": "Activities"}.get(c, "Other Expenses")


def _hotel_name(title: str) -> str:
    return re.sub(r"^\s*(hotel\s+)?(check[- ]?in|check[- ]?out)\s*:?\s*", "", title or "", flags=re.I).strip() or (title or "Hotel")


def build_lines(trip: dict, items: list[dict]) -> list[dict]:
    """Starting lines. items = [{key,title,type,booking_url}] in itinerary order."""
    raw = trip.get("budget_breakdown") if isinstance(trip.get("budget_breakdown"), dict) else {}
    totals = {c: 0.0 for c in CATEGORIES}
    for k, v in raw.items():
        try:
            totals[_canon(k)] += float(v or 0)
        except (TypeError, ValueError):
            pass
    if sum(totals.values()) <= 0:
        planned = float(trip.get("budget_max") or 0)
        totals = {c: round(planned * s, 2) for c, s in DEFAULT_SHARE.items()}
    lines: list[dict] = []

    flights = [i for i in items if i["type"] == "flight"]
    if flights:
        share = round(totals["Transport"] * 0.8 / len(flights), 2)
        lines += [{"item_key": f["key"], "category": "Transport", "title": f["title"], "amount": share, "booking_url": f.get("booking_url", "")} for f in flights]
        lines.append({"category": "Transport", "title": "Local transport", "amount": round(totals["Transport"] * 0.2, 2)})
    else:
        lines.append({"category": "Transport", "title": "Transport", "amount": totals["Transport"]})

    seen, hotels = set(), []
    for h in (i for i in items if i["type"] == "hotel"):
        name = _hotel_name(h["title"])
        if name.lower() not in seen:
            seen.add(name.lower()); hotels.append({**h, "title": name})
    if hotels:
        share = round(totals["Accommodation"] / len(hotels), 2)
        lines += [{"item_key": h["key"], "category": "Accommodation", "title": h["title"], "amount": share, "booking_url": h.get("booking_url", "")} for h in hotels]
    else:
        lines.append({"category": "Accommodation", "title": "Accommodation", "amount": totals["Accommodation"]})
    lines.append({"category": "Food", "title": "Food and drinks", "amount": totals["Food"]})
    lines.append({"category": "Activities", "title": "Activities and tickets", "amount": totals["Activities"]})
    lines.append({"category": "Other Expenses", "title": "Other expenses", "amount": totals["Other Expenses"]})
    return lines


def _itinerary_items(trip_id: str) -> list[dict]:
    its = supabase.table("itineraries").select("id").eq("trip_id", trip_id).execute().data
    if not its:
        return []
    days = supabase.table("itinerary_days").select("id,day_number").eq("itinerary_id", its[0]["id"]).execute().data
    days.sort(key=lambda d: d["day_number"])
    out = []
    for d in days:
        rows = supabase.table("itinerary_items").select("*").eq("day_id", d["id"]).execute().data
        rows.sort(key=lambda r: r.get("position") or 0)
        for r in rows:
            out.append({"key": str((r.get("source_data") or {}).get("client_id") or r["id"]), "title": r.get("title") or "",
                        "type": r.get("type") or "", "booking_url": r.get("booking_url") or ""})
    return out


def _seed(trip_id: str, trip: dict) -> None:
    if supabase.table("trip_budget_seed").select("trip_id").eq("trip_id", trip_id).execute().data:
        return
    items = _itinerary_items(trip_id)
    if not items:
        return  # nothing planned yet: try again once the itinerary exists
    booked = set(trip.get("booked_item_ids") or [])
    rows = []
    for pos, ln in enumerate(build_lines(trip, items)):
        rows.append({"trip_id": trip_id, "item_key": ln.get("item_key"), "category": ln["category"], "title": ln["title"][:140],
                     "amount": round(float(ln["amount"]), 2), "booking_url": ln.get("booking_url", ""), "position": pos,
                     "status": "booked" if ln.get("item_key") in booked else "estimated"})
    supabase.table("trip_budget_lines").insert(rows).execute()
    supabase.table("trip_budget_seed").upsert({"trip_id": trip_id}, on_conflict="trip_id").execute()


# ---------------------------------------------------------------- json
def _doc_json(d: dict) -> dict:
    return {"id": d["id"], "fileName": d["file_name"], "contentType": d["content_type"], "checkStatus": d["check_status"],
            "notes": d.get("check_notes") or [], "extracted": d.get("extracted") or {}, "createdAt": str(d.get("created_at") or "")}


def _line_json(l: dict, docs: list[dict]) -> dict:
    return {"id": l["id"], "category": l["category"], "title": l["title"], "amount": float(l["amount"] or 0), "status": l["status"],
            "bookingUrl": l.get("booking_url") or "", "documents": [_doc_json(d) for d in docs if d["line_id"] == l["id"]]}


def summary(trip: dict, lines: list[dict]) -> dict:
    by = {s: 0.0 for s in STATUSES}
    for l in lines:
        by[l["status"]] = by.get(l["status"], 0.0) + float(l["amount"] or 0)
    total = round(sum(by.values()), 2)
    budget = float(trip.get("budget_max") or 0)
    cur = trip.get("currency") or "MYR"
    return {"total": total, "byStatus": {k: round(v, 2) for k, v in by.items()}, "budget": budget,
            "remaining": round(budget - total, 2) if budget else None, "currency": CURRENCY_SYMBOLS.get(cur, cur)}


def _all(trip_id: str) -> tuple[list[dict], list[dict]]:
    lines = supabase.table("trip_budget_lines").select("*").eq("trip_id", trip_id).execute().data
    lines.sort(key=lambda l: (l.get("position") or 0, str(l.get("created_at"))))
    docs = supabase.table("trip_budget_docs").select("*").eq("trip_id", trip_id).execute().data
    docs.sort(key=lambda d: str(d.get("created_at")))
    return lines, docs


@router.get("")
def list_lines(trip_id: str, me: str = Depends(get_current_user_id)):
    trip_id, trip, is_host = _ctx(trip_id, me)
    _seed(trip_id, trip)
    lines, docs = _all(trip_id)
    return {"canEdit": is_host, "lines": [_line_json(l, docs) for l in lines], "summary": summary(trip, lines)}


class LineIn(BaseModel):
    category: str = "Other Expenses"
    title: str = Field(min_length=1, max_length=140)
    amount: float = Field(default=0, ge=0, le=10_000_000)
    status: str = "planned"
    bookingUrl: str = Field(default="", max_length=500)


class LinePatch(BaseModel):
    category: str | None = None
    title: str | None = Field(default=None, min_length=1, max_length=140)
    amount: float | None = Field(default=None, ge=0, le=10_000_000)
    status: str | None = None
    bookingUrl: str | None = Field(default=None, max_length=500)


def _check_status(value: str) -> str:
    if value not in STATUSES:
        raise HTTPException(status_code=422, detail="status must be estimated, planned, pending or booked")
    return value


def _url(value: str) -> str:
    v = (value or "").strip()
    if v and not re.match(r"^https?://\S+$", v):
        raise HTTPException(status_code=422, detail="The booking link must start with http:// or https://")
    return v


@router.post("")
def add_line(trip_id: str, body: LineIn, me: str = Depends(get_current_user_id)):
    trip_id, trip = _host(trip_id, me)
    existing = supabase.table("trip_budget_lines").select("id").eq("trip_id", trip_id).execute().data
    if len(existing) >= 100:
        raise HTTPException(status_code=409, detail="This trip has too many budget lines")
    row = supabase.table("trip_budget_lines").insert({
        "trip_id": trip_id, "category": _canon(body.category), "title": " ".join(body.title.split()), "amount": round(body.amount, 2),
        "status": _check_status(body.status), "booking_url": _url(body.bookingUrl), "position": len(existing) + 1, "updated_at": _now(),
    }).execute().data[0]
    return _line_json(row, [])


def _line(trip_id: str, line_id: str) -> dict:
    rows = supabase.table("trip_budget_lines").select("*").eq("trip_id", trip_id).eq("id", line_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Budget line not found")
    return rows[0]


@router.patch("/{line_id}")
def edit_line(trip_id: str, line_id: str, body: LinePatch, me: str = Depends(get_current_user_id)):
    trip_id, _ = _host(trip_id, me)
    _line(trip_id, line_id)
    patch: dict = {"updated_at": _now()}
    if body.category is not None: patch["category"] = _canon(body.category)
    if body.title is not None: patch["title"] = " ".join(body.title.split())
    if body.amount is not None: patch["amount"] = round(body.amount, 2)
    if body.status is not None: patch["status"] = _check_status(body.status)
    if body.bookingUrl is not None: patch["booking_url"] = _url(body.bookingUrl)
    supabase.table("trip_budget_lines").update(patch).eq("id", line_id).execute()
    docs = supabase.table("trip_budget_docs").select("*").eq("line_id", line_id).execute().data
    return _line_json(_line(trip_id, line_id), docs)


@router.delete("/{line_id}")
def delete_line(trip_id: str, line_id: str, me: str = Depends(get_current_user_id)):
    trip_id, _ = _host(trip_id, me)
    _line(trip_id, line_id)
    paths = [d["storage_path"] for d in supabase.table("trip_budget_docs").select("storage_path").eq("line_id", line_id).execute().data]
    if paths:
        try:
            _bucket().remove(paths)
        except Exception as e:
            print(f"[budget-docs] could not remove files: {e}")
    supabase.table("trip_budget_lines").delete().eq("id", line_id).execute()
    return {"ok": True}


# ---------------------------------------------------------------- documents
def _doc_schema() -> dict:
    s = {"type": "STRING"}
    return {"type": "OBJECT", "properties": {
        "doc_type": {"type": "STRING", "enum": ["flight", "hotel", "activity", "transport", "other", "not_a_booking"]},
        "provider": s, "start_date": s, "end_date": s, "total_amount": {"type": "NUMBER"}, "currency": s, "reference": s,
    }, "required": ["doc_type"]}


DOC_PROMPT = """Read this travel booking document (flight e-ticket, hotel confirmation, activity or transport ticket) and answer with JSON only.

- doc_type: flight, hotel, activity, transport, other, or not_a_booking if it is not a booking/ticket/reservation at all.
- provider: airline, hotel or company name as printed.
- start_date / end_date: YYYY-MM-DD. Flight: first departure date and last arrival date. Hotel: check-in and check-out. Activity or ticket: the date (or valid-from and valid-until). Empty string if not shown.
- total_amount: the total price as a plain number (0 if not shown). currency: 3-letter code or symbol as printed.
- reference: booking reference if shown, else "".
Never guess. Use empty values when something is not readable.

Answer with JSON only: {"doc_type": "hotel", "provider": "...", "start_date": "2026-10-12", "end_date": "2026-10-15", "total_amount": 0, "currency": "", "reference": ""}"""

_TYPE_FOR_CATEGORY = {"Transport": {"flight", "transport"}, "Accommodation": {"hotel"}, "Activities": {"activity"}}


def check_document(trip: dict, line: dict, ex: dict, today: date | None = None) -> tuple[str, list[str]]:
    """Compares what the document says with the trip. Returns (valid|check, notes). Pure."""
    today = today or datetime.now(timezone.utc).date()
    notes: list[str] = []
    kind = str(ex.get("doc_type") or "")
    if kind in ("", "not_a_booking"):
        return "check", ["This does not look like a booking confirmation or ticket. Please upload the right document."]
    allowed = _TYPE_FOR_CATEGORY.get(line.get("category"))
    if allowed and kind != "other" and kind not in allowed:
        notes.append(f"This looks like a {kind} document, but the line is {line.get('category')}.")
    ts, te = parse_date(trip.get("start_date")), parse_date(trip.get("end_date"))
    ds, de = parse_date(ex.get("start_date")), parse_date(ex.get("end_date"))
    if ts and te:
        lo, hi = ts - timedelta(days=1), te + timedelta(days=1)  # overnight flights may land the next day
        shown = [d for d in (ds, de) if d]
        if shown and any(d < lo or d > hi for d in shown):
            span = " to ".join(sorted({d.strftime("%d %b %Y") for d in shown}, key=lambda x: datetime.strptime(x, "%d %b %Y")))
            notes.append(f"The dates on the document ({span}) are outside your trip ({ts:%d %b} to {te:%d %b %Y}).")
        if not shown:
            notes.append("No date could be read from this document, so it could not be checked against your trip.")
    last = de or ds
    if last and last < today and (not te or te >= today):
        notes.append("This document has already expired.")
    amount = float(ex.get("total_amount") or 0)
    planned = float(line.get("amount") or 0)
    if amount > 0 and planned > 0 and abs(amount - planned) / planned > 0.25:
        notes.append(f"The total on the document ({ex.get('currency') or ''} {amount:,.0f}) is quite different from the line amount ({planned:,.0f}).".replace("  ", " "))
    return ("check" if notes else "valid"), notes


def _read_document(data: bytes, mime: str) -> dict | None:
    try:
        raw = gemini.generate_json(DOC_PROMPT, schema=_doc_schema(), temperature=0.1, fast=True, image=(data, mime))
    except gemini.GeminiError as e:
        print(f"[budget-docs] could not read the document: {e.message}")
        return None
    return raw if isinstance(raw, dict) else None


class DocIn(BaseModel):
    fileName: str = Field(min_length=1, max_length=160)
    mimeType: str
    dataBase64: str


def _safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", name)[-80:] or "document"


def _apply_check(trip: dict, line: dict, data: bytes, mime: str) -> tuple[str, list[str], dict]:
    ex = _read_document(data, mime)
    if ex is None:
        return "unchecked", ["The document is saved but could not be checked right now. Try Check again in a moment."], {}
    status, notes = check_document(trip, line, ex)
    return status, notes, {k: ex.get(k) for k in ("doc_type", "provider", "start_date", "end_date", "total_amount", "currency", "reference")}


@router.post("/{line_id}/documents")
def upload_document(trip_id: str, line_id: str, body: DocIn, me: str = Depends(get_current_user_id)):
    trip_id, trip = _host(trip_id, me)
    line = _line(trip_id, line_id)
    mime = body.mimeType.strip().lower()
    if mime not in DOC_TYPES:
        raise HTTPException(status_code=422, detail="Please upload a PDF, JPG, PNG or WebP file")
    try:
        data = base64.b64decode(body.dataBase64, validate=False)
    except (binascii.Error, ValueError):
        raise HTTPException(status_code=422, detail="The file could not be read")
    if not data:
        raise HTTPException(status_code=422, detail="The file is empty")
    if len(data) > MAX_BYTES:
        raise HTTPException(status_code=413, detail="The file is too large (8 MB max)")
    if len(supabase.table("trip_budget_docs").select("id").eq("line_id", line_id).execute().data) >= 5:
        raise HTTPException(status_code=409, detail="A line can have up to 5 documents")
    path = f"{trip_id}/{line_id}/{uuid.uuid4().hex}_{_safe_name(body.fileName)}"
    try:
        _bucket().upload(path, data, {"content-type": mime})
    except Exception as e:
        print(f"[budget-docs] upload failed: {e}")
        raise HTTPException(status_code=502, detail="The file could not be stored. Check that the 'trip-docs' storage bucket exists (run 013_budget_lines.sql).")
    status, notes, extracted = _apply_check(trip, line, data, mime)
    row = supabase.table("trip_budget_docs").insert({
        "trip_id": trip_id, "line_id": line_id, "file_name": body.fileName.strip()[:160], "content_type": mime, "storage_path": path,
        "uploaded_by": me, "check_status": status, "check_notes": notes, "extracted": extracted, "created_at": _now(),
    }).execute().data[0]
    if status == "valid" and line["status"] != "booked":
        supabase.table("trip_budget_lines").update({"status": "booked", "updated_at": _now()}).eq("id", line_id).execute()
    docs = supabase.table("trip_budget_docs").select("*").eq("line_id", line_id).execute().data
    return {"document": _doc_json(row), "line": _line_json(_line(trip_id, line_id), docs)}


def _doc(trip_id: str, line_id: str, doc_id: str) -> dict:
    rows = supabase.table("trip_budget_docs").select("*").eq("trip_id", trip_id).eq("line_id", line_id).eq("id", doc_id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Document not found")
    return rows[0]


@router.post("/{line_id}/documents/{doc_id}/recheck")
def recheck_document(trip_id: str, line_id: str, doc_id: str, me: str = Depends(get_current_user_id)):
    trip_id, trip = _host(trip_id, me)
    line, doc = _line(trip_id, line_id), _doc(trip_id, line_id, doc_id)
    try:
        data = _bucket().download(doc["storage_path"])
    except Exception:
        raise HTTPException(status_code=502, detail="The stored file could not be opened")
    status, notes, extracted = _apply_check(trip, line, data, doc["content_type"])
    supabase.table("trip_budget_docs").update({"check_status": status, "check_notes": notes, "extracted": extracted}).eq("id", doc_id).execute()
    if status == "valid" and line["status"] != "booked":
        supabase.table("trip_budget_lines").update({"status": "booked", "updated_at": _now()}).eq("id", line_id).execute()
    docs = supabase.table("trip_budget_docs").select("*").eq("line_id", line_id).execute().data
    return {"document": _doc_json(_doc(trip_id, line_id, doc_id)), "line": _line_json(_line(trip_id, line_id), docs)}


@router.get("/{line_id}/documents/{doc_id}/url")
def document_url(trip_id: str, line_id: str, doc_id: str, me: str = Depends(get_current_user_id)):
    trip_id, _, _ = _ctx(trip_id, me)
    doc = _doc(trip_id, line_id, doc_id)
    try:
        res = _bucket().create_signed_url(doc["storage_path"], 600)
    except Exception:
        raise HTTPException(status_code=502, detail="The file could not be opened")
    url = (res or {}).get("signedURL") or (res or {}).get("signedUrl") or ""
    if not url:
        raise HTTPException(status_code=502, detail="The file could not be opened")
    return {"url": url, "fileName": doc["file_name"], "contentType": doc["content_type"]}


@router.delete("/{line_id}/documents/{doc_id}")
def delete_document(trip_id: str, line_id: str, doc_id: str, me: str = Depends(get_current_user_id)):
    trip_id, _ = _host(trip_id, me)
    _line(trip_id, line_id)
    doc = _doc(trip_id, line_id, doc_id)
    try:
        _bucket().remove([doc["storage_path"]])
    except Exception as e:
        print(f"[budget-docs] could not remove file: {e}")
    supabase.table("trip_budget_docs").delete().eq("id", doc_id).execute()
    return {"ok": True}
