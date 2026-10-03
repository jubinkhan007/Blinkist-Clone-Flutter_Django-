from rest_framework import serializers
from apps.catalog.models import Book
from apps.summaries.models import SummarySection, UserAudioBookmark
from apps.summaries.highlight_serializers import HighlightBookSerializer, HighlightSectionSerializer


class UserAudioBookmarkSerializer(serializers.ModelSerializer):
    book = HighlightBookSerializer(read_only=True)
    section = HighlightSectionSerializer(read_only=True)
    formatted_timestamp = serializers.SerializerMethodField()

    class Meta:
        model = UserAudioBookmark
        fields = (
            'id',
            'book',
            'section',
            'timestamp_seconds',
            'formatted_timestamp',
            'title',
            'note',
            'created_at',
            'updated_at',
        )

    def get_formatted_timestamp(self, obj):
        total_seconds = obj.timestamp_seconds
        minutes = total_seconds // 60
        seconds = total_seconds % 60
        hours = minutes // 60
        if hours > 0:
            minutes = minutes % 60
            return f"{hours}:{minutes:02d}:{seconds:02d}"
        return f"{minutes:02d}:{seconds:02d}"


class UserAudioBookmarkCreateSerializer(serializers.ModelSerializer):
    book_slug = serializers.SlugField(write_only=True)
    section_id = serializers.IntegerField(write_only=True, required=False, allow_null=True)

    class Meta:
        model = UserAudioBookmark
        fields = (
            'id',
            'book_slug',
            'section_id',
            'timestamp_seconds',
            'title',
            'note',
        )

    def validate_book_slug(self, value):
        if not Book.objects.filter(slug=value).exists():
            raise serializers.ValidationError(f"Book with slug '{value}' does not exist.")
        return value

    def validate(self, attrs):
        section_id = attrs.get('section_id')
        book_slug = attrs.get('book_slug')
        if section_id:
            if not SummarySection.objects.filter(id=section_id, book__slug=book_slug).exists():
                raise serializers.ValidationError({"section_id": "Section does not belong to this book."})
        return attrs

    def create(self, validated_data):
        book_slug = validated_data.pop('book_slug')
        section_id = validated_data.pop('section_id', None)

        book = Book.objects.get(slug=book_slug)
        section = None
        if section_id:
            section = SummarySection.objects.get(id=section_id)

        validated_data['book'] = book
        validated_data['section'] = section
        user = self.context['request'].user
        return UserAudioBookmark.objects.create(user=user, **validated_data)
