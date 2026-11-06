from __future__ import annotations

from django.shortcuts import get_object_or_404
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.models import Book
from apps.catalog.serializers import _can_access_summary, _user_has_premium_access
from apps.summaries.models import SummarySection
from apps.summaries.voice_service import (
    DEFAULT_VOICE_ID,
    VOICE_MAP,
    get_voice_by_id,
    get_voice_catalog,
    resolve_section_voice_audio,
)


class VoiceCatalogView(APIView):
    """
    Returns the curated list of multi-voice AI narrator personas.
    """
    permission_classes = (permissions.AllowAny,)

    def get(self, request, *args, **kwargs):
        catalog = get_voice_catalog()
        has_premium = _user_has_premium_access(request)
        preferred_voice = DEFAULT_VOICE_ID

        if request.user and request.user.is_authenticated:
            preferred_voice = request.session.get('preferred_voice', DEFAULT_VOICE_ID)

        # Annotate user unlocked status
        for v in catalog:
            v['is_unlocked'] = (not v['is_premium']) or has_premium

        return Response({
            "voices": catalog,
            "default_voice": DEFAULT_VOICE_ID,
            "preferred_voice": preferred_voice,
            "has_premium_voices": has_premium,
        })


class SectionVoiceAudioView(APIView):
    """
    Provides or generates voice-specific narration audio for a book summary section.
    Usage: GET /api/v1/summaries/<book_slug>/<slug>/audio/?voice=jenny
    """
    permission_classes = (permissions.AllowAny,)

    def get(self, request, book_slug, slug, *args, **kwargs):
        book = get_object_or_404(Book, slug=book_slug)
        section = get_object_or_404(SummarySection, book=book, slug=slug)

        # Check basic book/section access (free vs premium summary)
        if not _can_access_summary(book, request):
            return Response(
                {
                    "error": "premium_summary_required",
                    "message": "This summary requires an active Blinkist Plus membership.",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        requested_voice_id = request.query_params.get(
            'voice',
            request.headers.get('X-Narration-Voice', DEFAULT_VOICE_ID),
        )
        voice_meta = get_voice_by_id(requested_voice_id)

        # Check premium voice gating
        if voice_meta.get('is_premium', False) and not _user_has_premium_access(request):
            return Response(
                {
                    "error": "premium_voice_required",
                    "message": f"{voice_meta['name']} is a Premium AI narrator persona. Upgrade to Blinkist Plus to unlock.",
                    "voice": voice_meta['id'],
                    "voice_name": voice_meta['name'],
                    "upgrade_required": True,
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        payload = resolve_section_voice_audio(
            section=section,
            voice_id=voice_meta['id'],
            request=request,
        )
        return Response(payload)


class UserVoicePreferenceView(APIView):
    """
    Gets or saves the user's preferred narration voice.
    """
    permission_classes = (permissions.AllowAny,)

    def get(self, request, *args, **kwargs):
        voice_id = DEFAULT_VOICE_ID
        if request.user and request.user.is_authenticated:
            voice_id = request.session.get('preferred_voice', DEFAULT_VOICE_ID)
        voice_meta = get_voice_by_id(voice_id)
        return Response({
            "preferred_voice": voice_meta['id'],
            "voice_name": voice_meta['name'],
            "voice_persona": voice_meta['persona'],
        })

    def post(self, request, *args, **kwargs):
        voice_id = request.data.get('voice') or request.data.get('preferred_voice')
        if not voice_id or voice_id not in VOICE_MAP:
            return Response(
                {
                    "error": "invalid_voice",
                    "message": f"Invalid voice ID. Available: {', '.join(VOICE_MAP.keys())}",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        voice_meta = VOICE_MAP[voice_id]
        if voice_meta.get('is_premium', False) and not _user_has_premium_access(request):
            return Response(
                {
                    "error": "premium_voice_required",
                    "message": f"Upgrade to Blinkist Plus to select {voice_meta['name']} as your default voice.",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        if request.user and request.user.is_authenticated:
            request.session['preferred_voice'] = voice_id
            request.session.modified = True

        return Response({
            "status": "success",
            "preferred_voice": voice_id,
            "voice_name": voice_meta['name'],
            "message": f"Narration voice updated to {voice_meta['name']} ({voice_meta['persona']}).",
        })
