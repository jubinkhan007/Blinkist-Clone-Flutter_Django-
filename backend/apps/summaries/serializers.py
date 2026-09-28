from rest_framework import serializers

from apps.summaries.models import SummarySection


class SummarySectionSerializer(serializers.ModelSerializer):
    content = serializers.SerializerMethodField()
    plainText = serializers.CharField(source='plain_text')
    audioUrl = serializers.SerializerMethodField()
    durationSeconds = serializers.IntegerField(source='duration_seconds')
    estimatedReadMinutes = serializers.IntegerField(source='estimated_read_minutes')

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
        if obj.audio_file:
            if request:
                return request.build_absolute_uri(obj.audio_file.url)
            return obj.audio_file.url
        return None
