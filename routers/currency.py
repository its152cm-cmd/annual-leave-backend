"""Exchange rates for showing prices in the person's own currency.

Every amount is stored in Malaysian Ringgit (MYR). The app multiplies by the rate for the currency
the person picked in Account > Currency. Rates come from a free public source (no key), are kept for
12 hours, and a built-in table is used when the source cannot be reached.
"""
import time

import httpx
from fastapi import APIRouter, Depends

from auth import get_current_user_id

router = APIRouter(prefix="/api/currency", tags=["currency"])

SOURCE = "https://open.er-api.com/v6/latest/MYR"
KEEP_SECONDS = 12 * 3600

# Approximate: 1 MYR in each currency. Only used when the live source is unavailable.
FALLBACK = {
    "MYR": 1.0, "USD": 0.21, "EUR": 0.19, "GBP": 0.16, "JPY": 32.0, "SGD": 0.29, "AUD": 0.33, "CNY": 1.52,
    "THB": 7.2, "IDR": 3500.0, "KRW": 295.0, "INR": 17.5, "HKD": 1.65, "TWD": 6.8, "NZD": 0.36,
    "CAD": 0.29, "CHF": 0.18, "PHP": 12.0, "VND": 5300.0, "AED": 0.77,
}

_cache: dict = {"at": 0.0, "rates": None, "live": False}


def _fetch() -> dict[str, float] | None:
    try:
        r = httpx.get(SOURCE, timeout=6.0)
        r.raise_for_status()
        data = r.json()
        rates = data.get("rates") or {}
        out = {c: float(rates[c]) for c in FALLBACK if isinstance(rates.get(c), (int, float)) and rates[c] > 0}
        out["MYR"] = 1.0
        return out if len(out) > 5 else None
    except Exception as e:
        print(f"[currency] could not fetch live rates: {e}")
        return None


def current_rates() -> tuple[dict[str, float], bool]:
    if _cache["rates"] and time.time() - _cache["at"] < KEEP_SECONDS:
        return _cache["rates"], _cache["live"]
    live = _fetch()
    if live:
        # a currency the source skipped keeps its built-in value
        rates = {**FALLBACK, **live}
        _cache.update(at=time.time(), rates=rates, live=True)
        return rates, True
    if _cache["rates"]:  # keep the last good ones a bit longer
        _cache["at"] = time.time() - KEEP_SECONDS + 600
        return _cache["rates"], _cache["live"]
    _cache.update(at=time.time() - KEEP_SECONDS + 600, rates=dict(FALLBACK), live=False)
    return _cache["rates"], False


@router.get("/rates")
def rates(me: str = Depends(get_current_user_id)):
    """How much 1 MYR is worth in each supported currency."""
    r, live = current_rates()
    return {"base": "MYR", "rates": r, "live": live}
