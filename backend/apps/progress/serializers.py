from rest_framework import serializers
from .models import (
    UserBookProgress,
    UserSectionProgress,
    UserAudioProgress,
    UserSummaryProgress,
    UserFullBookProgress,
    ActionPlan,
    ActionPlanItem,
)

class UserSummaryProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserSummaryProgress
        fields = ('id', 'book', 'current_section', 'completed_sections_count', 'last_read_at')
        read_only_fields = ('id', 'last_read_at')

class UserBookProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserBookProgress
        fields = ('id', 'book', 'current_section', 'percent_complete', 'last_read_at', 'is_completed')
        read_only_fields = ('id', 'last_read_at')

class UserSectionProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserSectionProgress
        fields = ('id', 'section', 'is_completed', 'read_at')
        read_only_fields = ('id', 'read_at')

class UserAudioProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserAudioProgress
        fields = ('id', 'book', 'current_section', 'current_position_seconds', 'is_finished', 'last_listened_at')
        read_only_fields = ('id', 'last_listened_at')


class UserFullBookProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserFullBookProgress
        fields = ('id', 'book', 'current_page', 'current_offset', 'last_opened_at')
        read_only_fields = ('id', 'last_opened_at')


class ActionPlanItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = ActionPlanItem
        fields = (
            'id',
            'day_number',
            'title',
            'description',
            'suggested_habit',
            'associated_quote',
            'is_completed',
            'completed_at',
        )
        read_only_fields = ('id', 'day_number', 'completed_at')


class ActionPlanSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source='book.title', read_only=True)
    book_slug = serializers.CharField(source='book.slug', read_only=True)
    book_author = serializers.CharField(source='book.author.name', read_only=True)
    book_cover_image_url = serializers.SerializerMethodField()
    items = ActionPlanItemSerializer(many=True, read_only=True)
    total_items_count = serializers.IntegerField(read_only=True)
    completed_items_count = serializers.IntegerField(read_only=True)
    progress_percent = serializers.IntegerField(read_only=True)
    is_completed = serializers.BooleanField(read_only=True)

    class Meta:
        model = ActionPlan
        fields = (
            'id',
            'book',
            'book_title',
            'book_slug',
            'book_author',
            'book_cover_image_url',
            'title',
            'duration_days',
            'is_active',
            'is_completed',
            'progress_percent',
            'completed_items_count',
            'total_items_count',
            'items',
            'created_at',
            'updated_at',
            'completed_at',
        )
        read_only_fields = (
            'id',
            'book',
            'book_title',
            'book_slug',
            'book_author',
            'book_cover_image_url',
            'created_at',
            'updated_at',
            'completed_at',
        )

    def get_book_cover_image_url(self, obj) -> str:
        request = self.context.get('request')
        if obj.book and obj.book.cover_image:
            if request:
                return request.build_absolute_uri(obj.book.cover_image.url)
            return obj.book.cover_image.url
        return ''

