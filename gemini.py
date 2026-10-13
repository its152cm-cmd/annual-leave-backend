"""Small client for the Gemini API (Google AI Studio key).

The key lives only in the backend .env (GEMINI_API_KEY). The model can be fixed
with GEMINI_MODEL; when it is not set, the newest "flash" model that supports
generateContent is looked up once and reused.
"""
import base64
import json
import os
import re
import time

import httpx
from dotenv import load_dotenv

load_dotenv()

BASE = "https://generativelanguage.googleapis.com/v1beta"
FALLBACK_MODEL = "gemini-2.5-flash"

_model_cache: str | None = None


class GeminiError(Exception):
    """status is the HTTP status the API should answer with."""

    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status
        self.message = message
        self.raw_text = ""  # set when the model answered but the text was not valid JSON


def _headers() -> dict:
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        raise GeminiError(500, "GEMINI_API_KEY is not set in the backend .env file")
    return {"x-goog-api-key": key, "Content-Type": "application/json"}


def _version(name: str) -> tuple:
    m = re.search(r"gemini-(\d+(?:\.\d+)?)-flash", name)
    return (float(m.group(1)),) if m else (0.0,)


_model_list: list[str] | None = None


def pick_model(refresh: bool = False) -> str:
    """GEMINI_MODEL if set, otherwise the newest stable-looking flash model."""
    return candidate_models(refresh)[0]


def candidate_models(refresh: bool = False) -> list[str]:
    """Models to try in order. A model that is overloaded hands over to the next."""
    global _model_cache, _model_list
    fixed = os.getenv("GEMINI_MODEL")
    if fixed:
        return [fixed]
    if _model_list and not refresh:
        return _model_list
    try:
        resp = httpx.get(f"{BASE}/models", params={"pageSize": 200}, headers=_headers(), timeout=15.0)
        resp.raise_for_status()
        names, lite = [], []
        for m in resp.json().get("models", []):
            name = m.get("name", "").removeprefix("models/")
            if "generateContent" not in m.get("supportedGenerationMethods", []):
                continue
            if "flash" not in name:
                continue
            if any(bad in name for bad in ("image", "tts", "live", "audio", "exp", "robotics", "computer", "thinking")):
                continue
            (lite if "lite" in name else names).append(name)
        # newest version first; stable (not "preview") ahead of preview
        newest_first = lambda n: (_version(n), "preview" not in n)
        names.sort(key=newest_first, reverse=True)
        lite.sort(key=newest_first, reverse=True)
        # three full models, then one lighter "lite" model as a last resort
        chosen = names[:3] + lite[:1] or [FALLBACK_MODEL]
    except GeminiError:
        raise
    except Exception as e:
        print(f"[gemini] could not list models ({e}); using {FALLBACK_MODEL}")
        chosen = [FALLBACK_MODEL]
    _model_list, _model_cache = chosen, chosen[0]
    print(f"[gemini] models to try: {', '.join(chosen)}")
    return chosen


def _extract_text(data: dict) -> str:
    candidates = data.get("candidates") or []
    if not candidates:
        reason = (data.get("promptFeedback") or {}).get("blockReason")
        raise GeminiError(502, f"Gemini returned no answer{f' (blocked: {reason})' if reason else ''}")
    parts = (candidates[0].get("content") or {}).get("parts") or []
    text = "".join(p.get("text", "") for p in parts if not p.get("thought"))
    if not text.strip():
        raise GeminiError(502, "Gemini returned an empty answer")
    return text


def parse_json_text(text: str):
    """JSON from the model, tolerating ```json fences and text around it."""
    text = text.strip()
    fenced = re.match(r"^```(?:json)?\s*(.*?)\s*```$", text, re.S)
    if fenced:
        text = fenced.group(1)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        start, end = text.find("{"), text.rfind("}")
        if start != -1 and end > start:
            try:
                return json.loads(text[start : end + 1])
            except json.JSONDecodeError:
                pass
    print(f"[gemini] unreadable answer starts with: {text[:160]!r} ... ends with: {text[-80:]!r}")
    error = GeminiError(502, "Gemini answered, but not in a readable format. Please try again.")
    error.raw_text = text
    raise error


def _try_model(model: str, prompt: str, schema: dict | None, temperature: float, timeout: float, image: tuple | None = None, max_tokens: int | None = None):
    """One model, with simpler and simpler requests if it rejects an option (400)."""
    attempts = []
    if schema:
        attempts += [(True, True), (True, False)]
    attempts += [(False, False)]  # (use_schema, thinking_off)
    last_error: GeminiError | None = None

    for use_schema, thinking_off in attempts:
        config: dict = {"responseMimeType": "application/json", "temperature": temperature}
        if max_tokens:
            config["maxOutputTokens"] = max_tokens
        if use_schema and schema:
            config["responseSchema"] = schema
        if thinking_off:
            # a short itinerary does not need long "thinking"; it only makes the answer slow
            config["thinkingConfig"] = {"thinkingBudget": 0}
        parts: list = []
        if image:  # (bytes, mime type): a photo for the model to read
            parts.append({"inlineData": {"mimeType": image[1], "data": base64.b64encode(image[0]).decode()}})
        parts.append({"text": prompt})
        body = {"contents": [{"role": "user", "parts": parts}], "generationConfig": config}

        for retry in range(2):
            started = time.time()
            try:
                resp = httpx.post(f"{BASE}/models/{model}:generateContent", json=body, headers=_headers(), timeout=timeout)
            except httpx.TimeoutException:
                raise GeminiError(504, "Gemini took too long to answer. Please try again.")
            except httpx.HTTPError as e:
                raise GeminiError(502, f"Cannot reach Gemini: {e}")
            print(f"[gemini] {model} answered {resp.status_code} in {time.time() - started:.1f}s")
            if resp.status_code in (429, 503) and retry == 0:
                time.sleep(4)
                continue
            break

        if resp.status_code == 200:
            data = resp.json()
            usage = data.get("usageMetadata") or {}
            print(f"[gemini] tokens: prompt={usage.get('promptTokenCount')} "
                  f"answer={usage.get('candidatesTokenCount')} thinking={usage.get('thoughtsTokenCount')}")
            return parse_json_text(_extract_text(data))

        message = ""
        try:
            message = resp.json().get("error", {}).get("message", "")
        except Exception:
            message = resp.text[:200]
        if resp.status_code == 429:
            raise GeminiError(429, "The AI is busy right now (free-tier limit). Wait a minute and try again.")
        if resp.status_code == 503:
            raise GeminiError(503, "The AI model is overloaded right now. Please try again in a moment.")
        if resp.status_code in (401, 403):
            raise GeminiError(500, f"Gemini rejected the API key: {message}")
        if resp.status_code == 404:
            raise GeminiError(404, f"Gemini model {model} is not available: {message}")
        last_error = GeminiError(502, f"Gemini error {resp.status_code}: {message}")
        if resp.status_code != 400:
            break  # only a 400 (unsupported option) is worth retrying with simpler options

    raise last_error or GeminiError(502, "Gemini request failed")


def generate_json(prompt: str, schema: dict | None = None, temperature: float = 0.7, timeout: float = 170.0, fast: bool = False, image: tuple | None = None, max_tokens: int | None = None):
    """Asks Gemini for a JSON answer and returns it already parsed.

    The lightest model is always tried first, then the heavier ones as backup.

    If one model is overloaded (503), over its limit (429) or gone (404), the
    next model on the list is tried before giving up.
    """
    global _model_list, _model_cache
    last_error: GeminiError | None = None
    models = candidate_models()
    # Always the lightest model first (quicker, and the heavier ones are often overloaded); the others are the backup.
    models = sorted(models, key=lambda m: "lite" not in m)
    for model in models:
        try:
            return _try_model(model, prompt, schema, temperature, timeout, image, max_tokens)
        except GeminiError as e:
            unreadable = e.status == 502 and bool(e.raw_text)  # answered, but not valid JSON: another model may do better
            if e.status not in (429, 503, 404) and not unreadable:
                raise
            if e.status == 404:
                _model_list = _model_cache = None  # look the list up again next time
            print(f"[gemini] {model} unavailable ({e.status}); trying the next model")
            last_error = e
    raise last_error or GeminiError(502, "Gemini request failed")
