from __future__ import annotations

import logging
import os
from typing import Any, Dict, List, Optional
from django.conf import settings
from apps.summaries.models import SummarySection
from apps.summaries.tts_service import generate_audio

logger = logging.getLogger(__name__)

VOICE_CATALOG: List[Dict[str, Any]] = [
    {
        "id": "christopher",
        "name": "Christopher",
        "persona": "The Thoughtful Strategist",
        "gender": "male",
        "accent": "US English",
        "edge_voice": "en-US-ChristopherNeural",
        "description": "Warm, authoritative, deliberate cadence. Ideal for strategy, leadership, and deep focus.",
        "avatar": "👨‍💼",
        "is_default": True,
        "is_premium": False,
        "speed_recommendation": 1.0,
    },
    {
        "id": "jenny",
        "name": "Jenny",
        "persona": "The Calm Storyteller",
        "gender": "female",
        "accent": "US English",
        "edge_voice": "en-US-JennyNeural",
        "description": "Empathetic, clear, and engaging rhythm. Ideal for mindfulness, psychology, and personal growth.",
        "avatar": "👩‍💼",
        "is_default": False,
        "is_premium": False,
        "speed_recommendation": 1.0,
    },
    {
        "id": "guy",
        "name": "Guy",
        "persona": "The Energetic Executive",
        "gender": "male",
        "accent": "US English",
        "edge_voice": "en-US-GuyNeural",
        "description": "Crisp, dynamic, high-momentum delivery. Perfect for productivity, business, and economics.",
        "avatar": "⚡",
        "is_default": False,
        "is_premium": False,
        "speed_recommendation": 1.1,
    },
    {
        "id": "sonia",
        "name": "Sonia",
        "persona": "The Refined Scholar",
        "gender": "female",
        "accent": "British English",
        "edge_voice": "en-GB-SoniaNeural",
        "description": "Articulate, nuanced, British eloquence. Best for science, philosophy, and historical deep dives.",
        "avatar": "🎓",
        "is_default": False,
        "is_premium": True,
        "speed_recommendation": 1.0,
    },
    {
        "id": "brian",
        "name": "Brian",
        "persona": "The Modern Innovator",
        "gender": "male",
        "accent": "US English",
        "edge_voice": "en-US-BrianMultilingualNeural",
        "description": "Fresh, conversational, upbeat delivery. Great for technology, creativity, and modern biographies.",
        "avatar": "🚀",
        "is_default": False,
        "is_premium": True,
        "speed_recommendation": 1.05,
    },
]

VOICE_MAP: Dict[str, Dict[str, Any]] = {v["id"]: v for v in VOICE_CATALOG}
DEFAULT_VOICE_ID = "christopher"


def get_voice_catalog() -> List[Dict[str, Any]]:
    """Returns the list of all available voice personas."""
    return [dict(v) for v in VOICE_CATALOG]


def get_voice_by_id(voice_id: str | None) -> Dict[str, Any]:
    """Resolves voice definition by id or returns default."""
    if not voice_id:
        return VOICE_MAP[DEFAULT_VOICE_ID]
    return VOICE_MAP.get(voice_id.lower().strip(), VOICE_MAP[DEFAULT_VOICE_ID])


def get_section_voice_audio_path(section: SummarySection, voice_id: str) -> tuple[str, str]:
    """
    Returns (relative_media_path, absolute_disk_path) for a voice audio file.
    """
    relative_dir = os.path.join("books", "audio", "voices")
    filename = f"book_{section.book_id}_sec_{section.order}_{voice_id}.mp3"
    relative_path = os.path.join(relative_dir, filename)
    absolute_path = os.path.join(settings.MEDIA_ROOT, relative_path)
    return relative_path, absolute_path


def resolve_section_voice_audio(
    section: SummarySection,
    voice_id: str | None = None,
    request: Any = None,
) -> Dict[str, Any]:
    """
    Resolves or generates voice narration for a given SummarySection.
    Returns dictionary with audio_url, duration_seconds, voice metadata, and fallback flag.
    """
    voice_meta = get_voice_by_id(voice_id)
    v_id = voice_meta["id"]

    # 1. If default voice and section has primary audio_file, use it
    if v_id == DEFAULT_VOICE_ID and section.audio_file:
        url = section.audio_file.url
        if request:
            url = request.build_absolute_uri(url)
        return {
            "voice": v_id,
            "voice_name": voice_meta["name"],
            "voice_persona": voice_meta["persona"],
            "audio_url": url,
            "duration_seconds": section.duration_seconds or 120,
            "is_fallback": False,
        }

    # 2. Check if voice-specific audio file exists on disk
    rel_path, abs_path = get_section_voice_audio_path(section, v_id)
    if os.path.exists(abs_path) and os.path.getsize(abs_path) > 0:
        url = settings.MEDIA_URL + rel_path.replace("\\", "/")
        if request:
            url = request.build_absolute_uri(url)
        return {
            "voice": v_id,
            "voice_name": voice_meta["name"],
            "voice_persona": voice_meta["persona"],
            "audio_url": url,
            "duration_seconds": section.duration_seconds or 120,
            "is_fallback": False,
        }

    # 3. Attempt synthesis on demand
    text_to_speak = (section.plain_text or section.content or "").strip()
    if text_to_speak:
        try:
            os.makedirs(os.path.dirname(abs_path), exist_ok=True)
            edge_voice = voice_meta.get("edge_voice", "en-US-ChristopherNeural")
            generate_audio(text_to_speak, abs_path, voice=edge_voice)
            if os.path.exists(abs_path) and os.path.getsize(abs_path) > 0:
                url = settings.MEDIA_URL + rel_path.replace("\\", "/")
                if request:
                    url = request.build_absolute_uri(url)
                return {
                    "voice": v_id,
                    "voice_name": voice_meta["name"],
                    "voice_persona": voice_meta["persona"],
                    "audio_url": url,
                    "duration_seconds": section.duration_seconds or 120,
                    "is_fallback": False,
                }
        except Exception as e:
            logger.warning(
                f"TTS generation for section {section.id} voice {v_id} failed: {e}. Falling back to default audio."
            )

    # 4. Graceful fallback to default section.audio_file or sample
    fallback_url = None
    if section.audio_file:
        fallback_url = section.audio_file.url
        if request:
            fallback_url = request.build_absolute_uri(fallback_url)

    return {
        "voice": v_id,
        "voice_name": voice_meta["name"],
        "voice_persona": voice_meta["persona"],
        "audio_url": fallback_url,
        "duration_seconds": section.duration_seconds or 120,
        "is_fallback": True,
    }
