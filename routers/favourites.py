"""Each person's own hearts (favourites) in Suggestions. Saved per account."""
import json

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from auth import get_current_user_id
from database import supabase

router = APIRouter(prefix="/api/favourites", tags=["favourites"])


class FavouriteIn(BaseModel):
    key: str = Field(min_length=3, max_length=200)  # e.g. "hotel:12345"
    favourite: bool
    item: dict | None = None  # a small copy of the place, shown in the Favourites list


@router.get("")
def list_favourites(me: str = Depends(get_current_user_id)):
    rows = supabase.table("user_favourites").select("item_key,item").eq("user_id", me).execute().data
    return {
        "keys": [r["item_key"] for r in rows],
        "items": [{"key": r["item_key"], "item": r["item"]} for r in rows if r.get("item")],
    }


@router.put("")
def set_favourite(body: FavouriteIn, me: str = Depends(get_current_user_id)):
    key = body.key.strip()
    if body.favourite:
        row = {"user_id": me, "item_key": key}
        if body.item:
            if len(json.dumps(body.item)) > 6000:
                raise HTTPException(status_code=413, detail="That place is too large to save")
            row["item"] = body.item
        supabase.table("user_favourites").upsert(row, on_conflict="user_id,item_key").execute()
    else:
        supabase.table("user_favourites").delete().eq("user_id", me).eq("item_key", key).execute()
    return {"ok": True}
