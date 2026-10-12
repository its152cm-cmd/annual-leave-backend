"""seed.py - fills the database with sample data so the endpoints return something.

Run once from the backend folder (with venv active):   python seed.py
Safe to run again: it will not create duplicate users, trips or messages.
It DOES reset the sample trips' membership and "last read" times, so the unread
counts come back.

What it creates (based on the Flutter mock data):
  - 4 sample users (Sarah, Alex, Ving, Mei). They are real accounts in YOUR
    Supabase project with fake emails and random passwords, so nobody can log
    in as them. Delete them in Authentication -> Users when you no longer need them.
  - your DEV user is renamed "Ying" and given an avatar
  - Kyoto Autumn Getaway   (upcoming, you are host, 5 chat messages, 2 unread)
  - Penang weekend         (draft, solo)
  - Seoul Food & Shopping  (draft, group, you are host)
  - Bali Retreat 2026      (draft, group, Alex is host)
  - Bali Holiday 2025      (completed, solo)
  - Tokyo Spring Blossom   (Sarah invited you - a pending invitation)
"""
import os
import secrets
from datetime import datetime, timedelta, timezone

from dotenv import load_dotenv

from database import supabase

load_dotenv()

DEV_USER_ID = os.getenv("DEV_USER_ID")
if not DEV_USER_ID:
    raise SystemExit("Set DEV_USER_ID in your .env first.")

NOW = datetime.now(timezone.utc)


def ago(minutes: int) -> str:
    return (NOW - timedelta(minutes=minutes)).isoformat()


def get_or_create_user(name: str, email: str, avatar: str) -> str:
    existing = supabase.table("profiles").select("id").eq("email", email).execute().data
    if existing:
        user_id = existing[0]["id"]
    else:
        created = supabase.auth.admin.create_user(
            {
                "email": email,
                "password": secrets.token_urlsafe(24),  # random: nobody can log in
                "email_confirm": True,
                "user_metadata": {"full_name": name},
            }
        )
        user_id = str(created.user.id)  # the signup trigger also creates the profile row
    supabase.table("profiles").update({"full_name": name, "avatar_url": avatar}).eq(
        "id", user_id
    ).execute()
    return user_id


def get_or_create_trip(host_id: str, title: str, fields: dict) -> str:
    existing = (
        supabase.table("trips")
        .select("id")
        .eq("host_id", host_id)
        .eq("title", title)
        .execute()
        .data
    )
    if existing:
        return existing[0]["id"]
    row = {"host_id": host_id, "title": title, **fields}
    return supabase.table("trips").insert(row).execute().data[0]["id"]


def add_member(trip_id, user_id, role, status, last_read_at=None):
    row = {"trip_id": trip_id, "user_id": user_id, "role": role, "status": status}
    if last_read_at:
        row["last_read_at"] = last_read_at
    supabase.table("trip_members").upsert(row, on_conflict="trip_id,user_id").execute()


def add_messages_if_empty(trip_id, messages):
    """messages: list of (sender_id or None for AI, text, minutes_ago)"""
    existing = (
        supabase.table("chat_messages").select("id").eq("trip_id", trip_id).limit(1).execute().data
    )
    if existing:
        return
    rows = [
        {
            "trip_id": trip_id,
            "sender_id": sender,
            "text": text,
            "type": "text",
            "is_ai_response": sender is None,
            "created_at": ago(minutes),
        }
        for sender, text, minutes in messages
    ]
    supabase.table("chat_messages").insert(rows).execute()


def upsert_summary(trip_id, **fields):
    supabase.table("trip_summaries").upsert(
        {"trip_id": trip_id, **fields}, on_conflict="trip_id"
    ).execute()


def main():
    me = DEV_USER_ID
    found = supabase.table("profiles").select("id").eq("id", me).execute().data
    if not found:
        raise SystemExit("DEV_USER_ID was not found in the profiles table. Check .env.")
    supabase.table("profiles").update(
        {
            "full_name": "Ying",
            "avatar_url": "https://i.pravatar.cc/150?img=6",
            "countries_visited": 8,
            "cities_explored": 32,
            "distance_travelled_km": 2450,
        }
    ).eq("id", me).execute()

    sarah = get_or_create_user("Sarah Jenkins", "sarah.jenkins@example.com", "https://i.pravatar.cc/150?img=5")
    alex = get_or_create_user("Alex Wong", "alex.wong@example.com", "https://i.pravatar.cc/150?img=2")
    ving = get_or_create_user("Ving Ang", "ving.ang@example.com", "https://i.pravatar.cc/150?img=3")
    mei = get_or_create_user("Mei Chen", "mei.chen@example.com", "https://i.pravatar.cc/150?img=4")

    # ---- Kyoto: upcoming ----
    kyoto = get_or_create_trip(me, "Kyoto Autumn Getaway", {
        "trip_type": "group", "destination": "Kyoto, Japan",
        "destination_city": "Osaka", "destination_code": "KIX",
        "origin_city": "Kuala Lumpur", "origin_code": "KUL",
        "flag_emoji": "🇯🇵", "start_date": "2026-10-12", "end_date": "2026-10-18",
        "budget_min": 1000, "budget_max": 2000, "currency": "MYR", "traveller_count": 4,
        "image_url": "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=300&q=80",
        "status": "upcoming",
    })
    add_member(kyoto, me, "Host", "accepted", last_read_at=ago(165))  # 2 messages newer than this
    for friend in (alex, ving, mei):
        add_member(kyoto, friend, "Member", "accepted")
    add_messages_if_empty(kyoto, [
        (alex, "I'm thinking of Tokyo for our next trip. What do you think?", 190),
        (ving, "Sounds great! I've been wanting to visit the new Ghibli Museum.", 180),
        (mei, "Kyoto's a place we can consider too for planning this trip.", 170),
        (alex, "RM 1,000 to RM 5,000. Let's avoid super crowded areas.", 160),
        (None, "Kyoto is a historic Japanese city famous for its classical Buddhist temples, peaceful gardens, and traditional wooden houses.", 150),
    ])
    upsert_summary(
        kyoto,
        confirmed_details={"Destination": "Kyoto, Japan", "Dates": "Oct 12 - 18",
                           "Traveller": "4 Friends", "Duration": "6 days", "Budget": "RM2000"},
        pending_decisions=["Budget", "Accommodation", "Transport"],
        preference_tags=["no seafood", "prefers transit", "low-crowd spaces"],
        completed_items=5, total_items=7, is_ready_to_plan=True,
    )

    # ---- Penang: solo draft ----
    penang = get_or_create_trip(me, "Penang weekend", {
        "trip_type": "solo", "destination": "Penang, Malaysia",
        "origin_city": "Kuala Lumpur", "flag_emoji": "🇲🇾",
        "start_date": "2026-12-12", "end_date": "2026-12-18",
        "budget_min": 3000, "budget_max": 3000, "currency": "MYR", "traveller_count": 4,
        "image_url": "https://thumb.wikimedia.org/wikipedia/commons/thumb/6/65/Skyline_of_George_Town%2C_Penang_at_night_Nov2024-29-17.jpg/1280px-Skyline_of_George_Town%2C_Penang_at_night_Nov2024-29-17.jpg",
        "status": "draft",
    })
    add_member(penang, me, "Host", "accepted")

    # ---- Seoul: group draft ----
    seoul = get_or_create_trip(me, "Seoul Food & Shopping", {
        "trip_type": "group", "destination": "Seoul, South Korea",
        "flag_emoji": "🇰🇷", "start_date": "2026-12-12", "end_date": "2026-12-17",
        "budget_min": 2000, "budget_max": 3500, "currency": "MYR", "traveller_count": 2,
        "image_url": "https://images.unsplash.com/photo-1538485399081-7191377e8241?auto=format&fit=crop&w=300&q=80",
        "status": "draft",
    })
    add_member(seoul, me, "Host", "accepted", last_read_at=ago(0))
    add_member(seoul, mei, "Member", "accepted")
    add_messages_if_empty(seoul, [(mei, "Added Myeongdong street food to preferences", 4320)])
    upsert_summary(
        seoul,
        confirmed_details={"Destination": "Seoul, South Korea", "Dates": "Dec 12 - 17"},
        pending_decisions=["Accommodation"],
        preference_tags=["street food", "shopping"],
        completed_items=6, total_items=7, is_ready_to_plan=False,
    )

    # ---- Bali Retreat: group draft, Alex is host ----
    bali = get_or_create_trip(alex, "Bali Retreat 2026", {
        "trip_type": "group", "destination": "Bali, Indonesia",
        "flag_emoji": "🇮🇩", "start_date": "2027-01-20", "end_date": "2027-01-27",
        "budget_min": 2000, "budget_max": 4000, "currency": "MYR", "traveller_count": 3,
        "image_url": "https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=300&q=80",
        "status": "draft",
    })
    add_member(bali, alex, "Host", "accepted")
    add_member(bali, me, "Member", "accepted", last_read_at=ago(0))
    add_member(bali, ving, "Member", "accepted")
    add_messages_if_empty(bali, [(alex, "Should we book the villa near Canggu?", 1440)])

    # ---- Bali Holiday 2025: completed, solo ----
    bali_old = get_or_create_trip(me, "Bali Holiday 2025", {
        "trip_type": "solo", "destination": "Bali, Indonesia",
        "origin_city": "Kuala Lumpur", "flag_emoji": "🇮🇩",
        "start_date": "2025-02-12", "end_date": "2025-02-18",
        "budget_min": 1800, "budget_max": 1800, "currency": "MYR", "traveller_count": 2,
        "image_url": "https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=1000&q=80",
        "status": "completed",
    })
    add_member(bali_old, me, "Host", "accepted")

    # ---- Tokyo: a pending invitation for you ----
    tokyo = get_or_create_trip(sarah, "Tokyo Spring Blossom", {
        "trip_type": "group", "destination": "Tokyo, Japan",
        "flag_emoji": "🇯🇵", "start_date": "2027-04-15", "end_date": "2027-04-22",
        "budget_min": 3000, "budget_max": 5000, "currency": "MYR",
        "image_url": "", "status": "draft",
    })
    add_member(tokyo, sarah, "Host", "accepted")
    add_member(tokyo, me, "Member", "invited")

    print("Seed complete. Try GET /api/me, /api/trips, /api/chats, /api/invitations.")


if __name__ == "__main__":
    main()
