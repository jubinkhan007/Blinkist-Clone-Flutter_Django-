from django.contrib import admin
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import display

from apps.progress.badges import BADGES
from .models import (
    UserAudioProgress,
    UserBadge,
    UserBookProgress,
    UserDailyActivity,
    UserFullBookProgress,
    UserSectionProgress,
    UserSummaryProgress,
)


@admin.register(UserDailyActivity)
class UserDailyActivityAdmin(ModelAdmin):
    list_display = (
        'user',
        'date',
        'reading_minutes',
        'audio_minutes',
        'total_time_badge',
        'sections_read',
        'books_completed',
        'created_at',
    )
    list_filter = ('date', 'created_at')
    date_hierarchy = 'date'
    search_fields = ('user__email',)
    ordering = ('-date', '-created_at')

    @display(description='Total Learning')
    def total_time_badge(self, obj):
        total = obj.reading_minutes + obj.audio_minutes
        return format_html(
            '<span style="display: inline-block; padding: 2px 8px; border-radius: 12px; background: #ecfdf5; color: #047857; font-weight: 600; font-size: 11px;">⏱️ {} mins</span>',
            total,
        )


@admin.register(UserBadge)
class UserBadgeAdmin(ModelAdmin):
    list_display = ('user', 'badge_icon_display', 'badge_title_display', 'badge_key', 'unlocked_at')
    list_filter = ('badge_key', 'unlocked_at')
    search_fields = ('user__email', 'badge_key')
    ordering = ('-unlocked_at',)

    @display(description='Badge')
    def badge_icon_display(self, obj):
        badge_def = BADGES.get(obj.badge_key, {})
        icon = badge_def.get('icon', '🏆')
        return format_html('<span style="font-size: 18px;">{}</span>', icon)

    @display(description='Title')
    def badge_title_display(self, obj):
        badge_def = BADGES.get(obj.badge_key, {})
        title = badge_def.get('title', obj.badge_key)
        category = badge_def.get('category', '').title()
        return format_html(
            '<strong>{}</strong> <span style="font-size: 11px; color: #6b7280;">({})</span>',
            title,
            category,
        )


@admin.register(UserBookProgress)
class UserBookProgressAdmin(ModelAdmin):
    list_display = ('user', 'book', 'progress_bar', 'completion_badge', 'last_read_at')
    list_filter = ('is_completed', 'last_read_at')
    search_fields = ('user__email', 'book__title')
    raw_id_fields = ('user', 'book', 'current_section')
    ordering = ('-last_read_at',)

    @display(description='Completion %', ordering='percent_complete')
    def progress_bar(self, obj):
        pct = max(0, min(100, obj.percent_complete))
        color = '#00A86B' if obj.is_completed or pct >= 100 else '#3b82f6'
        return format_html(
            '<div style="display: flex; align-items: center; gap: 8px;">'
            '<div style="width: 80px; height: 8px; background: #e5e7eb; border-radius: 4px; overflow: hidden;">'
            '<div style="width: {}%; height: 100%; background: {};"></div>'
            '</div>'
            '<span style="font-size: 11px; font-weight: 600; color: #4b5563;">{}%</span>'
            '</div>',
            pct,
            color,
            pct,
        )

    @display(
        description='Status',
        label={
            'Finished': 'success',
            'In Progress': 'info',
        },
    )
    def completion_badge(self, obj):
        return 'Finished' if obj.is_completed else 'In Progress'


@admin.register(UserAudioProgress)
class UserAudioProgressAdmin(ModelAdmin):
    list_display = (
        'user',
        'book',
        'section_title',
        'position_display',
        'finished_badge',
        'last_listened_at',
    )
    list_filter = ('is_finished', 'last_listened_at')
    search_fields = ('user__email', 'book__title')
    raw_id_fields = ('user', 'book', 'current_section')
    ordering = ('-last_listened_at',)

    @display(description='Section')
    def section_title(self, obj):
        return obj.current_section.title if obj.current_section else '-'

    @display(description='Audio Position')
    def position_display(self, obj):
        m, s = divmod(int(obj.current_position_seconds), 60)
        return f'{m:02d}:{s:02d}'

    @display(
        description='Status',
        label={
            'Completed': 'success',
            'Listening': 'warning',
        },
    )
    def finished_badge(self, obj):
        return 'Completed' if obj.is_finished else 'Listening'


@admin.register(UserSectionProgress)
class UserSectionProgressAdmin(ModelAdmin):
    list_display = ('user', 'section', 'is_completed_badge', 'read_at')
    list_filter = ('is_completed', 'read_at')
    search_fields = ('user__email', 'section__title')
    raw_id_fields = ('user', 'section')
    ordering = ('-read_at',)

    @display(description='Completed', boolean=True)
    def is_completed_badge(self, obj):
        return obj.is_completed


@admin.register(UserSummaryProgress)
class UserSummaryProgressAdmin(ModelAdmin):
    list_display = ('user', 'book', 'completed_sections_count', 'last_read_at')
    search_fields = ('user__email', 'book__title')
    raw_id_fields = ('user', 'book', 'current_section')
    ordering = ('-last_read_at',)


@admin.register(UserFullBookProgress)
class UserFullBookProgressAdmin(ModelAdmin):
    list_display = ('user', 'book', 'current_page', 'last_opened_at')
    search_fields = ('user__email', 'book__title')
    raw_id_fields = ('user', 'book')
    ordering = ('-last_opened_at',)
