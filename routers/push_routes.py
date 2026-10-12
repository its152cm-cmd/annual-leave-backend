from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field

import push
from auth import get_current_user_id
from database import supabase

router = APIRouter(prefix="/api/push", tags=["push"])


class TokenIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    token: str = Field(min_length=20, max_length=4096)
    platform: str = Field(default="web", max_length=20)


@router.get("/status")
def status():
    """Whether the server can send push notifications (Firebase is set up)."""
    return {"enabled": push.configured()}


@router.post("/token")
def save_token(body: TokenIn, me: str = Depends(get_current_user_id)):
    """Remembers this browser / phone for the signed-in person. A token belongs to one person at a time."""
    supabase.table("device_tokens").upsert(
        {"token": body.token, "user_id": me, "platform": body.platform, "updated_at": datetime.now(timezone.utc).isoformat()},
        on_conflict="token",
    ).execute()
    return {"success": True}


@router.delete("/token")
def remove_token(token: str, me: str = Depends(get_current_user_id)):
    """Called when signing out, so this device stops getting this person's notifications."""
    supabase.table("device_tokens").delete().eq("token", token).eq("user_id", me).execute()
    return {"success": True}


@router.post("/test")
def send_test(me: str = Depends(get_current_user_id)):
    """Sends a test notification to your own devices (to check the set-up)."""
    mine = push.tokens_for([me])
    push.notify([me], "Annual Leave", "Notifications are working on this device.", kind="reminder", force=True)
    return {"enabled": push.configured(), "devices": len(mine)}
