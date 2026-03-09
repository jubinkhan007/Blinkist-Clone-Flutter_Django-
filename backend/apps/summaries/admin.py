from django.contrib import admin
from .models import SummarySection


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

