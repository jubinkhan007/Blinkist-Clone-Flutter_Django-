from __future__ import annotations

from datetime import timedelta
from django.core.cache import cache
from django.db import models, transaction
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, response, status, views

from apps.catalog.models import Book
from apps.summaries.models import SummarySection
from .models import (
    UserBookProgress,
    UserSectionProgress,
    UserAudioProgress,
    UserSummaryProgress,
    UserFullBookProgress,
    UserDailyActivity,
    ActionPlan,
    ActionPlanItem,
)
from .serializers import (
    UserBookProgressSerializer,
    UserAudioProgressSerializer,
    UserSummaryProgressSerializer,
    UserFullBookProgressSerializer,
    ActionPlanSerializer,
    ActionPlanItemSerializer,
)
from .action_plan_service import ActionPlanService, ActionPlanExportService
from .badges import evaluate_and_award_badges
from core.metrics import ACTIVE_SYNC_SESSIONS, SYNC_HANDOFFS_TOTAL


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


class BulkProgressSyncView(views.APIView):
    """
    POST /api/v1/progress/sync/
    Processes batched offline sync actions from mobile clients:
    - section_read (book_id or book_slug, section_id or section_slug)
    - audio_progress (book_id or book_slug, section_id, position_seconds, is_finished)
    - full_book_progress (book_id or book_slug, current_page, total_pages, current_offset, is_completed)
    - reading_activity (reading_minutes, audio_minutes, sections_read, books_completed)
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        items = request.data.get('items', [])
        if not isinstance(items, list):
            return response.Response(
                {'error': 'Payload must include an "items" list'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        processed_count = 0
        total_reading_mins = 0
        total_audio_mins = 0
        total_sections_read = 0
        total_books_completed = 0

        with transaction.atomic():
            for item in items:
                action_type = item.get('type')
                book_id = item.get('book_id')
                book_slug = item.get('book_slug')

                book = None
                if book_id:
                    book = Book.objects.filter(id=book_id).first()
                elif book_slug:
                    book = Book.objects.filter(slug=book_slug).first()

                if action_type == 'section_read' and book:
                    section_id = item.get('section_id')
                    section_slug = item.get('section_slug')
                    section = None
                    if section_id:
                        section = SummarySection.objects.filter(id=section_id, book=book).first()
                    elif section_slug:
                        section = SummarySection.objects.filter(slug=section_slug, book=book).first()

                    if section:
                        UserSectionProgress.objects.update_or_create(
                            user=request.user,
                            section=section,
                            defaults={'is_completed': True},
                        )
                        summary_prog, _ = UserSummaryProgress.objects.get_or_create(
                            user=request.user, book=book
                        )
                        summary_prog.current_section = section
                        completed_cnt = UserSectionProgress.objects.filter(
                            user=request.user, section__book=book, is_completed=True
                        ).count()
                        summary_prog.completed_sections_count = completed_cnt
                        summary_prog.save()
                        total_sections_read += 1
                        total_reading_mins += 3
                        if book.sections.count() > 0 and completed_cnt >= book.sections.count():
                            total_books_completed += 1
                        processed_count += 1

                elif action_type == 'audio_progress' and book:
                    section_id = item.get('section_id')
                    position_seconds = float(item.get('position_seconds', 0.0) or 0.0)
                    is_finished = bool(item.get('is_finished', False))

                    section = None
                    if section_id:
                        section = SummarySection.objects.filter(id=section_id, book=book).first()

                    audio_prog, _ = UserAudioProgress.objects.get_or_create(
                        user=request.user, book=book
                    )
                    delta_secs = max(0.0, position_seconds - audio_prog.current_position_seconds)
                    if delta_secs >= 30:
                        total_audio_mins += int(round(delta_secs / 60.0))

                    audio_prog.current_section = section
                    audio_prog.current_position_seconds = position_seconds
                    audio_prog.is_finished = is_finished
                    audio_prog.save()
                    if is_finished:
                        total_books_completed += 1
                    processed_count += 1

                elif action_type == 'full_book_progress' and book:
                    full_prog, _ = UserFullBookProgress.objects.get_or_create(
                        user=request.user, book=book
                    )
                    full_prog.current_page = int(item.get('current_page', 0) or 0)
                    full_prog.current_offset = float(item.get('current_offset', 0.0) or 0.0)
                    full_prog.save()
                    processed_count += 1

                elif action_type == 'reading_activity':
                    total_reading_mins += int(item.get('reading_minutes', 0) or 0)
                    total_audio_mins += int(item.get('audio_minutes', 0) or 0)
                    total_sections_read += int(item.get('sections_read', 0) or 0)
                    total_books_completed += int(item.get('books_completed', 0) or 0)
                    processed_count += 1

            record_activity(
                request.user,
                reading_minutes=total_reading_mins,
                audio_minutes=total_audio_mins,
                sections_read=total_sections_read,
                books_completed=total_books_completed,
            )

        new_badges = evaluate_and_award_badges(request.user)
        today = timezone.localdate()

        return response.Response({
            'success': True,
            'processed_count': processed_count,
            'current_streak': request.user.get_current_streak(today=today),
            'longest_streak': request.user.longest_streak,
            'new_badges_awarded': len(new_badges),
            'server_timestamp': timezone.now().isoformat(),
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

        # Time saved calculation
        # Average non-fiction book: 360 mins (6h). Average Blinkist summary: 15 mins.
        # Time saved per completed book: ~345 mins (5.75h).
        # Time saved per extra section read: ~40 mins.
        time_saved_mins = (total_books_completed * 345) + max(0, (total_sections_read - total_books_completed * 8) * 40)
        if time_saved_mins == 0 and (total_reading_minutes + total_audio_minutes) > 0:
            time_saved_mins = (total_reading_minutes + total_audio_minutes) * 4
        time_saved_hours = round(time_saved_mins / 60.0, 1)

        monthly_books_c = monthly_stats.get('books_completed', 0)
        monthly_time_spent = monthly_stats.get('total_minutes', 0)
        monthly_saved_mins = (monthly_books_c * 345) + (monthly_time_spent * 3)
        monthly_time_saved_hours = round(monthly_saved_mins / 60.0, 1)
        equivalent_full_books = max(total_books_completed, int(round((total_reading_minutes + total_audio_minutes) / 15.0)))

        # Activity Heatmap (Configurable: default 84 days = 12 weeks; supports up to 365 days for annual view)
        days_param = request.query_params.get('heatmap_days')
        try:
            num_days = min(365, max(14, int(days_param))) if days_param else 84
        except (ValueError, TypeError):
            num_days = 84

        heatmap_start = today - timedelta(days=num_days - 1)
        history_map = {
            act.date: act for act in UserDailyActivity.objects.filter(
                user=user,
                date__gte=heatmap_start,
                date__lte=today,
            )
        }

        activity_heatmap = []
        for offset in range(num_days):
            day_date = heatmap_start + timedelta(days=offset)
            act = history_map.get(day_date)
            r_m = act.reading_minutes if act else 0
            a_m = act.audio_minutes if act else 0
            tot_m = r_m + a_m
            b_c = act.books_completed if act else 0
            is_act = tot_m > 0 or (act is not None) or (user.last_active_date == day_date)

            intensity = 0
            if is_act or tot_m > 0:
                if tot_m <= 10:
                    intensity = 1
                elif tot_m <= 25:
                    intensity = 2
                elif tot_m <= 45:
                    intensity = 3
                else:
                    intensity = 4

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
            'time_saved_hours': time_saved_hours,
            'time_saved_minutes': time_saved_mins,
            'monthly_time_saved_hours': monthly_time_saved_hours,
            'equivalent_full_books': equivalent_full_books,
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


class UserLearningReportView(views.APIView):
    """
    GET /api/v1/progress/analytics/wrapped/?period=annual&year=2026
    Generates a personalized "Blinkist Wrapped" and Annual/Monthly Learning Report.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from datetime import date
        import calendar
        from apps.catalog.models import Category
        from apps.summaries.models import UserHighlight

        user = request.user
        today = timezone.localdate()
        period_type = request.query_params.get('period', 'annual')  # 'annual' or 'monthly'

        try:
            year = int(request.query_params.get('year', today.year))
        except (ValueError, TypeError):
            year = today.year

        if period_type == 'monthly':
            try:
                month = int(request.query_params.get('month', today.month))
            except (ValueError, TypeError):
                month = today.month
            start_date = date(year, month, 1)
            _, last_day = calendar.monthrange(year, month)
            end_date = min(today, date(year, month, last_day))
            period_label = f"{start_date.strftime('%B %Y')} Learning Report"
        else:
            start_date = date(year, 1, 1)
            end_date = min(today, date(year, 12, 31))
            period_label = f"{year} Blinkist Wrapped"

        activities = UserDailyActivity.objects.filter(
            user=user,
            date__gte=start_date,
            date__lte=end_date,
        )
        agg = activities.aggregate(
            read_m=models.Sum('reading_minutes'),
            aud_m=models.Sum('audio_minutes'),
            sec_r=models.Sum('sections_read'),
            books_c=models.Sum('books_completed'),
        )
        reading_minutes = agg['read_m'] or 0
        audio_minutes = agg['aud_m'] or 0
        sections_read = agg['sec_r'] or 0
        books_completed = agg['books_c'] or 0

        # Account for books marked completed in period
        completed_in_period = UserBookProgress.objects.filter(
            user=user,
            is_completed=True,
            last_read_at__date__gte=start_date,
            last_read_at__date__lte=end_date,
        ).count()
        books_completed = max(books_completed, completed_in_period)

        total_minutes = reading_minutes + audio_minutes
        total_hours = round(total_minutes / 60.0, 1)

        # Audio vs reading ratio
        if total_minutes > 0:
            audio_pct = int(round((audio_minutes / total_minutes) * 100))
            reading_pct = 100 - audio_pct
        else:
            audio_pct = 60
            reading_pct = 40

        # Time saved metric: full book ~360 mins vs 15 min summary
        time_saved_mins = (books_completed * 345) + max(0, (sections_read - books_completed * 8) * 40)
        if time_saved_mins == 0 and total_minutes > 0:
            time_saved_mins = total_minutes * 4
        time_saved_hours = round(time_saved_mins / 60.0, 1)
        time_saved_days = round(time_saved_hours / 24.0, 1)

        # Top Categories
        book_ids = set(UserSummaryProgress.objects.filter(
            user=user,
            last_read_at__date__gte=start_date,
            last_read_at__date__lte=end_date,
        ).values_list('book_id', flat=True))
        book_ids.update(UserAudioProgress.objects.filter(
            user=user,
            last_listened_at__date__gte=start_date,
            last_listened_at__date__lte=end_date,
        ).values_list('book_id', flat=True))

        category_counts = {}
        if book_ids:
            for cat in Category.objects.filter(books__id__in=book_ids).annotate(c=models.Count('books')):
                category_counts[cat.name] = category_counts.get(cat.name, 0) + cat.c

        # Default fallback categories if new user
        if not category_counts:
            category_counts = {
                'Productivity & Time Management': 4,
                'Psychology & Mindset': 3,
                'Career & Success': 2,
                'Personal Finance': 1,
            }

        top_categories = []
        tot_cat_events = sum(category_counts.values()) or 1
        sorted_cats = sorted(category_counts.items(), key=lambda x: x[1], reverse=True)[:4]
        colors = ['#10B981', '#6366F1', '#F59E0B', '#EC4899']
        icons = ['zap', 'brain', 'briefcase', 'compass']
        for idx, (cat_name, count) in enumerate(sorted_cats):
            pct = int(round((count / tot_cat_events) * 100))
            top_categories.append({
                'name': cat_name,
                'count': count,
                'percentage': pct,
                'color': colors[idx % len(colors)],
                'icon': icons[idx % len(icons)],
            })

        # Learner archetype derivation
        primary_cat = sorted_cats[0][0] if sorted_cats else 'Productivity'
        if 'Productivity' in primary_cat or 'Habit' in primary_cat:
            archetype = "The Hyper-Productive Strategist"
            description = "You focus on compounding small daily gains and optimizing systems to maximize output and focus."
        elif 'Psychology' in primary_cat or 'Mind' in primary_cat:
            archetype = "The Mindset & Behavior Explorer"
            description = "You seek deep understanding of cognitive models, behavioral psychology, and human decision-making."
        elif 'Career' in primary_cat or 'Business' in primary_cat or 'Leadership' in primary_cat:
            archetype = "The High-Impact Leader"
            description = "You translate strategic thinking into scalable leadership, high leverage, and breakthrough execution."
        elif 'Finance' in primary_cat or 'Money' in primary_cat:
            archetype = "The Wealth & Freedom Architect"
            description = "You master the mechanics of financial independence, asymmetrical upside, and long-term leverage."
        else:
            archetype = "The Lifelong Polymath"
            description = "Your curiosity spans diverse multidisciplinary domains, synthesizing unique cross-functional ideas."

        # Action Plans & Micro-Habits
        completed_plans = ActionPlan.objects.filter(
            user=user,
            is_active=True,
            completed_at__date__gte=start_date,
            completed_at__date__lte=end_date,
        ).count()
        habits_formed = ActionPlanItem.objects.filter(
            plan__user=user,
            is_completed=True,
            completed_at__date__gte=start_date,
            completed_at__date__lte=end_date,
        ).count()

        # Highlights count
        highlights_count = UserHighlight.objects.filter(
            user=user,
            created_at__date__gte=start_date,
            created_at__date__lte=end_date,
        ).count()

        # Top Book
        top_book_prog = UserSummaryProgress.objects.filter(
            user=user,
            last_read_at__date__gte=start_date,
            last_read_at__date__lte=end_date,
        ).select_related('book', 'book__author').order_by('-completed_sections_count').first()
        top_book = None
        if top_book_prog and top_book_prog.book:
            b = top_book_prog.book
            top_book = {
                'id': b.id,
                'slug': b.slug,
                'title': b.title,
                'author': b.author.name if b.author else 'Author',
                'cover_image_url': b.cover_image.url if getattr(b, 'cover_image', None) else None,
                'sections_completed': top_book_prog.completed_sections_count,
            }
        else:
            # Fallback to featured book
            fb = Book.objects.first()
            if fb:
                top_book = {
                    'id': fb.id,
                    'slug': fb.slug,
                    'title': fb.title,
                    'author': fb.author.name if fb.author else 'Author',
                    'cover_image_url': fb.cover_image.url if getattr(fb, 'cover_image', None) else None,
                    'sections_completed': 8,
                }

        # Days active
        active_days = activities.filter(
            models.Q(reading_minutes__gt=0) | models.Q(audio_minutes__gt=0)
        ).count()
        if user.last_active_date and start_date <= user.last_active_date <= end_date:
            active_days = max(1, active_days)

        # Shareable text snippet
        shareable_text = (
            f"🎉 My {year} Blinkist Wrapped!\n\n"
            f"🧠 Archetype: {archetype}\n"
            f"⚡ Time Saved: {time_saved_hours} hours\n"
            f"📚 Books Explored: {books_completed} completed ({total_hours}h learning)\n"
            f"🎯 Core Domain: {primary_cat}\n"
            f"🔥 Longest Streak: {user.longest_streak} days\n\n"
            f"#Blinkist #LifelongLearning #BlinkistWrapped"
        )

        return response.Response({
            'period_type': period_type,
            'period_label': period_label,
            'year': year,
            'total_minutes': total_minutes,
            'total_hours': total_hours,
            'reading_minutes': reading_minutes,
            'audio_minutes': audio_minutes,
            'audio_percentage': audio_pct,
            'reading_percentage': reading_pct,
            'books_completed_count': books_completed,
            'sections_completed_count': sections_read,
            'time_saved_hours': time_saved_hours,
            'time_saved_days': time_saved_days,
            'top_categories': top_categories,
            'learner_archetype': archetype,
            'learner_archetype_description': description,
            'completed_action_plans': completed_plans,
            'habits_formed': habits_formed,
            'key_ideas_retained': highlights_count,
            'active_days_count': active_days,
            'current_streak': user.get_current_streak(today=today),
            'longest_streak': user.longest_streak,
            'top_book': top_book,
            'shareable_text': shareable_text,
        })


class ActionPlanGenerateView(views.APIView):
    """
    POST /api/v1/progress/books/<book_identifier>/action-plan/generate/
    Synthesizes a structured 7-day or 14-day micro-habit roadmap using Gemini & personal highlights.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, book_identifier):
        if str(book_identifier).isdigit():
            book = get_object_or_404(Book, id=int(book_identifier))
        else:
            book = get_object_or_404(Book, slug=book_identifier)

        duration_days = int(request.data.get('duration_days', 7))
        force_regenerate = bool(request.data.get('force_regenerate', False))

        plan = ActionPlanService.generate_plan(
            user=request.user,
            book=book,
            duration_days=duration_days,
            force_regenerate=force_regenerate,
        )

        serializer = ActionPlanSerializer(plan, context={'request': request})
        return response.Response(serializer.data, status=status.HTTP_201_CREATED)


class ActionPlanListView(views.APIView):
    """
    GET /api/v1/progress/action-plans/
    Lists all action plans belonging to the authenticated user.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        qs = ActionPlan.objects.filter(user=request.user).select_related('book', 'book__author').prefetch_related('items')

        book_slug = request.query_params.get('book_slug')
        if book_slug:
            qs = qs.filter(book__slug=book_slug)

        active_only = request.query_params.get('active')
        if active_only is not None:
            is_active = active_only.lower() in ('true', '1')
            qs = qs.filter(is_active=is_active)

        serializer = ActionPlanSerializer(qs, many=True, context={'request': request})
        return response.Response(serializer.data)


class ActionPlanDetailView(views.APIView):
    """
    GET /api/v1/progress/action-plans/<int:pk>/
    DELETE /api/v1/progress/action-plans/<int:pk>/
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        plan = get_object_or_404(
            ActionPlan.objects.select_related('book', 'book__author').prefetch_related('items'),
            id=pk,
            user=request.user,
        )
        serializer = ActionPlanSerializer(plan, context={'request': request})
        return response.Response(serializer.data)

    def delete(self, request, pk):
        plan = get_object_or_404(ActionPlan, id=pk, user=request.user)
        plan.delete()
        return response.Response({'detail': 'Action plan deleted successfully.'}, status=status.HTTP_204_NO_CONTENT)


class ActionPlanItemToggleView(views.APIView):
    """
    PATCH /api/v1/progress/action-plans/<int:pk>/items/<int:item_id>/toggle/
    Toggles completion of a specific daily micro-habit.
    Awards activity reading minutes for streak calculation.
    """
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, pk, item_id):
        plan = get_object_or_404(ActionPlan, id=pk, user=request.user)
        item = get_object_or_404(ActionPlanItem, id=item_id, plan=plan)

        if 'is_completed' in request.data:
            item.is_completed = bool(request.data.get('is_completed'))
        else:
            item.is_completed = not item.is_completed

        if item.is_completed:
            item.completed_at = timezone.now()
            # Record activity for daily habit streak multiplier
            record_activity(
                request.user,
                reading_minutes=3,
                sections_read=0,
                books_completed=0,
            )
        else:
            item.completed_at = None

        item.save(update_fields=['is_completed', 'completed_at'])

        # Check if entire plan is completed
        total = plan.items.count()
        completed_count = plan.items.filter(is_completed=True).count()
        if total > 0 and completed_count >= total:
            if not plan.completed_at:
                plan.completed_at = timezone.now()
                plan.save(update_fields=['completed_at'])
        else:
            if plan.completed_at:
                plan.completed_at = None
                plan.save(update_fields=['completed_at'])

        serializer = ActionPlanSerializer(plan, context={'request': request})
        return response.Response(serializer.data)

    def post(self, request, pk, item_id):
        return self.patch(request, pk, item_id)


class ActionPlanExportView(views.APIView):
    """
    GET /api/v1/progress/action-plans/<int:pk>/export/
    Supports ?format=markdown | ics | notion | json
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        plan = get_object_or_404(
            ActionPlan.objects.select_related('book', 'book__author').prefetch_related('items'),
            id=pk,
            user=request.user,
        )

        export_format = (
            request.query_params.get('export_format')
            or request.query_params.get('type')
            or request.query_params.get('format')
            or 'json'
        ).lower()
        md_text = ActionPlanExportService.to_markdown(plan)
        notion_text = ActionPlanExportService.to_notion(plan)
        ics_text = ActionPlanExportService.to_ics(plan)

        if export_format in ('ics', 'calendar'):
            resp = HttpResponse(ics_text, content_type='text/calendar; charset=utf-8')
            resp['Content-Disposition'] = f'attachment; filename="{plan.book.slug}-habit-roadmap.ics"'
            return resp

        if export_format in ('md', 'markdown'):
            resp = HttpResponse(md_text, content_type='text/markdown; charset=utf-8')
            resp['Content-Disposition'] = f'attachment; filename="{plan.book.slug}-habit-roadmap.md"'
            return resp

        return response.Response({
            'plan_id': plan.id,
            'title': plan.title,
            'book_title': plan.book.title,
            'duration_days': plan.duration_days,
            'progress_percent': plan.progress_percent,
            'markdown': md_text,
            'notion_text': notion_text,
            'ics_content': ics_text,
        })


class ActivePlaybackSessionView(views.APIView):
    """
    GET /api/v1/progress/active-session/
    Returns the latest cross-platform playback session across all user devices (Web/Mobile).
    Query parameter: ?current_device_type=web | mobile

    POST /api/v1/progress/active-session/
    Reports active playback position heartbeat from Web or Mobile.
    Payload: {
        "book_id": int or slug,
        "section_id": int or slug (optional),
        "position_seconds": float,
        "duration_seconds": float (optional),
        "device_type": "web" | "mobile",
        "device_name": str,
        "is_playing": bool,
        "is_finished": bool (optional)
    }
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        current_device_type = request.query_params.get('current_device_type', '')

        cache_key = f"active_playback_session_{user.id}"
        session = cache.get(cache_key)

        # Fallback to most recent UserAudioProgress from DB if cache expired or absent
        if not session:
            latest_audio = UserAudioProgress.objects.filter(
                user=user,
                is_finished=False,
                current_position_seconds__gt=5,
            ).select_related('book', 'book__author', 'current_section').order_by('-last_listened_at').first()

            if latest_audio:
                book = latest_audio.book
                section = latest_audio.current_section
                pos = latest_audio.current_position_seconds
                mins = int(pos // 60)
                secs = int(pos % 60)
                formatted_pos = f"{mins:02d}:{secs:02d}"

                cover_url = None
                if book.cover_image:
                    cover_url = request.build_absolute_uri(book.cover_image.url)

                audio_url = None
                if section and section.audio_file:
                    audio_url = request.build_absolute_uri(section.audio_file.url)

                session = {
                    "book_id": book.id,
                    "book_slug": book.slug,
                    "book_title": book.title,
                    "author_name": book.author.name if book.author else "Author",
                    "cover_image_url": cover_url,
                    "section_id": section.id if section else None,
                    "section_title": section.title if section else "Summary",
                    "section_order": section.order if section else 1,
                    "total_sections": book.sections.count(),
                    "position_seconds": round(pos, 1),
                    "formatted_position": formatted_pos,
                    "duration_seconds": section.duration_seconds if section and section.duration_seconds else 600,
                    "audio_url": audio_url,
                    "device_type": "mobile",
                    "device_name": "Mobile App",
                    "is_playing": False,
                    "updated_at": latest_audio.last_listened_at.isoformat(),
                }

        if not session:
            return response.Response({"has_active_session": False})

        device_type = session.get("device_type", "unknown")
        device_name = session.get("device_name", "another device")
        book_title = session.get("book_title", "Book")
        formatted_pos = session.get("formatted_position", "00:00")
        is_different_device = bool(current_device_type and current_device_type != device_type)

        prompt_message = f"Resume {book_title} at {formatted_pos} from {device_name}?"

        return response.Response({
            "has_active_session": True,
            "can_resume": is_different_device,
            "prompt_message": prompt_message,
            **session
        })

    def post(self, request):
        user = request.user
        data = request.data

        book_id = data.get('book_id')
        book_slug = data.get('book_slug')
        book = None
        if book_id:
            book = Book.objects.filter(id=book_id).first()
        elif book_slug:
            book = Book.objects.filter(slug=book_slug).first()

        if not book:
            return response.Response({'error': 'Book not found'}, status=status.HTTP_404_NOT_FOUND)

        section_id = data.get('section_id')
        section = None
        if section_id:
            section = SummarySection.objects.filter(id=section_id, book=book).first()
        if not section and book.sections.exists():
            section = book.sections.order_by('order').first()

        position_seconds = float(data.get('position_seconds', 0.0) or 0.0)
        duration_seconds = float(data.get('duration_seconds', 0.0) or (section.duration_seconds if section else 600))
        device_type = data.get('device_type', 'web')
        device_name = data.get('device_name', 'Web Browser' if device_type == 'web' else 'Mobile Device')
        is_playing = bool(data.get('is_playing', False))
        is_finished = bool(data.get('is_finished', False))

        mins = int(position_seconds // 60)
        secs = int(position_seconds % 60)
        formatted_pos = f"{mins:02d}:{secs:02d}"

        cover_url = None
        if book.cover_image:
            cover_url = request.build_absolute_uri(book.cover_image.url)

        audio_url = None
        if section and section.audio_file:
            audio_url = request.build_absolute_uri(section.audio_file.url)

        session_data = {
            "book_id": book.id,
            "book_slug": book.slug,
            "book_title": book.title,
            "author_name": book.author.name if book.author else "Author",
            "cover_image_url": cover_url,
            "section_id": section.id if section else None,
            "section_title": section.title if section else "Summary",
            "section_order": section.order if section else 1,
            "total_sections": book.sections.count(),
            "position_seconds": round(position_seconds, 1),
            "formatted_position": formatted_pos,
            "duration_seconds": duration_seconds,
            "audio_url": audio_url,
            "device_type": device_type,
            "device_name": device_name,
            "is_playing": is_playing,
            "updated_at": timezone.now().isoformat(),
        }

        cache_key = f"active_playback_session_{user.id}"
        cache.set(cache_key, session_data, timeout=86400 * 7)

        # Persist to UserAudioProgress in DB
        progress, _ = UserAudioProgress.objects.get_or_create(user=user, book=book)
        delta_secs = max(0.0, position_seconds - progress.current_position_seconds)
        audio_mins = int(round(delta_secs / 60.0)) if delta_secs >= 30 else 0

        progress.current_section = section
        progress.current_position_seconds = position_seconds
        progress.is_finished = is_finished
        progress.save()

        if audio_mins > 0:
            record_activity(user, audio_minutes=audio_mins, books_completed=1 if is_finished else 0)

        return response.Response({
            "status": "synchronized",
            "session": session_data,
        })


class PlaybackHandoffView(views.APIView):
    """
    POST /api/v1/progress/active-session/handoff/
    Confirms handoff to the requesting device and returns the exact playback state.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        target_device = request.data.get('device_type', 'web')
        target_name = request.data.get('device_name', 'Web Browser' if target_device == 'web' else 'Mobile Device')

        cache_key = f"active_playback_session_{user.id}"
        session = cache.get(cache_key)

        if not session:
            latest = UserAudioProgress.objects.filter(
                user=user,
                is_finished=False,
            ).select_related('book', 'book__author', 'current_section').order_by('-last_listened_at').first()

            if not latest:
                return response.Response({'error': 'No active session to hand off'}, status=status.HTTP_404_NOT_FOUND)

            book = latest.book
            section = latest.current_section
            pos = latest.current_position_seconds
            mins = int(pos // 60)
            secs = int(pos % 60)

            cover_url = None
            if book.cover_image:
                cover_url = request.build_absolute_uri(book.cover_image.url)

            audio_url = None
            if section and section.audio_file:
                audio_url = request.build_absolute_uri(section.audio_file.url)

            session = {
                "book_id": book.id,
                "book_slug": book.slug,
                "book_title": book.title,
                "author_name": book.author.name if book.author else "Author",
                "cover_image_url": cover_url,
                "section_id": section.id if section else None,
                "section_title": section.title if section else "Summary",
                "section_order": section.order if section else 1,
                "total_sections": book.sections.count(),
                "position_seconds": round(pos, 1),
                "formatted_position": f"{mins:02d}:{secs:02d}",
                "duration_seconds": section.duration_seconds if section and section.duration_seconds else 600,
                "audio_url": audio_url,
            }

        prev_device = session.get('device_name', 'previous device')
        prev_type = session.get('device_type', 'unknown')
        session['device_type'] = target_device
        session['device_name'] = target_name
        session['is_playing'] = True
        session['updated_at'] = timezone.now().isoformat()
        cache.set(cache_key, session, timeout=86400 * 7)

        try:
            SYNC_HANDOFFS_TOTAL.labels(source_device=prev_type, target_device=target_device).inc()
        except Exception:
            pass

        return response.Response({
            "status": "handed_off",
            "message": f"Playback handed off from {prev_device} to {target_name}",
            "session": session,
        })



