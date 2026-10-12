import os

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from database import supabase
from routers import auth_routes, budget_lines, checklist, chat_ai, chat_polls, chats, collaborators, expenses, favourites, invitations, itinerary, itinerary_review, leave, options, planning, replan, trips, users, voice, routes, push_routes

app = FastAPI(title="Annual Leave API")

# Flutter Web runs in the browser, so the backend must allow cross-origin calls.
# CORS_ORIGINS in .env = the web app address(es), comma separated, e.g. https://your-app.web.app
# Not set = anyone may call (fine for local development only).
_origins = [o.strip().rstrip("/") for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins or ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_routes.router)
app.include_router(users.router)
app.include_router(trips.router)
app.include_router(invitations.router)
app.include_router(collaborators.router)
app.include_router(chats.router)
app.include_router(leave.router)
app.include_router(itinerary.router)
app.include_router(options.router)
app.include_router(checklist.router)
app.include_router(expenses.router)
app.include_router(planning.router)
app.include_router(favourites.router)
app.include_router(chat_polls.router)
app.include_router(chat_ai.router)
app.include_router(itinerary_review.router)
app.include_router(replan.router)
app.include_router(budget_lines.router)
app.include_router(voice.router)
app.include_router(routes.router)
app.include_router(push_routes.router)


@app.get("/health")
def health():
    """Server is running."""
    return {"status": "ok"}


@app.get("/health/db")
def health_db():
    """Server can reach Supabase and read from the database."""
    try:
        result = supabase.table("profiles").select("id").limit(1).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database check failed: {e}")
    return {"status": "ok", "database": "connected", "profiles_found": len(result.data)}
