from rest_framework import serializers

from apps.catalog.serializers import AuthorSerializer, CategorySerializer


class ContinueReadingSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    title = serializers.CharField()
    subtitle = serializers.CharField()
    slug = serializers.CharField()
    author = AuthorSerializer()
    categories = CategorySerializer(many=True)
    cover_image_url = serializers.SerializerMethodField()
    estimated_read_time_minutes = serializers.IntegerField()
    is_premium = serializers.BooleanField()
    is_saved = serializers.BooleanField()
    percent_complete = serializers.FloatField()
    last_read_at = serializers.DateTimeField()
    current_section_title = serializers.CharField(allow_null=True)
    last_mode = serializers.CharField()

    def get_cover_image_url(self, obj):
        cover_image = obj.get('cover_image')
        if not cover_image:
            return None

        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(cover_image.url)
        return cover_image.url
