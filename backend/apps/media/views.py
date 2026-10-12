import datetime
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import views, permissions, status, response

from apps.progress.views import record_activity
from .models import DailyAudioDigest, UserDailyDigestProgress
from .services import get_or_create_daily_digest
from .serializers import (
    DailyAudioDigestSerializer,
    DailyDigestProgressUpdateSerializer,
    UserDailyDigestProgressSerializer,
)


class DailyAudioDigestView(views.APIView):
    """
    GET /api/v1/media/daily-digest/
    Returns the curated 3-insight Daily Audio Digest for today (or optional ?date=YYYY-MM-DD).
    If authenticated and user has personalized preferences, returns personalized digest.
    Includes user playback progress if authenticated.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        target_date = timezone.localdate()
        date_str = request.query_params.get('date')
        if date_str:
            try:
                target_date = datetime.date.fromisoformat(date_str)
            except ValueError:
                return response.Response(
                    {"error": "Invalid date format. Use YYYY-MM-DD."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        user = request.user if request.user.is_authenticated else None
        digest = get_or_create_daily_digest(user=user, target_date=target_date)

        if not digest:
            return response.Response(
                {"detail": "No audio digest available for this date."},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = DailyAudioDigestSerializer(digest, context={'request': request})
        return response.Response(serializer.data, status=status.HTTP_200_OK)


class DailyAudioDigestProgressView(views.APIView):
    """
    POST /api/v1/media/daily-digest/progress/
    Updates user listening progress for a daily digest track.
    If is_completed is True, records reading/listening habit activity toward user streak.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = DailyDigestProgressUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        digest_id = serializer.validated_data['digest_id']
        current_item_index = serializer.validated_data['current_item_index']
        current_position_seconds = serializer.validated_data['current_position_seconds']
        is_completed = serializer.validated_data['is_completed']

        digest = get_object_or_404(DailyAudioDigest, id=digest_id)

        progress, created = UserDailyDigestProgress.objects.get_or_create(
            user=request.user,
            digest=digest,
            defaults={
                'current_item_index': current_item_index,
                'current_position_seconds': current_position_seconds,
                'is_completed': is_completed,
            }
        )

        was_completed = progress.is_completed
        progress.current_item_index = current_item_index
        progress.current_position_seconds = current_position_seconds

        if is_completed and not was_completed:
            progress.is_completed = True
            progress.completed_at = timezone.now()
            # Record activity toward streaks and habit metrics
            audio_mins = max(1, digest.total_duration_seconds // 60)
            record_activity(
                request.user,
                audio_minutes=audio_mins,
                sections_read=digest.items.count(),
            )
        elif is_completed:
            progress.is_completed = True

        progress.save()

        return response.Response({
            'status': 'ok',
            'progress': UserDailyDigestProgressSerializer(progress).data,
            'current_streak': request.user.get_current_streak(),
        }, status=status.HTTP_200_OK)
