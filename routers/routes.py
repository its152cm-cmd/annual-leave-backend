"""How to get from one stop of a day to the next: real walking / driving time and distance.

Places are found on the map (Geoapify geocoding) and the route is calculated by
Geoapify Routing, so the numbers are real, not made up. If routing is unavailable
the straight-line distance is used and the result is marked as an estimate.
"""
import math
import re
from concurrent.futures import ThreadPoolExecutor

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, field_validator

from auth import get_current_user_id
from database import supabase
from routers.options import _cached, _geo_get, _store, geocode

router = APIRouter(prefix="/api/routes", tags=["routes"])

SKIP_TYPES = {"flight", "transit", "transport"}
PREFIXES = re.compile(r"^(check[- ]?in|check[- ]?out|arrive at|visit|lunch at|dinner at|breakfast at|lunch|dinner|breakfast|stay at)\s*[:\-]?\s*", re.I)


def _cut(v, n):
    return str(v if v is not None else "")[:n]


class PlaceIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = ""
    title: str = ""
    type: str = ""

    @field_validator("id", "title", "type", mode="before")
    @classmethod
    def _short(cls, v):
        return _cut(v, 160)


class LegsIn(BaseModel):
    """Lenient on purpose: a long day or a missing city must give an empty answer, not a 422."""
    model_config = ConfigDict(extra="ignore")
    city: str = ""
    places: list[PlaceIn] = []

    @field_validator("city", mode="before")
    @classmethod
    def _city(cls, v):
        return _cut(v, 120)

    @field_validator("places", mode="after")
    @classmethod
    def _cap(cls, v):
        return v[:14]


def clean_name(title: str) -> str:
    name = PREFIXES.sub("", title.strip())
    return " ".join(name.split())


def haversine_m(a: tuple[float, float], b: tuple[float, float]) -> float:
    """a and b are (lon, lat)."""
    lo1, la1, lo2, la2 = (math.radians(x) for x in (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 6371000 * 2 * math.asin(math.sqrt(h))


def find_point(name: str, city: str) -> tuple[float, float] | None:
    """(lon, lat) of the named place in the city, or None when the map cannot find it."""
    key = ("routepoint", name.lower(), city.lower())
    hit = _cached(key)
    if hit is not None:
        return hit or None
    try:
        lon, lat = geocode(city)
        data = _geo_get("/v1/geocode/search", {
            "text": f"{name}, {city}", "limit": 1, "format": "json",
            "filter": f"circle:{lon},{lat},30000", "bias": f"proximity:{lon},{lat}",
        })
    except HTTPException:
        return None
    res = (data.get("results") or [None])[0]
    if not res or str(res.get("result_type") or "") in ("country", "state", "county", "postcode", "city"):
        return None
    got = {w for w in re.findall(r"[a-z0-9]{3,}", f"{res.get('name') or ''} {res.get('address_line1') or ''}".lower())}
    want = {w for w in re.findall(r"[a-z0-9]{3,}", name.lower())}
    # Names in other scripts have no latin words to compare; trust the map's own match for those.
    if want and got and not (want & got):
        return _store(key, ())
    return _store(key, (float(res["lon"]), float(res["lat"])))


def _route_full(a: tuple[float, float], b: tuple[float, float], mode: str):
    """(metres, seconds, line) from Geoapify Routing, or None. line is [[lat, lon], ...]."""
    key = ("routefull", round(a[0], 5), round(a[1], 5), round(b[0], 5), round(b[1], 5), mode)
    hit = _cached(key)
    if hit is not None:
        return hit or None
    try:
        data = _geo_get("/v1/routing", {"waypoints": f"{a[1]},{a[0]}|{b[1]},{b[0]}", "mode": mode})
        feat = (data.get("features") or [{}])[0]
        props = feat.get("properties") or {}
        geom = feat.get("geometry") or {}
        coords = geom.get("coordinates") or []
        if geom.get("type") == "MultiLineString":
            coords = [c for part in coords for c in part]
        line = [[float(c[1]), float(c[0])] for c in coords if isinstance(c, (list, tuple)) and len(c) >= 2]
        if len(line) > 150:  # keep the answer small
            step = len(line) / 150
            line = [line[int(i * step)] for i in range(150)] + [line[-1]]
        return _store(key, (float(props["distance"]), float(props["time"]), line))
    except (HTTPException, KeyError, TypeError, ValueError):
        return None


def route(a: tuple[float, float], b: tuple[float, float], mode: str) -> tuple[float, float] | None:
    """(metres, seconds) from Geoapify Routing, or None."""
    full = _route_full(a, b, mode)
    return (full[0], full[1]) if full else None


def leg_between(a: tuple[float, float], b: tuple[float, float], max_walk_min: int) -> dict:
    straight = haversine_m(a, b)
    estimated = False
    walk = route(a, b, "walk") if straight <= 4000 else None
    if walk and walk[1] / 60 <= max_walk_min:
        metres, minutes, method = walk[0], walk[1] / 60, "walk"
    else:
        drive = route(a, b, "drive")
        if drive:
            metres, minutes = drive
            minutes /= 60
        else:  # routing unavailable: straight line, roads are about 1.3x longer
            estimated = True
            metres = straight * 1.3
            on_foot = straight <= 1500
            minutes = metres / 1000 / (4.5 if on_foot else 25) * 60
        if estimated and straight <= 1500 and minutes <= max_walk_min:
            method = "walk"
        else:
            method = "taxi" if metres < 15000 else "transit"
    mins = max(1, round(minutes))
    km = metres / 1000
    dist = f"{km:.1f} km" if km >= 1 else f"{int(round(metres / 10) * 10)} m"
    name = {"walk": "Walk", "taxi": "Taxi", "transit": "Train / taxi"}[method]
    approx = "about " if estimated else ""
    suffix = " by car" if method == "transit" else ""
    return {"method": method, "minutes": mins, "km": round(km, 2), "estimated": estimated,
            "label": f"{name} · {approx}{mins} min{suffix} · {dist}"}


def _max_walk(me: str) -> int:
    rows = supabase.table("user_settings").select("max_walking_minutes").eq("user_id", me).execute().data
    return int((rows[0].get("max_walking_minutes") if rows else None) or 15)


@router.post("/legs")
def legs(body: LegsIn, me: str = Depends(get_current_user_id)):
    """For stops in order, the way from each stop to the next: {legs: [{toId, method, minutes, km, label, estimated}]}."""
    city = body.city.split("→")[0].split(",")[0].strip()
    stops = [p for p in body.places if p.id and p.type.lower() not in SKIP_TYPES and clean_name(p.title)]
    if not city or len(stops) < 2:
        return {"legs": []}
    max_walk = _max_walk(me)
    with ThreadPoolExecutor(max_workers=6) as pool:
        points = list(pool.map(lambda p: find_point(clean_name(p.title), city), stops))
    pairs = [(i, points[i - 1], points[i]) for i in range(1, len(stops)) if points[i - 1] and points[i]]
    with ThreadPoolExecutor(max_workers=6) as pool:
        found = list(pool.map(lambda t: leg_between(t[1], t[2], max_walk), pairs))
    out = []
    for (i, _, _), leg in zip(pairs, found):
        out.append({"fromId": stops[i - 1].id, "toId": stops[i].id, **leg})
    return {"legs": out}


@router.post("/map")
def day_map(body: LegsIn, me: str = Depends(get_current_user_id)):
    """The day on a map: {points: [{id, title, type, lat, lon, number}], lines: [{fromId, toId, method, label, path: [[lat, lon], ...]}], googleUrl}."""
    city = body.city.split("→")[0].split(",")[0].strip()
    stops = [p for p in body.places if p.id and p.type.lower() not in SKIP_TYPES and clean_name(p.title)]
    if not city or not stops:
        return {"points": [], "lines": [], "googleUrl": ""}
    max_walk = _max_walk(me)
    with ThreadPoolExecutor(max_workers=6) as pool:
        found = list(pool.map(lambda p: find_point(clean_name(p.title), city), stops))
    placed = [(p, pt) for p, pt in zip(stops, found) if pt]
    points = [{"id": p.id, "title": clean_name(p.title), "type": p.type, "lat": pt[1], "lon": pt[0], "number": i + 1}
              for i, (p, pt) in enumerate(placed)]

    def line_for(i: int) -> dict:
        (pa, a), (pb, b) = placed[i - 1], placed[i]
        leg = leg_between(a, b, max_walk)
        full = _route_full(a, b, "walk" if leg["method"] == "walk" else "drive")
        path = full[2] if full and full[2] else [[a[1], a[0]], [b[1], b[0]]]
        return {"fromId": pa.id, "toId": pb.id, "method": leg["method"], "label": leg["label"], "path": path}

    with ThreadPoolExecutor(max_workers=6) as pool:
        lines = list(pool.map(line_for, range(1, len(placed))))
    google = ""
    if len(placed) >= 2:
        from urllib.parse import quote
        pts = [f"{pt[1]},{pt[0]}" for _, pt in placed[:10]]
        google = ("https://www.google.com/maps/dir/?api=1&travelmode=walking"
                  f"&origin={quote(pts[0])}&destination={quote(pts[-1])}"
                  + (f"&waypoints={quote('|'.join(pts[1:-1]))}" if len(pts) > 2 else ""))
    return {"points": points, "lines": lines, "googleUrl": google}
