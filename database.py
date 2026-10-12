import os

import httpx
from dotenv import load_dotenv
from supabase import Client, create_client

from safe_db import SafeClient

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY")

if not SUPABASE_URL or not SUPABASE_SECRET_KEY:
    raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SECRET_KEY in your .env file")

_client = create_client(SUPABASE_URL, SUPABASE_SECRET_KEY)

# On a hosting service, a long-lived HTTP/2 connection to Supabase goes stale while the server is idle and the next
# request fails with "Server disconnected". Plain HTTP/1.1 with short-lived connections avoids that.
_old = _client.postgrest.session
_client.postgrest.session = httpx.Client(
    base_url=_old.base_url,
    headers=_old.headers,
    timeout=_old.timeout,
    http2=False,
    follow_redirects=True,
    limits=httpx.Limits(max_keepalive_connections=10, keepalive_expiry=4),
)

# Uses the secret key, so this bypasses RLS. Backend only - never expose it.
supabase: Client = SafeClient(_client)  # type: ignore[assignment]
