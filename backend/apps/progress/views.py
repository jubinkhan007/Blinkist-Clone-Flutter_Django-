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
from .badges import evaluate_and_award_badges


def record_activity(user, reading_minutes=0, audio_minutes=0, sections_read=0, books_completed=0):
    """Utility to register user activity for streak, daily habit tracking, and reading metrics."""
    if user and user.is_authenticated:
        user.record_reading_activity()
        today = timezone.localdate()
        daily, _ = UserDailyActivity.objects.get_or_create(user=user, date=today)
        if reading_minutes > 0 or audio_minutes > 0 or sections_read > 0 or books_completed > 0:
            daily.reading_minutes += reading_minutes
            daily.audio_minutes += audio_minutes
            daily.sections_read += sections_read
            daily.books_completed += books_completed
            daily.save(update_fields=['reading_minutes', 'audio_minutes', 'sections_read', 'books_completed'])


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
        is_finished = total_sections > 0 and completed_sections_count >= total_sections
        record_activity(
            request.user,
            reading_minutes=3,
            sections_read=1,
            books_completed=1 if is_finished else 0,
        )

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
        position_seconds = float(request.data.get('position_seconds', 0.0) or 0.0)
        is_finished = request.data.get('is_finished', False)

        section = None
        if section_id:
            section = get_object_or_404(SummarySection, id=section_id, book=book)

        progress, _ = UserAudioProgress.objects.get_or_create(user=request.user, book=book)
        delta_secs = max(0.0, position_seconds - progress.current_position_seconds)
        audio_mins = int(round(delta_secs / 60.0)) if delta_secs >= 30 else 0

        progress.current_section = section
        progress.current_position_seconds = position_seconds
        progress.is_finished = is_finished
        progress.save()

        # Record activity for streak tracking and audio minutes
        record_activity(
            request.user,
            audio_minutes=audio_mins,
            books_completed=1 if is_finished else 0,
        )

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
    """Returns aggregated gamification metrics, period breakdowns, habit heatmap, and badge awards."""
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

        # Reading minutes (from daily activity or fallback estimated at 3 mins / section)
        daily_read_mins = UserDailyActivity.objects.filter(user=user).aggregate(
            total=models.Sum('reading_minutes')
        )['total'] or 0
        total_reading_minutes = max(daily_read_mins, total_sections_read * 3)

        # Highlights count
        from apps.summaries.models import UserHighlight
        total_highlights = UserHighlight.objects.filter(user=user).count()

        # Weekly habit activity & period stats (Monday to Sunday)
        monday = today - timedelta(days=today.weekday())
        week_end = monday + timedelta(days=6)
        week_dates = [monday + timedelta(days=i) for i in range(7)]

        week_activities = UserDailyActivity.objects.filter(
            user=user,
            date__gte=monday,
            date__lte=week_end,
        )
        active_dates = set(week_activities.values_list('date', flat=True))
        if user.last_active_date and monday <= user.last_active_date <= week_end:
            active_dates.add(user.last_active_date)

        weekly_activity = [d in active_dates for d in week_dates]

        week_agg = week_activities.aggregate(
            read_m=models.Sum('reading_minutes'),
            aud_m=models.Sum('audio_minutes'),
            books_c=models.Sum('books_completed'),
        )
        weekly_read = week_agg['read_m'] or 0
        weekly_audio = week_agg['aud_m'] or 0
        weekly_stats = {
            'reading_minutes': weekly_read,
            'audio_minutes': weekly_audio,
            'total_minutes': weekly_read + weekly_audio,
            'days_active': len(active_dates),
            'books_completed': week_agg['books_c'] or 0,
        }

        # Monthly period stats (First day of current month to today)
        month_start = today.replace(day=1)
        month_activities = UserDailyActivity.objects.filter(
            user=user,
            date__gte=month_start,
            date__lte=today,
        )
        month_active_dates = set(month_activities.values_list('date', flat=True))
        if user.last_active_date and month_start <= user.last_active_date <= today:
            month_active_dates.add(user.last_active_date)

        month_agg = month_activities.aggregate(
            read_m=models.Sum('reading_minutes'),
            aud_m=models.Sum('audio_minutes'),
            books_c=models.Sum('books_completed'),
        )
        monthly_read = month_agg['read_m'] or 0
        monthly_audio = month_agg['aud_m'] or 0
        monthly_stats = {
            'reading_minutes': monthly_read,
            'audio_minutes': monthly_audio,
            'total_minutes': monthly_read + monthly_audio,
            'days_active': len(month_active_dates),
            'books_completed': month_agg['books_c'] or 0,
        }

        # 84-Day Activity Heatmap (12 full weeks ending today)
        heatmap_start = today - timedelta(days=83)
        history_map = {
            act.date: act for act in UserDailyActivity.objects.filter(
                user=user,
                date__gte=heatmap_start,
                date__lte=today,
            )
        }

        activity_heatmap = []
        for offset in range(84):
            day_date = heatmap_start + timedelta(days=offset)
            act = history_map.get(day_date)
            r_m = act.reading_minutes if act else 0
            a_m = act.audio_minutes if act else 0
            tot_m = r_m + a_m
            b_c = act.books_completed if act else 0
            is_act = tot_m > 0 or (act is not None) or (user.last_active_date == day_date)

            intensity = 0
            if is_act:
                if tot_m <= 10:
                    intensity = 1
                elif tot_m <= 25:
                    intensity = 2
                else:
                    intensity = 3

            activity_heatmap.append({
                'date': day_date.isoformat(),
                'day_of_week': day_date.weekday(),  # 0 = Mon, 6 = Sun
                'reading_minutes': r_m,
                'audio_minutes': a_m,
                'total_minutes': tot_m,
                'books_completed': b_c,
                'intensity': intensity,
                'is_active': is_act,
            })

        # Evaluate and unlock achievement badges
        badges = evaluate_and_award_badges(user)
        unlocked_badges = [b for b in badges if b['is_unlocked']]

        return response.Response({
            'current_streak': user.get_current_streak(today=today),
            'longest_streak': user.longest_streak,
            'last_active_date': user.last_active_date,
            'is_active_today': user.last_active_date == today,
            'total_sections_read': total_sections_read,
            'total_books_completed': total_books_completed,
            'total_audio_minutes': total_audio_minutes,
            'total_reading_minutes': total_reading_minutes,
            'total_highlights': total_highlights,
            'weekly_activity': weekly_activity,
            'weekly': weekly_stats,
            'monthly': monthly_stats,
            'activity_heatmap': activity_heatmap,
            'unlocked_badges_count': len(unlocked_badges),
            'total_badges_count': len(badges),
            'recent_badges': unlocked_badges[:4],
        })


class UserBadgesView(views.APIView):
    """Returns full catalog of achievement badges with user's unlock statuses and progress."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        badges = evaluate_and_award_badges(request.user)
        unlocked_count = sum(1 for b in badges if b['is_unlocked'])
        return response.Response({
            'total_badges': len(badges),
            'unlocked_count': unlocked_count,
            'badges': badges,
        })

