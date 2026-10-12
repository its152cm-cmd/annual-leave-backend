import os

from dotenv import load_dotenv
from supabase import Client, create_client

from safe_db import SafeClient

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY")

if not SUPABASE_URL or not SUPABASE_SECRET_KEY:
    raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SECRET_KEY in your .env file")

# Uses the secret key, so this bypasses RLS. Backend only - never expose it.
supabase: Client = SafeClient(create_client(SUPABASE_URL, SUPABASE_SECRET_KEY))  # type: ignore[assignment]
