"""Turns a short voice recording into text for the travel-preferences box (Gemini listens to the audio)."""
import base64
import binascii

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

import gemini
from auth import get_current_user_id

router = APIRouter(prefix="/api/preferences", tags=["preferences"])

MAX_BYTES = 6 * 1024 * 1024
AUDIO_TYPES = {"audio/webm", "audio/ogg", "audio/wav", "audio/mp3", "audio/mpeg", "audio/mp4", "audio/aac", "audio/flac", "audio/x-m4a"}

PROMPT = (
    "Transcribe this short voice note. The speaker is describing what they want from a trip "
    "(places, food, pace, budget, who they travel with). Return only what they said, lightly cleaned up "
    "(no filler words, proper punctuation), in the language they spoke. Do not add anything they did not say. "
    "If there is no speech, return an empty text."
)
SCHEMA = {"type": "OBJECT", "properties": {"text": {"type": "STRING"}}, "required": ["text"]}


class TranscribeIn(BaseModel):
    audioBase64: str
    mimeType: str = "audio/webm"


@router.post("/transcribe")
def transcribe(body: TranscribeIn, me: str = Depends(get_current_user_id)):
    mime = body.mimeType.split(";")[0].strip().lower()
    if mime not in AUDIO_TYPES:
        raise HTTPException(status_code=422, detail="This audio format is not supported. Please type instead.")
    try:
        data = base64.b64decode(body.audioBase64, validate=False)
    except (binascii.Error, ValueError):
        raise HTTPException(status_code=422, detail="The recording could not be read")
    if not data:
        raise HTTPException(status_code=422, detail="The recording is empty")
    if len(data) > MAX_BYTES:
        raise HTTPException(status_code=413, detail="The recording is too long. Please keep it under a few minutes.")
    try:
        raw = gemini.generate_json(PROMPT, schema=SCHEMA, temperature=0.0, fast=True, image=(data, mime))
    except gemini.GeminiError as e:
        raise HTTPException(status_code=e.status, detail=e.message)
    text = ""
    if isinstance(raw, dict):
        text = str(raw.get("text") or "").strip()
    if not text:
        raise HTTPException(status_code=422, detail="We could not hear anything. Please try again closer to the microphone.")
    return {"text": text[:1500]}
