from rest_framework import views, response, status, permissions
from django.shortcuts import get_object_or_404
from django.db import models
from django.utils import timezone
from datetime import timedelta

from apps.catalog.models import Book
from apps.summaries.models import SummarySection
from .models import (
    UserBookProgress,
    UserSectionProgress,
    UserAudioProgress,
    UserSummaryProgress,
    UserFullBookProgress,
    UserDailyActivity,
)
from .serializers import (
    UserBookProgressSerializer,
    UserAudioProgressSerializer,
    UserSummaryProgressSerializer,
    UserFullBookProgressSerializer,
)


def record_activity(user):
    """Utility to register user activity for streak and daily habit tracking."""
    if user and user.is_authenticated:
        user.record_reading_activity()
        today = timezone.localdate()
        UserDailyActivity.objects.get_or_create(user=user, date=today)


class ReadProgressView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        # GET /api/v1/progress/books/<book_id>/
        book = get_object_or_404(Book, id=book_id)
        progress, _ = UserSummaryProgress.objects.get_or_create(user=request.user, book=book)
        serializer = UserSummaryProgressSerializer(progress)
        return response.Response(serializer.data)


class MarkSectionReadView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, book_id, section_id):
        # POST /api/v1/progress/books/<book_id>/section/<section_id>/
        book = get_object_or_404(Book, id=book_id)
        section = get_object_or_404(SummarySection, id=section_id, book=book)

        # Mark section complete
        UserSectionProgress.objects.update_or_create(
            user=request.user, 
            section=section,
            defaults={'is_completed': True}
        )

        # Update book progress
        summary_progress, _ = UserSummaryProgress.objects.get_or_create(user=request.user, book=book)
        summary_progress.current_section = section
        
        # Recalculate percentage
        total_sections = book.sections.count()
        completed_sections_count = UserSectionProgress.objects.filter(
            user=request.user, 
            section__book=book, 
            is_completed=True
        ).count()
        
        summary_progress.completed_sections_count = completed_sections_count
        summary_progress.save()

        # Record activity for streak tracking
        record_activity(request.user)

        return response.Response(UserSummaryProgressSerializer(summary_progress).data)


class AudioProgressView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        # GET /api/v1/progress/books/<book_id>/audio/
        book = get_object_or_404(Book, id=book_id)
        progress, _ = UserAudioProgress.objects.get_or_create(user=request.user, book=book)
        return response.Response(UserAudioProgressSerializer(progress).data)

    def post(self, request, book_id):
        # POST /api/v1/progress/books/<book_id>/audio/
        # Body: { section_id, position_seconds, is_finished }
        book = get_object_or_404(Book, id=book_id)
        section_id = request.data.get('section_id')
        position_seconds = request.data.get('position_seconds', 0.0)
        is_finished = request.data.get('is_finished', False)

        section = None
        if section_id:
            section = get_object_or_404(SummarySection, id=section_id, book=book)

        progress, _ = UserAudioProgress.objects.get_or_create(user=request.user, book=book)
        progress.current_section = section
        progress.current_position_seconds = position_seconds
        progress.is_finished = is_finished
        progress.save()

        # Record activity for streak tracking
        record_activity(request.user)

        return response.Response(UserAudioProgressSerializer(progress).data)


class FullBookProgressView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        book = get_object_or_404(Book, id=book_id)
        progress, _ = UserFullBookProgress.objects.get_or_create(
            user=request.user,
            book=book,
        )
        return response.Response(UserFullBookProgressSerializer(progress).data)

    def post(self, request, book_id):
        book = get_object_or_404(Book, id=book_id)
        progress, _ = UserFullBookProgress.objects.get_or_create(
            user=request.user,
            book=book,
        )
        progress.current_page = int(request.data.get('current_page', 0) or 0)
        progress.current_offset = float(request.data.get('current_offset', 0.0) or 0.0)
        progress.save()

        # Record activity for streak tracking
        record_activity(request.user)

        return response.Response(UserFullBookProgressSerializer(progress).data)


class RecordActivityView(views.APIView):
    """Explicit endpoint for client check-ins or reading heartbeats."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        record_activity(request.user)
        today = timezone.localdate()
        return response.Response({
            'status': 'success',
            'current_streak': request.user.get_current_streak(today=today),
            'longest_streak': request.user.longest_streak,
            'last_active_date': request.user.last_active_date,
            'is_active_today': True,
        })


class UserReadingStatsView(views.APIView):
    """Returns aggregated gamification metrics, active streak, and weekly habit activity."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        today = timezone.localdate()

        # Sections read
        total_sections_read = UserSectionProgress.objects.filter(
            user=user, is_completed=True
        ).count()

        # Books completed
        completed_book_ids = set(
            UserBookProgress.objects.filter(user=user, is_completed=True).values_list('book_id', flat=True)
        )
        for sp in UserSummaryProgress.objects.filter(user=user).select_related('book'):
            total_secs = sp.book.sections.count()
            if total_secs > 0 and sp.completed_sections_count >= total_secs:
                completed_book_ids.add(sp.book_id)
        total_books_completed = len(completed_book_ids)

        # Audio minutes
        audio_secs = UserAudioProgress.objects.filter(user=user).aggregate(
            total=models.Sum('current_position_seconds')
        )['total'] or 0.0
        total_audio_minutes = int(round(audio_secs / 60.0))

        # Highlights count
        from apps.summaries.models import UserHighlight
        total_highlights = UserHighlight.objects.filter(user=user).count()

        # Weekly habit activity (Monday to Sunday of current week)
        monday = today - timedelta(days=today.weekday())
        week_dates = [monday + timedelta(days=i) for i in range(7)]
        active_dates = set(
            UserDailyActivity.objects.filter(
                user=user,
                date__gte=monday,
                date__lte=week_dates[-1]
            ).values_list('date', flat=True)
        )
        if user.last_active_date:
            active_dates.add(user.last_active_date)

        weekly_activity = [d in active_dates for d in week_dates]

        return response.Response({
            'current_streak': user.get_current_streak(today=today),
            'longest_streak': user.longest_streak,
            'last_active_date': user.last_active_date,
            'is_active_today': user.last_active_date == today,
            'total_sections_read': total_sections_read,
            'total_books_completed': total_books_completed,
            'total_audio_minutes': total_audio_minutes,
            'total_highlights': total_highlights,
            'weekly_activity': weekly_activity,
        })
