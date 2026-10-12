from rest_framework import serializers
from .models import DailyAudioDigest, DailyAudioDigestItem, UserDailyDigestProgress


class DailyAudioDigestItemSerializer(serializers.ModelSerializer):
    book_id = serializers.IntegerField(source='book.id', read_only=True)
    book_title = serializers.CharField(source='book.title', read_only=True)
    book_subtitle = serializers.CharField(source='book.subtitle', read_only=True)
    book_slug = serializers.CharField(source='book.slug', read_only=True)
    author_name = serializers.CharField(source='book.author.name', read_only=True)
    cover_image_url = serializers.SerializerMethodField()
    section_id = serializers.IntegerField(source='section.id', read_only=True)
    section_title = serializers.CharField(source='section.title', read_only=True)
    section_order = serializers.IntegerField(source='section.order', read_only=True)
    audio_url = serializers.SerializerMethodField()
    duration_seconds = serializers.IntegerField(source='section.duration_seconds', read_only=True)

    class Meta:
        model = DailyAudioDigestItem
        fields = (
            'id',
            'order',
            'insight_prompt',
            'book_id',
            'book_title',
            'book_subtitle',
            'book_slug',
            'author_name',
            'cover_image_url',
            'section_id',
            'section_title',
            'section_order',
            'audio_url',
            'duration_seconds',
        )

    def get_cover_image_url(self, obj):
        if obj.book and obj.book.cover_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.book.cover_image.url)
            return obj.book.cover_image.url
        return None

    def get_audio_url(self, obj):
        if obj.section and obj.section.audio_file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.section.audio_file.url)
            return obj.section.audio_file.url
        return None


class UserDailyDigestProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserDailyDigestProgress
        fields = (
            'is_completed',
            'current_item_index',
            'current_position_seconds',
            'completed_at',
            'updated_at',
        )


class DailyAudioDigestSerializer(serializers.ModelSerializer):
    formatted_duration = serializers.CharField(read_only=True)
    items = DailyAudioDigestItemSerializer(many=True, read_only=True)
    user_progress = serializers.SerializerMethodField()

    class Meta:
        model = DailyAudioDigest
        fields = (
            'id',
            'date',
            'title',
            'subtitle',
            'theme',
            'total_duration_seconds',
            'formatted_duration',
            'items',
            'user_progress',
        )

    def get_user_progress(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            progress = UserDailyDigestProgress.objects.filter(
                user=request.user,
                digest=obj
            ).first()
            if progress:
                return UserDailyDigestProgressSerializer(progress).data
        return None


class DailyDigestProgressUpdateSerializer(serializers.Serializer):
    digest_id = serializers.IntegerField()
    current_item_index = serializers.IntegerField(default=0, min_value=0)
    current_position_seconds = serializers.IntegerField(default=0, min_value=0)
    is_completed = serializers.BooleanField(default=False)
