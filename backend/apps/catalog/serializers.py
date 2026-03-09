from rest_framework import serializers
from apps.catalog.models import Book, Category, Author
from apps.summaries.models import SummarySection

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ('id', 'name', 'slug', 'description')

class AuthorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Author
        fields = ('id', 'name', 'bio', 'avatar_url')

class SummarySectionListSerializer(serializers.ModelSerializer):
    audio_url = serializers.SerializerMethodField()

    class Meta:
        model = SummarySection
        fields = ('id', 'slug', 'order', 'title', 'duration_seconds', 'estimated_read_minutes', 'audio_url')

    def get_audio_url(self, obj):
        if obj.audio_file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.audio_file.url)
            return obj.audio_file.url
        return None

class BookListSerializer(serializers.ModelSerializer):
    author = AuthorSerializer(read_only=True)
    categories = CategorySerializer(many=True, read_only=True)
    cover_image_url = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = ('id', 'title', 'subtitle', 'slug', 'author', 'categories', 
                  'cover_image_url', 'estimated_read_time_minutes', 'is_premium')

    def get_cover_image_url(self, obj):
        if obj.cover_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.cover_image.url)
            return obj.cover_image.url
        return None

class SummarySectionDetailSerializer(SummarySectionListSerializer):
    """Includes full content for the reader screen."""
    class Meta(SummarySectionListSerializer.Meta):
        fields = SummarySectionListSerializer.Meta.fields + ('content',)

class BookDetailSerializer(BookListSerializer):
    sections = SummarySectionDetailSerializer(many=True, read_only=True)
    
    class Meta(BookListSerializer.Meta):
        fields = BookListSerializer.Meta.fields + ('description', 'what_you_will_learn', 'sections')
