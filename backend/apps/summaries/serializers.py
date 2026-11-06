from rest_framework import serializers

from apps.summaries.models import SummarySection


class SummarySectionSerializer(serializers.ModelSerializer):
    content = serializers.SerializerMethodField()
    plainText = serializers.CharField(source='plain_text')
    audioUrl = serializers.SerializerMethodField()
    durationSeconds = serializers.IntegerField(source='duration_seconds')
    estimatedReadMinutes = serializers.IntegerField(source='estimated_read_minutes')
    availableVoices = serializers.SerializerMethodField()

    class Meta:
        model = SummarySection
        fields = (
            'id',
            'slug',
            'order',
            'title',
            'content',
            'plainText',
            'audioUrl',
            'durationSeconds',
            'estimatedReadMinutes',
            'availableVoices',
        )

    def get_content(self, obj):
        request = self.context.get('request')
        from apps.catalog.serializers import _can_access_summary
        if hasattr(obj, 'book') and not _can_access_summary(obj.book, request):
            return None
        return obj.content

    def get_audioUrl(self, obj):
        request = self.context.get('request')
        from apps.catalog.serializers import _can_access_summary
        if hasattr(obj, 'book') and not _can_access_summary(obj.book, request):
            return None

        # Check if a specific voice was requested via query param or header
        if request:
            requested_voice = request.query_params.get('voice') or request.headers.get('X-Narration-Voice')
            if requested_voice and requested_voice != 'christopher':
                from .voice_service import resolve_section_voice_audio
                voice_data = resolve_section_voice_audio(obj, voice_id=requested_voice, request=request)
                if voice_data.get('audio_url'):
                    return voice_data['audio_url']

        if obj.audio_file:
            if request:
                return request.build_absolute_uri(obj.audio_file.url)
            return obj.audio_file.url
        return None

    def get_availableVoices(self, obj):
        from .voice_service import get_voice_catalog
        return get_voice_catalog()
