from rest_framework import serializers
from apps.catalog.models import Book
from apps.summaries.models import SummarySection, UserHighlight


class HighlightBookSerializer(serializers.ModelSerializer):
    author = serializers.CharField(source='author.name', read_only=True)
    cover_image_url = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = ('id', 'title', 'subtitle', 'slug', 'author', 'cover_image_url')

    def get_cover_image_url(self, obj):
        if obj.cover_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.cover_image.url)
            return obj.cover_image.url
        return None


class HighlightSectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = SummarySection
        fields = ('id', 'slug', 'order', 'title')


class UserHighlightSerializer(serializers.ModelSerializer):
    book = HighlightBookSerializer(read_only=True)
    section = HighlightSectionSerializer(read_only=True)

    class Meta:
        model = UserHighlight
        fields = (
            'id',
            'book',
            'section',
            'selected_text',
            'note',
            'color',
            'created_at',
            'updated_at',
        )


class UserHighlightCreateSerializer(serializers.ModelSerializer):
    book_slug = serializers.SlugField(write_only=True)
    section_id = serializers.IntegerField(write_only=True, required=False, allow_null=True)

    class Meta:
        model = UserHighlight
        fields = (
            'id',
            'book_slug',
            'section_id',
            'selected_text',
            'note',
            'color',
        )

    def validate(self, attrs):
        book_slug = attrs.get('book_slug')
        try:
            book = Book.objects.get(slug=book_slug)
        except Book.DoesNotExist:
            raise serializers.ValidationError({'book_slug': 'Book not found.'})

        section_id = attrs.get('section_id')
        section = None
        if section_id:
            try:
                section = SummarySection.objects.get(id=section_id, book=book)
            except SummarySection.DoesNotExist:
                raise serializers.ValidationError({'section_id': 'Summary section not found for this book.'})

        attrs['book'] = book
        attrs['section'] = section
        return attrs

    def create(self, validated_data):
        validated_data.pop('book_slug', None)
        validated_data.pop('section_id', None)
        user = self.context['request'].user
        return UserHighlight.objects.create(user=user, **validated_data)
