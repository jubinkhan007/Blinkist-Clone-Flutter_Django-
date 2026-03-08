from django.contrib import admin
from .models import SummarySection

@admin.register(SummarySection)
class SummarySectionAdmin(admin.ModelAdmin):
    list_display = ('book', 'order', 'title', 'duration_seconds')
    list_filter = ('book',)
    search_fields = ('title', 'book__title')
    prepopulated_fields = {'slug': ('title',)}

