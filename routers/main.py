from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from database import supabase
from routers import auth_routes, checklist, chats, collaborators, expenses, favourites, invitations, itinerary, leave, options, planning, trips, users

app = FastAPI(title="Annual Leave API")

# Flutter Web runs in the browser, so the backend must allow cross-origin calls.
# "*" is fine for development; restrict it to your real frontend URL before the demo.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
