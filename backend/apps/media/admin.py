from django.contrib import admin
from django.utils.html import format_html
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import display

from .models import DailyAudioDigest, DailyAudioDigestItem, UserDailyDigestProgress


class DailyAudioDigestItemInline(TabularInline):
    model = DailyAudioDigestItem
    extra = 0
    fields = ('order', 'book', 'section', 'insight_prompt', 'audio_preview')
    readonly_fields = ('audio_preview',)

    @display(description='Track Audio')
    def audio_preview(self, obj):
        if obj and obj.section and obj.section.audio_file:
            return format_html(
                '<audio controls preload="none" style="height: 28px; width: 170px;">'
                '<source src="{}" type="audio/mpeg">'
                '</audio>',
                obj.section.audio_file.url,
            )
        return '-'


@admin.register(DailyAudioDigest)
class DailyAudioDigestAdmin(ModelAdmin):
    list_display = (
        'date',
        'title',
        'theme',
        'target_audience',
        'item_count',
        'duration_badge',
        'created_at',
    )
    list_filter = ('date', 'theme')
    search_fields = ('title', 'subtitle', 'theme', 'user__email')
    inlines = [DailyAudioDigestItemInline]
    date_hierarchy = 'date'

    @display(description='Audience')
    def target_audience(self, obj):
        if obj.user:
            return format_html(
                '<span style="background: #e0e7ff; color: #3730a3; padding: 2px 8px; border-radius: 9999px; font-weight: 500; font-size: 11px;">Personalized ({})</span>',
                obj.user.email,
            )
        return format_html(
            '<span style="background: #ecfdf5; color: #065f46; padding: 2px 8px; border-radius: 9999px; font-weight: 500; font-size: 11px;">Universal Daily</span>'
        )

    @display(description='Insights')
    def item_count(self, obj):
        return f"{obj.items.count()} Insights"

    @display(description='Duration')
    def duration_badge(self, obj):
        return obj.formatted_duration


@admin.register(UserDailyDigestProgress)
class UserDailyDigestProgressAdmin(ModelAdmin):
    list_display = (
        'user',
        'digest_date',
        'digest_theme',
        'completion_badge',
        'current_item_index',
        'position_display',
        'updated_at',
    )
    list_filter = ('is_completed', 'digest__date')
    search_fields = ('user__email', 'digest__title', 'digest__theme')
    list_select_related = ('user', 'digest')

    @display(description='Date')
    def digest_date(self, obj):
        return obj.digest.date

    @display(description='Theme')
    def digest_theme(self, obj):
        return obj.digest.theme

    @display(description='Status')
    def completion_badge(self, obj):
        if obj.is_completed:
            return format_html(
                '<span style="background: #dcfce7; color: #166534; padding: 2px 8px; border-radius: 9999px; font-weight: 600; font-size: 11px;">✓ Completed</span>'
            )
        return format_html(
            '<span style="background: #fef3c7; color: #92400e; padding: 2px 8px; border-radius: 9999px; font-weight: 500; font-size: 11px;">In Progress (Track {})</span>',
            obj.current_item_index + 1,
        )

    @display(description='Position')
    def position_display(self, obj):
        mins, secs = divmod(obj.current_position_seconds, 60)
        return f"{mins:02d}:{secs:02d}"
