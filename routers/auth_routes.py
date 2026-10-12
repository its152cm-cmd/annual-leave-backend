"""Sign up / sign in / refresh with Supabase Auth. The Flutter login screen talks to these."""
import os
import re

from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict
from supabase import create_client

from database import supabase
from routers.users import _get_profile, _profile_json

load_dotenv()
router = APIRouter(prefix="/api/auth", tags=["auth"])

EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


# --- the only two functions that talk to Supabase Auth (tests replace them) ---
def _fresh_client():
    """A separate client per call, so the main backend client keeps its secret key."""
    return create_client(os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_SECRET_KEY"))


def _password_login(email: str, password: str) -> dict:
    try:
        res = _fresh_client().auth.sign_in_with_password({"email": email, "password": password})
    except Exception:
        raise HTTPException(status_code=401, detail="Wrong email or password")
    if not res or not res.session or not res.user:
        raise HTTPException(status_code=401, detail="Wrong email or password")
    return {"token": res.session.access_token, "refreshToken": res.session.refresh_token, "userId": str(res.user.id)}


def _refresh(refresh_token: str) -> dict:
    try:
        res = _fresh_client().auth.refresh_session(refresh_token)
    except Exception:
        raise HTTPException(status_code=401, detail="Session expired, please sign in again")
    if not res or not res.session or not res.user:
        raise HTTPException(status_code=401, detail="Session expired, please sign in again")
    return {"token": res.session.access_token, "refreshToken": res.session.refresh_token, "userId": str(res.user.id)}


def _create_user(email: str, password: str, name: str) -> None:
    try:
        supabase.auth.admin.create_user(
            {"email": email, "password": password, "email_confirm": True, "user_metadata": {"full_name": name}}
        )
    except Exception as e:
        text = str(e).lower()
        if "already" in text or "registered" in text or "exists" in text:
            raise HTTPException(status_code=409, detail="An account with this email already exists")
        raise HTTPException(status_code=400, detail="Couldn't create the account. Try a different password.")


# ------------------------------------------------------------------ routes
class LoginIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    email: str
    password: str


class SignupIn(LoginIn):
    name: str = ""


class RefreshIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    refreshToken: str


def _session_json(session: dict) -> dict:
    return {**session, "profile": _profile_json(_get_profile(session["userId"]))}


def _clean_email(email: str) -> str:
    email = email.strip().lower()
    if not EMAIL.match(email):
        raise HTTPException(status_code=422, detail="Enter a valid email address")
    return email


@router.post("/login")
def login(body: LoginIn):
    email = _clean_email(body.email)
    if not body.password:
        raise HTTPException(status_code=422, detail="Enter your password")
    return _session_json(_password_login(email, body.password))


@router.post("/signup")
def signup(body: SignupIn):
    email = _clean_email(body.email)
    if len(body.password) < 6:
        raise HTTPException(status_code=422, detail="Password must be at least 6 characters")
    name = " ".join(body.name.split())[:80] or email.split("@")[0]
    _create_user(email, body.password, name)
    return _session_json(_password_login(email, body.password))


@router.post("/refresh")
def refresh(body: RefreshIn):
    return _session_json(_refresh(body.refreshToken))
