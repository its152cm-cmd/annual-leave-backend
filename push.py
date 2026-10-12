"""Push notifications with Firebase Cloud Messaging.

Optional: if FIREBASE_CREDENTIALS is not set (path to the service-account JSON, or the JSON itself in
FIREBASE_CREDENTIALS_JSON) every call here quietly does nothing, so the app works without Firebase.

kind decides which switch in Account > Notifications applies:
  chat -> group chat, trip -> trip updates, reminder -> reminders
"""
import json
import os
import threading

from database import supabase

KIND_COLUMN = {"chat": "notify_group_chat", "trip": "notify_trip_updates", "reminder": "notify_reminders"}

_messaging = None
_tried = False


def configured() -> bool:
    return bool(os.getenv("FIREBASE_CREDENTIALS") or os.getenv("FIREBASE_CREDENTIALS_JSON"))


def _client():
    """firebase_admin.messaging, or None when Firebase is not set up (or the package is missing)."""
    global _messaging, _tried
    if _tried:
        return _messaging
    _tried = True
    if not configured():
        return None
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging

        raw = os.getenv("FIREBASE_CREDENTIALS_JSON")
        cred = credentials.Certificate(json.loads(raw) if raw else os.environ["FIREBASE_CREDENTIALS"])
        firebase_admin.initialize_app(cred)
        _messaging = messaging
    except Exception as e:  # a missing key must never stop the server
        print(f"[push] Firebase is not ready: {e}")
    return _messaging


def _wants(user_id: str, kind: str) -> bool:
    col = KIND_COLUMN.get(kind)
    if not col:
        return True
    rows = supabase.table("user_settings").select(col).eq("user_id", user_id).execute().data
    return rows[0].get(col) is not False if rows else True


def tokens_for(user_ids) -> list[dict]:
    ids = [u for u in set(user_ids) if u]
    if not ids:
        return []
    return supabase.table("device_tokens").select("token,user_id").in_("user_id", ids).execute().data


def _send(token: str, title: str, body: str, data: dict, link: str) -> bool:
    """Sends one message. Returns False when the token is no longer valid (so it can be removed)."""
    messaging = _client()
    if messaging is None:
        return True
    try:
        webpush = messaging.WebpushConfig(
            notification=messaging.WebpushNotification(title=title, body=body),
            fcm_options=messaging.WebpushFCMOptions(link=link) if link else None,
        )
        messaging.send(messaging.Message(token=token, data={k: str(v) for k, v in data.items()}, webpush=webpush))
        print("[push] sent OK")
        return True
    except Exception as e:
        name = type(e).__name__
        print(f"[push] {name}: {e}")
        if name in ("UnregisteredError", "SenderIdMismatchError", "InvalidArgumentError"):
            return False
        print(f"[push] could not send: {e}")
        return True


def _spawn(fn) -> None:
    threading.Thread(target=fn, daemon=True).start()


def notify(user_ids, title: str, body: str, kind: str = "trip", trip_id: str | None = None, force: bool = False) -> None:
    """Pushes to every device of these people (who have this kind switched on). Never raises, never blocks."""
    if not configured():
        return
    users = list(user_ids)

    def work():
        try:
            allowed = [u for u in set(users) if force or _wants(u, kind)]
            if not allowed:
                print(f"[push] skipped: {kind} notifications are switched off for this user")
            link = ""
            base = os.getenv("APP_URL", "").rstrip("/")
            if base.startswith("https://") and trip_id:  # Firebase only accepts https links (not http://localhost)
                link = f"{base}/#/chat/trip_{trip_id}" if kind == "chat" else base
            data = {"kind": kind, **({"tripId": trip_id, "groupId": f"trip_{trip_id}"} if trip_id else {})}
            rows = tokens_for(allowed)
            if not rows:
                print("[push] skipped: no device token saved for this user")
            for row in rows:
                if not _send(row["token"], title[:80], body[:180], data, link):
                    supabase.table("device_tokens").delete().eq("token", row["token"]).execute()
        except Exception as e:
            print(f"[push] {e}")

    _spawn(work)
