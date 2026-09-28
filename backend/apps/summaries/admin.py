from django.contrib import admin
from .models import SummarySection, UserHighlight


@admin.register(SummarySection)
class SummarySectionAdmin(admin.ModelAdmin):
    list_display = ('book', 'order', 'title', 'has_audio', 'duration_seconds')
    list_filter = ('book',)
    search_fields = ('title', 'book__title')
    prepopulated_fields = {'slug': ('title',)}
    ordering = ('book', 'order')
    list_select_related = ('book',)

    @admin.display(description='Audio', boolean=True)
    def has_audio(self, obj):
        return bool(obj.audio_file)


@admin.register(UserHighlight)
class UserHighlightAdmin(admin.ModelAdmin):
    list_display = ('user', 'book', 'section', 'color', 'short_text', 'created_at')
    list_filter = ('color', 'created_at')
    search_fields = ('user__email', 'book__title', 'selected_text', 'note')
    raw_id_fields = ('user', 'book', 'section')

    @admin.display(description='Quote')
    def short_text(self, obj):
        return obj.selected_text[:50]

