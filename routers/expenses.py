"""Group expenses: receipts, who pays what share, and who has paid back.

The JSON matches the Flutter Receipt model (camelCase). Money is stored per
receipt item; each person's share is worked out in the app from the item
assignments or the split percentages, and the settled amount is saved here.
"""
import base64
import binascii
import os
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field

import budget_watch
import gemini
from auth import get_current_user_id
from database import supabase
from queries import display_name, fetch_profiles, require_accepted_member, require_uuid

router = APIRouter(prefix="/api/expenses", tags=["expenses"])

CATEGORIES = ["Transport", "Accommodation", "Food", "Activities", "Other Expenses"]
COLORS = [0xFF66BB6A, 0xFF7E57C2, 0xFFFFB74D, 0xFF42A5F5, 0xFFEF5350, 0xFF26C6DA, 0xFFEC407A, 0xFF8D6E63]
MAX_RECEIPTS = 500


def _money(value) -> float:
    try:
        return round(float(value or 0), 2)
    except (TypeError, ValueError):
        return 0.0


def _initials(name: str) -> str:
    return "".join(p[0] for p in name.split()[:2]).upper() or "?"


def _canonical_category(value: str) -> str:
    v = (value or "").strip().lower()
    for c in CATEGORIES:
        if c.lower() == v:
            return c
    return {"activity": "Activities", "other": "Other Expenses"}.get(v, "Other Expenses")


def _members(trip_id: str) -> list[dict]:
    """People who share the expenses. Host first, then in the order they were added.

    While testing, people who are invited but have not answered also count
    (EXPENSE_INCLUDE_INVITED=true, the default for now). For the real app set
    EXPENSE_INCLUDE_INVITED=false in .env so only people who accepted can split.
    """
    statuses = ["accepted"]
    if os.getenv("EXPENSE_INCLUDE_INVITED", "true").strip().lower() not in ("false", "0", "no"):
        statuses.append("invited")
    rows = (
        supabase.table("trip_members")
        .select("user_id,role,joined_at")
        .eq("trip_id", trip_id)
        .in_("status", statuses)
        .execute()
        .data
    )
    rows.sort(key=lambda r: (r.get("role") != "Host", str(r.get("joined_at"))))
    profiles = fetch_profiles([r["user_id"] for r in rows])
    return [
        {"id": r["user_id"], "role": r.get("role") or "Member", "profile": profiles.get(r["user_id"], {})}
        for r in rows
    ]


def _trip(trip_id: str, me: str) -> tuple[str, list[dict]]:
    trip_id = require_uuid(trip_id, "trip id")
    require_accepted_member(trip_id, me)
    return trip_id, _members(trip_id)


def _timestamp(receipt_at, people: int, resolved: bool) -> str:
    try:
        day = datetime.fromisoformat(str(receipt_at).replace("Z", "+00:00"))
        when = f"{day.day} {day.strftime('%B %Y')}"
    except ValueError:
        when = ""
    state = "Settled" if resolved else "Pending split"
    return " · ".join(x for x in (when, f"{people} {'person' if people == 1 else 'people'}", state) if x)


def _receipt_json(trip_id: str, members: list[dict], receipt: dict) -> dict:
    rid = receipt["id"]
    by_id = {m["id"]: m for m in members}
    color = {m["id"]: COLORS[i % len(COLORS)] for i, m in enumerate(members)}

    items = supabase.table("receipt_items").select("id,title,price,quantity").eq("receipt_id", rid).execute().data
    assigned: dict[str, list[str]] = {}
    if items:
        rows = (
            supabase.table("receipt_item_assignments")
            .select("item_id,user_id")
            .in_("item_id", [i["id"] for i in items])
            .execute()
            .data
        )
        for r in rows:
            assigned.setdefault(r["item_id"], []).append(r["user_id"])
    splits = (
        supabase.table("receipt_member_splits")
        .select("user_id,split_percentage,settled_amount")
        .eq("receipt_id", rid)
        .execute()
        .data
    )

    def name_of(uid):
        return display_name(by_id[uid]["profile"]) if uid in by_id else "Former member"

    payer = receipt.get("paid_by")
    payer_profile = by_id.get(payer, {}).get("profile", {})
    resolved = receipt.get("status") == "settled"
    return {
        "id": rid,
        "merchantName": receipt["merchant_name"],
        "type": receipt.get("category") or "Other Expenses",
        "timestamp": _timestamp(receipt.get("receipt_at"), len(splits), resolved),
        "peopleCount": len(splits),
        "items": [
            {
                "id": i["id"],
                "title": i["title"],
                "price": _money(i["price"]),
                "quantity": int(i["quantity"] or 1),
                "assignedMemberIds": [u for u in assigned.get(i["id"], []) if u in by_id],
            }
            for i in items
        ],
        "memberSplits": [
            {
                "id": s["user_id"],
                "name": name_of(s["user_id"]),
                "colorHex": color.get(s["user_id"], 0xFF9E9E9E),
                "avatarUrl": (by_id.get(s["user_id"], {}).get("profile") or {}).get("avatar_url"),
                "splitPercentage": int(s["split_percentage"] or 0),
                "settledAmount": _money(s["settled_amount"]),
            }
            for s in splits
        ],
        "paidByMemberId": payer or "",
        "paidByMemberName": name_of(payer) if payer else "",
        "paidByMemberAvatar": _initials(name_of(payer)) if payer else "",
        "paidByMemberAvatarUrl": payer_profile.get("avatar_url"),
        "splitResolved": resolved,
    }


def _load_receipt(trip_id: str, receipt_id: str) -> dict:
    receipt_id = require_uuid(receipt_id, "receipt id")
    rows = (
        supabase.table("receipts")
        .select("id,trip_id,merchant_name,category,receipt_at,paid_by,status")
        .eq("id", receipt_id)
        .eq("trip_id", trip_id)
        .execute()
        .data
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Receipt not found")
    return rows[0]


# ----------------------------------------------------------------- reads

@router.get("/{trip_id}/members")
def list_members(trip_id: str, me: str = Depends(get_current_user_id)):
    """The people who share this trip's expenses (GroupMember JSON)."""
    trip_id, members = _trip(trip_id, me)
    return [
        {
            "id": m["id"],
            "name": display_name(m["profile"]),
            "role": m["role"],
            "avatarUrl": m["profile"].get("avatar_url"),
            "isMe": m["id"] == me,
        }
        for m in members
    ]


@router.get("/{trip_id}/receipts")
def list_receipts(trip_id: str, me: str = Depends(get_current_user_id)):
    trip_id, members = _trip(trip_id, me)
    rows = (
        supabase.table("receipts")
        .select("id,trip_id,merchant_name,category,receipt_at,paid_by,status")
        .eq("trip_id", trip_id)
        .order("receipt_at", desc=True)
        .execute()
        .data
    )
    return [_receipt_json(trip_id, members, r) for r in rows]


# ---------------------------------------------------------------- create

class ItemIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    title: str
    price: float = Field(ge=0, le=1_000_000)
    quantity: int = Field(default=1, ge=1, le=99)
    assignedMemberIds: list[str] = []


class SplitIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str
    splitPercentage: int = Field(default=0, ge=0, le=100)
    settledAmount: float = Field(default=0, ge=0, le=1_000_000)


class ReceiptIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    merchantName: str
    type: str = "Other Expenses"
    items: list[ItemIn]
    memberSplits: list[SplitIn] = []
    paidByMemberId: str | None = None


@router.post("/{trip_id}/receipts")
def create_receipt(trip_id: str, body: ReceiptIn, me: str = Depends(get_current_user_id)):
    """Saves a confirmed split. Item and receipt ids are made here; the answer carries them."""
    trip_id, members = _trip(trip_id, me)
    ids = {m["id"] for m in members}

    name = " ".join(body.merchantName.split())
    if not name or len(name) > 120:
        raise HTTPException(status_code=422, detail="Merchant name must be 1-120 characters")
    if not body.items or len(body.items) > 100:
        raise HTTPException(status_code=422, detail="A receipt needs 1-100 items")
    for item in body.items:
        if not item.title.strip() or len(item.title) > 120:
            raise HTTPException(status_code=422, detail="Every item needs a name (120 characters max)")
        if any(u not in ids for u in item.assignedMemberIds):
            raise HTTPException(status_code=422, detail="An item is assigned to someone who is not on this trip")
    payer = body.paidByMemberId or me
    if payer not in ids:
        raise HTTPException(status_code=422, detail="The payer is not on this trip")
    if any(s.id not in ids for s in body.memberSplits):
        raise HTTPException(status_code=422, detail="A split belongs to someone who is not on this trip")
    existing = supabase.table("receipts").select("id").eq("trip_id", trip_id).execute().data
    if len(existing) >= MAX_RECEIPTS:
        raise HTTPException(status_code=409, detail="This trip has too many receipts")

    itemised = any(i.assignedMemberIds for i in body.items)
    receipt = (
        supabase.table("receipts")
        .insert(
            {
                "trip_id": trip_id,
                "merchant_name": name,
                "category": _canonical_category(body.type),
                "receipt_at": datetime.now(timezone.utc).isoformat(),
                "paid_by": payer,
                "split_mode": "itemized" if itemised else "even",
                "status": "pending",
            }
        )
        .execute()
        .data[0]
    )
    rid = receipt["id"]
    try:
        made = (
            supabase.table("receipt_items")
            .insert([{"receipt_id": rid, "title": i.title.strip(), "price": round(i.price, 2), "quantity": i.quantity} for i in body.items])
            .execute()
            .data
        )
        links = [
            {"item_id": row["id"], "user_id": u}
            for row, item in zip(made, body.items)
            for u in dict.fromkeys(item.assignedMemberIds)
        ]
        if links:
            supabase.table("receipt_item_assignments").insert(links).execute()
        # everyone on the trip appears in the split, even with 0%
        given = {s.id: s for s in body.memberSplits}
        supabase.table("receipt_member_splits").insert(
            [
                {
                    "receipt_id": rid,
                    "user_id": m["id"],
                    "split_percentage": given[m["id"]].splitPercentage if m["id"] in given else 0,
                    "settled_amount": 0,
                }
                for m in members
            ]
        ).execute()
    except Exception:
        supabase.table("receipts").delete().eq("id", rid).execute()  # no half-saved receipt
        raise
    saved = _receipt_json(trip_id, members, _load_receipt(trip_id, rid))
    status = budget_watch.check(trip_id, announce=True)
    if status["level"]:
        saved["budgetAlert"] = {k: status[k] for k in ("level", "message", "budget", "spent", "percent")}
    return saved


@router.get("/{trip_id}/budget-status")
def budget_status(trip_id: str, me: str = Depends(get_current_user_id)):
    """Spent so far against the trip budget, for the warning banner."""
    trip_id, _ = _trip(trip_id, me)
    s = budget_watch.check(trip_id, announce=False)
    return {k: s.get(k) for k in ("level", "message", "budget", "spent", "percent", "projected")}


# ---------------------------------------------------------------- settle

class SettleSplit(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str
    settledAmount: float = Field(ge=0, le=1_000_000)


class SettleIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    memberSplits: list[SettleSplit] = []
    splitResolved: bool | None = None


@router.patch("/{trip_id}/receipts/{receipt_id}")
def settle_receipt(trip_id: str, receipt_id: str, body: SettleIn, me: str = Depends(get_current_user_id)):
    """Saves who has paid their share back (and whether the receipt is fully settled)."""
    trip_id, members = _trip(trip_id, me)
    receipt = _load_receipt(trip_id, receipt_id)
    ids = {m["id"] for m in members}
    if any(s.id not in ids for s in body.memberSplits):
        raise HTTPException(status_code=422, detail="A split belongs to someone who is not on this trip")
    for s in body.memberSplits:
        supabase.table("receipt_member_splits").update({"settled_amount": round(s.settledAmount, 2)}).eq(
            "receipt_id", receipt["id"]
        ).eq("user_id", s.id).execute()
    if body.splitResolved is not None:
        supabase.table("receipts").update({"status": "settled" if body.splitResolved else "pending"}).eq(
            "id", receipt["id"]
        ).execute()
    return _receipt_json(trip_id, members, _load_receipt(trip_id, receipt["id"]))


@router.delete("/{trip_id}/receipts/{receipt_id}")
def delete_receipt(trip_id: str, receipt_id: str, me: str = Depends(get_current_user_id)):
    """Only the person who paid, or the host, can remove a receipt."""
    trip_id, members = _trip(trip_id, me)
    receipt = _load_receipt(trip_id, receipt_id)
    host = next((m["id"] for m in members if m["role"] == "Host"), None)
    if me not in (receipt.get("paid_by"), host):
        raise HTTPException(status_code=403, detail="Only the payer or the host can delete a receipt")
    supabase.table("receipts").delete().eq("id", receipt["id"]).execute()
    budget_watch.check(trip_id, announce=False)  # a removed expense can clear a warning
    return {"ok": True}


# ------------------------------------------------------------------ scan

MAX_IMAGE_BYTES = 6 * 1024 * 1024
IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}


class ScanIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    imageBase64: str
    mimeType: str = "image/jpeg"


def _scan_schema() -> dict:
    s, n = {"type": "STRING"}, {"type": "NUMBER"}
    return {
        "type": "OBJECT",
        "properties": {
            "merchant_name": s,
            "category": s,
            "items": {
                "type": "ARRAY",
                "items": {
                    "type": "OBJECT",
                    "properties": {"title": s, "unit_price": n, "quantity": n},
                    "required": ["title", "unit_price", "quantity"],
                },
            },
        },
        "required": ["merchant_name", "items"],
    }


SCAN_PROMPT = f"""Read this receipt photo and answer with JSON only.

- merchant_name: the shop or restaurant name as printed.
- category: exactly one of {", ".join(CATEGORIES)}.
- items: every line the customer paid for. title is the item name as printed, unit_price is the price of ONE unit as a plain number, quantity is a whole number (1 if not shown).
- Include tax, service charge or rounding as their own lines ("Service charge", "Tax") so the total matches the receipt. Do not include the grand total, subtotal, change or payment method lines.
- If the photo is not a receipt or nothing is readable, answer {{"merchant_name": "", "items": []}}. Never invent items.

Answer with JSON only: {{"merchant_name": "...", "category": "Food", "items": [{{"title": "...", "unit_price": 12.5, "quantity": 2}}]}}"""


@router.post("/{trip_id}/scan")
def scan_receipt(trip_id: str, body: ScanIn, me: str = Depends(get_current_user_id)):
    """Reads a receipt photo with Gemini and returns a draft to review and split (not saved yet)."""
    trip_id, members = _trip(trip_id, me)
    mime = body.mimeType.strip().lower()
    if mime not in IMAGE_TYPES:
        raise HTTPException(status_code=422, detail="Please use a JPG, PNG or WebP photo")
    try:
        data = base64.b64decode(body.imageBase64, validate=False)
    except (binascii.Error, ValueError):
        raise HTTPException(status_code=422, detail="The photo could not be read")
    if not data:
        raise HTTPException(status_code=422, detail="The photo is empty")
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="The photo is too large (6 MB max)")
    try:
        raw = gemini.generate_json(SCAN_PROMPT, schema=_scan_schema(), temperature=0.1, fast=True, image=(data, mime))
    except gemini.GeminiError as e:
        raise HTTPException(status_code=e.status, detail=e.message)
    if not isinstance(raw, dict):
        raise HTTPException(status_code=502, detail="The AI answered in an unexpected format. Please try again.")

    everyone = [m["id"] for m in members]
    items = []
    for entry in (raw.get("items") or [])[:60]:
        if not isinstance(entry, dict):
            continue
        title = " ".join(str(entry.get("title") or "").split())[:120]
        price = _money(entry.get("unit_price"))
        try:
            qty = int(round(float(entry.get("quantity") or 1)))
        except (TypeError, ValueError):
            qty = 1
        if not title or price <= 0:
            continue
        items.append({
            "id": f"scan_{len(items) + 1}",
            "title": title,
            "price": min(price, 1_000_000),
            "quantity": max(1, min(qty, 99)),
            "assignedMemberIds": list(everyone),  # shared equally until edited
        })
    if not items:
        raise HTTPException(status_code=422, detail="Couldn't read any items from that photo. Try a clearer, well-lit picture of the whole receipt.")

    by_id = {m["id"]: m for m in members}
    base, extra = 100 // len(everyone), 100 % len(everyone)
    me_profile = by_id[me]["profile"]
    return {
        "id": "scan_receipt",
        "merchantName": " ".join(str(raw.get("merchant_name") or "").split())[:120] or "Receipt",
        "type": _canonical_category(str(raw.get("category") or "")),
        "timestamp": _timestamp(datetime.now(timezone.utc).isoformat(), len(everyone), False).replace("Pending split", "Scanned"),
        "peopleCount": len(everyone),
        "items": items,
        "memberSplits": [
            {
                "id": uid,
                "name": display_name(by_id[uid]["profile"]),
                "colorHex": COLORS[i % len(COLORS)],
                "avatarUrl": by_id[uid]["profile"].get("avatar_url"),
                "splitPercentage": base + (1 if i < extra else 0),
                "settledAmount": 0,
            }
            for i, uid in enumerate(everyone)
        ],
        "paidByMemberId": me,
        "paidByMemberName": display_name(me_profile),
        "paidByMemberAvatar": _initials(display_name(me_profile)),
        "paidByMemberAvatarUrl": me_profile.get("avatar_url"),
        "splitResolved": False,
    }
