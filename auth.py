import os

from dotenv import load_dotenv
from fastapi import Header, HTTPException

from database import supabase

load_dotenv()


def get_current_user_id(authorization: str | None = Header(default=None)) -> str:
    """Works out who is calling.

    1. If the request has "Authorization: Bearer <token>", the token is checked
       with Supabase Auth (this is what the real login screen will use later).
    2. Otherwise, if DEV_USER_ID is set in .env, that user is used. This was a
       development shortcut from before the login screen existed. Real login
       works now, so DELETE the DEV_USER_ID line from .env: with it set, anyone
       who is not signed in is treated as that user.
    """
    if authorization:
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token:
            raise HTTPException(status_code=401, detail="Invalid Authorization header")
        try:
            result = supabase.auth.get_user(token)
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
        if not result or not result.user:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
        return str(result.user.id)

    dev_user_id = os.getenv("DEV_USER_ID")
    if dev_user_id and os.getenv("APP_ENV", "").strip().lower() != "production":
        return dev_user_id

    raise HTTPException(status_code=401, detail="Not signed in")
