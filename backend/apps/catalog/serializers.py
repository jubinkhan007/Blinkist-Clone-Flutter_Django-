from rest_framework import serializers
from apps.catalog.models import Author, Book, Category
from apps.summaries.models import SummarySection

def _user_has_premium_access(request) -> bool:
    """
    Anonymous users never have premium access.
    Authenticated users may have premium access via User.has_premium_access()
    (trialing/active) or legacy is_premium flag.
    """
    if request is None:
        return False

    user = getattr(request, "user", None)
    if user is None or not getattr(user, "is_authenticated", False):
        return False

    if hasattr(user, "has_premium_access"):
        return bool(user.has_premium_access())

    return bool(getattr(user, "is_premium", False))


def _can_access_summary(book, request) -> bool:
    """
    Returns True if user has access to summary insights (text/audio).
    Accessible if:
    - Book is not premium (free for all)
    - User has active premium access
    - Book is today's Daily Pick (free for today)
    """
    if not book.is_premium:
        return True
    if getattr(book, 'is_daily_free', False):
        return True
    return _user_has_premium_access(request)


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
        request = self.context.get('request')
        if not _can_access_summary(obj.book, request):
            return None

        if obj.audio_file:
            if request:
                return request.build_absolute_uri(obj.audio_file.url)
            return obj.audio_file.url
        return None

class BookListSerializer(serializers.ModelSerializer):
    author = AuthorSerializer(read_only=True)
    categories = CategorySerializer(many=True, read_only=True)
    cover_image_url = serializers.SerializerMethodField()
    is_saved = serializers.SerializerMethodField()
    is_daily_free = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = ('id', 'title', 'subtitle', 'slug', 'author', 'categories', 
                  'cover_image_url', 'estimated_read_time_minutes', 'is_premium', 
                  'is_daily_free', 'is_saved')

    def get_cover_image_url(self, obj):
        if obj.cover_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.cover_image.url)
            return obj.cover_image.url
        return None

    def get_is_saved(self, obj):
        if hasattr(obj, 'is_saved'):
            return bool(obj.is_saved)

        request = self.context.get('request')
        user = getattr(request, 'user', None)
        if user is None or not getattr(user, 'is_authenticated', False):
            return False

        return user.library_items.filter(book=obj).exists()

    def get_is_daily_free(self, obj):
        return bool(getattr(obj, 'is_daily_free', False))

class SummarySectionDetailSerializer(SummarySectionListSerializer):
    """Includes full content for the reader screen."""
    content = serializers.SerializerMethodField()

    class Meta(SummarySectionListSerializer.Meta):
        fields = SummarySectionListSerializer.Meta.fields + ('content',)

    def get_content(self, obj):
        request = self.context.get('request')
        if not _can_access_summary(obj.book, request):
            return None
        return obj.content

class BookDetailSerializer(BookListSerializer):
    sections = SummarySectionDetailSerializer(many=True, read_only=True)
    full_text = serializers.SerializerMethodField()
    full_book_pdf_url = serializers.SerializerMethodField()

    class Meta(BookListSerializer.Meta):
        fields = BookListSerializer.Meta.fields + (
            'description', 'what_you_will_learn',
            'full_text', 'full_book_pdf_url', 'sections',
        )

    def get_full_text(self, obj):
        request = self.context.get('request')
        if obj.is_premium and not _user_has_premium_access(request):
            return None
        return obj.full_text

    def get_full_book_pdf_url(self, obj):
        request = self.context.get('request')
        if obj.is_premium and not _user_has_premium_access(request):
            return None
        if obj.full_book_pdf:
            if request:
                return request.build_absolute_uri(obj.full_book_pdf.url)
            return obj.full_book_pdf.url
        return None
