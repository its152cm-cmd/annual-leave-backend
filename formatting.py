"""Turns real dates and numbers into the display strings the Flutter models expect,
and parses the Flutter date text back into real dates."""
import re
import uuid
from datetime import date

CURRENCY_SYMBOLS = {"MYR": "RM", "SGD": "S$", "USD": "$", "JPY": "¥", "EUR": "€", "GBP": "£"}

MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]


# ---------- ids ----------------------------------------------------------
def group_id_for(trip_id: str) -> str:
    """The frontend names a trip's group chat 'trip_<tripId>'."""
    return f"trip_{trip_id}"


def trip_id_from_group(group_id: str) -> str:
    return group_id[len("trip_"):] if group_id.startswith("trip_") else group_id


def is_uuid(value) -> bool:
    try:
        uuid.UUID(str(value))
        return True
    except (ValueError, AttributeError, TypeError):
        return False


# ---------- dates --------------------------------------------------------
def parse_date(value) -> date | None:
    if not value:
        return None
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value)[:10])


_RANGE = re.compile(
    r"(\d{1,2})\s*([A-Za-z]{3,9})?\s*(\d{4})?\s*[-–—]\s*(\d{1,2})\s*([A-Za-z]{3,9})?\s*(\d{4})?"
)


def _month(name: str | None) -> int | None:
    if not name:
        return None
    key = name.strip().lower()[:3]
    return MONTHS.index(key) + 1 if key in MONTHS else None


def parse_date_range(text: str | None) -> tuple[date | None, date | None]:
    """Reads the text the Flutter app sends, e.g.
         '12 - 18 October 2026'            '12 October - 18 December 2026'
         '15 Apr - 22 Apr 2026'            '12-18 Oct 2026'
       Returns (None, None) when it cannot be understood."""
    m = _RANGE.search(text or "")
    if not m:
        return None, None
    d1, m1, y1, d2, m2, y2 = m.groups()
    end_month = _month(m2)
    if end_month is None:
        return None, None
    start_month = _month(m1) or end_month
    end_year = int(y2) if y2 else (int(y1) if y1 else None)
    if end_year is None:
        return None, None
    start_year = int(y1) if y1 else end_year
    try:
        end = date(end_year, end_month, int(d2))
        start = date(start_year, start_month, int(d1))
        if start > end and not y1:  # e.g. '28 December - 3 January 2027'
            start = date(end_year - 1, start_month, int(d1))
    except ValueError:
        return None, None
    return (start, end) if start <= end else (None, None)


def duration_text(start: date | None, end: date | None) -> str:
    """12 Oct -> 18 Oct = '6 days' (matches the mock data)."""
    if not start or not end:
        return ""
    days = max((end - start).days, 1)
    return f"{days} day" if days == 1 else f"{days} days"


def long_range(start: date | None, end: date | None) -> str:
    """'12 - 18 October 2026' (used by Trip)."""
    if not start or not end:
        return ""
    if start.year == end.year and start.month == end.month:
        return f"{start.day} - {end.day} {end.strftime('%B %Y')}"
    if start.year == end.year:
        return f"{start.day} {start.strftime('%B')} - {end.day} {end.strftime('%B %Y')}"
    return f"{start.day} {start.strftime('%B %Y')} - {end.day} {end.strftime('%B %Y')}"


def invitation_range(start: date | None, end: date | None) -> str:
    """'15 Apr - 22 Apr 2026' (used by TripInvitation)."""
    if not start or not end:
        return ""
    if start.year == end.year:
        return f"{start.day} {start.strftime('%b')} - {end.day} {end.strftime('%b %Y')}"
    return f"{start.day} {start.strftime('%b %Y')} - {end.day} {end.strftime('%b %Y')}"


# ---------- money --------------------------------------------------------
def budget_text(budget_max, currency: str | None) -> str:
    """'RM 1,500 budget' (used by Trip)."""
    if budget_max is None:
        return ""
    symbol = CURRENCY_SYMBOLS.get(currency or "MYR", currency or "")
    return f"{symbol} {float(budget_max):,.0f} budget"


def budget_amounts(label: str | None) -> list[float]:
    """Numbers inside a label such as 'RM 1,000 - RM 2,000 budget'."""
    return [float(x.replace(",", "")) for x in re.findall(r"\d[\d,]*(?:\.\d+)?", label or "")]
