"""Estimated prices (in Malaysian Ringgit) for places, written by Gemini.

Attractions: entry fee for ONE person (0 = free). Hotels: typical price for one room for one night.
They are estimates, not live prices, and the app says so. Answers are remembered per city + place name."""
import re
import time

import gemini

_cache: dict[tuple, tuple[float, float]] = {}
TTL = 24 * 3600
LIMITS = {"attraction": (0, 1500), "hotel": (40, 8000)}


def _key(kind: str, city: str, name: str) -> tuple:
    return (kind, re.sub(r"\s+", " ", (city or "").split(",")[0]).strip().lower(), re.sub(r"\s+", " ", name or "").strip().lower())


def _schema() -> dict:
    s, n = {"type": "STRING"}, {"type": "NUMBER"}
    return {"type": "OBJECT", "properties": {"prices": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"name": s, "price_myr": n}, "required": ["name", "price_myr"]}}}, "required": ["prices"]}


def _prompt(kind: str, city: str, names: list[str]) -> str:
    what = ("the usual entry fee for ONE adult visitor (0 if it is free to enter)" if kind == "attraction"
            else "the usual price of ONE standard room for ONE night")
    lines = "\n".join(f"- {n}" for n in names)
    return (f"Estimate {what} at each place below in {city}, in Malaysian Ringgit (RM), as a plain number. "
            "Use what is published online and typical current prices; convert from the local currency at an approximate current rate. "
            "Be realistic: parks, temples, shrines and viewpoints are often free or cheap, museums and theme parks cost more, "
            "luxury hotels cost much more than hostels. These are estimates, not live prices.\n"
            f"Places:\n{lines}\n"
            'Answer with JSON only: {"prices": [{"name": "exact name as given", "price_myr": 45}]}')


def estimate(kind: str, city: str, names: list[str]) -> dict[str, float]:
    """{place name: price in RM}. Names the AI could not price are left out."""
    lo, hi = LIMITS[kind]
    now = time.time()
    out: dict[str, float] = {}
    missing: list[str] = []
    for n in dict.fromkeys(x for x in names if x):
        hit = _cache.get(_key(kind, city, n))
        if hit and now - hit[0] < TTL:
            out[n] = hit[1]
        else:
            missing.append(n)
    for i in range(0, len(missing), 30):
        batch = missing[i:i + 30]
        try:
            raw = gemini.generate_json(_prompt(kind, city, batch), schema=_schema(), temperature=0.2, fast=True, max_tokens=1500)
        except gemini.GeminiError as e:
            print(f"[estimates] unavailable: {e.message}")
            continue
        got = {}
        for r in (raw.get("prices") if isinstance(raw, dict) else None) or []:
            if not isinstance(r, dict):
                continue
            try:
                v = float(r.get("price_myr"))
            except (TypeError, ValueError):
                continue
            got[re.sub(r"\s+", " ", str(r.get("name") or "")).strip().lower()] = v
        for n in batch:
            v = got.get(re.sub(r"\s+", " ", n).strip().lower())
            if v is None or v < 0 or (kind == "hotel" and v <= 0):
                continue
            v = float(round(min(max(v, lo), hi)))
            _cache[_key(kind, city, n)] = (now, v)
            out[n] = v
    return out


def fmt(kind: str, price: float | None) -> str:
    if price is None:
        return ""
    if kind == "attraction":
        return "Free" if price <= 0 else f"About RM{round(price)}"
    return f"About RM{round(price)}/nt"
