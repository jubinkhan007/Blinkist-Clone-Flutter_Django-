from rest_framework import serializers
from apps.catalog.models import Author, Book, Category, Collection, CollectionItem, UserAudioQueueItem
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
    has_audio = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = ('id', 'title', 'subtitle', 'slug', 'author', 'categories', 
                  'cover_image_url', 'estimated_read_time_minutes', 'is_premium', 
                  'is_daily_free', 'is_saved', 'rating', 'rating_count', 'has_audio')

    def get_has_audio(self, obj):
        if hasattr(obj, 'has_audio_cached'):
            return bool(obj.has_audio_cached)
        return obj.sections.filter(audio_file__isnull=False).exclude(audio_file='').exists()

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


def _is_book_completed_for_user(user, book) -> bool:
    if user is None or not getattr(user, 'is_authenticated', False):
        return False
    from apps.progress.models import UserBookProgress, UserAudioProgress, UserSummaryProgress
    if UserBookProgress.objects.filter(user=user, book=book, is_completed=True).exists():
        return True
    if UserAudioProgress.objects.filter(user=user, book=book, is_finished=True).exists():
        return True
    summary_prog = UserSummaryProgress.objects.filter(user=user, book=book).first()
    if summary_prog:
        total_sec = book.sections.count()
        if total_sec > 0 and summary_prog.completed_sections_count >= total_sec:
            return True
        elif total_sec == 0 and summary_prog.completed_sections_count > 0:
            return True
    return False


class CollectionItemSerializer(serializers.ModelSerializer):
    book = BookListSerializer(read_only=True)
    is_completed = serializers.SerializerMethodField()

    class Meta:
        model = CollectionItem
        fields = ('id', 'order', 'note', 'book', 'is_completed')

    def get_is_completed(self, obj):
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        return _is_book_completed_for_user(user, obj.book)



class CollectionListSerializer(serializers.ModelSerializer):
    banner_image_url = serializers.SerializerMethodField()
    books_count = serializers.IntegerField(read_only=True)
    total_estimated_minutes = serializers.IntegerField(read_only=True)
    preview_books = serializers.SerializerMethodField()

    class Meta:
        model = Collection
        fields = (
            'id', 'title', 'subtitle', 'slug', 'description',
            'banner_image_url', 'icon', 'color_hex', 'target_duration_days',
            'is_featured', 'books_count', 'total_estimated_minutes', 'preview_books'
        )

    def get_banner_image_url(self, obj):
        if obj.banner_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.banner_image.url)
            return obj.banner_image.url
        return None

    def get_preview_books(self, obj):
        request = self.context.get('request')
        covers = []
        for item in obj.items.select_related('book')[:4]:
            url = None
            if item.book.cover_image:
                url = request.build_absolute_uri(item.book.cover_image.url) if request else item.book.cover_image.url
            covers.append({
                'id': item.book.id,
                'title': item.book.title,
                'cover_image_url': url,
            })
        return covers


class CollectionDetailSerializer(serializers.ModelSerializer):
    banner_image_url = serializers.SerializerMethodField()
    books_count = serializers.IntegerField(read_only=True)
    total_estimated_minutes = serializers.IntegerField(read_only=True)
    items = CollectionItemSerializer(many=True, read_only=True)
    completed_books_count = serializers.SerializerMethodField()
    progress_percent = serializers.SerializerMethodField()

    class Meta:
        model = Collection
        fields = (
            'id', 'title', 'subtitle', 'slug', 'description',
            'banner_image_url', 'icon', 'color_hex', 'target_duration_days',
            'books_count', 'total_estimated_minutes', 'completed_books_count',
            'progress_percent', 'items'
        )

    def get_banner_image_url(self, obj):
        if obj.banner_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.banner_image.url)
            return obj.banner_image.url
        return None

    def get_completed_books_count(self, obj):
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        if user is None or not getattr(user, 'is_authenticated', False):
            return 0
        return sum(1 for item in obj.items.all() if _is_book_completed_for_user(user, item.book))


    def get_progress_percent(self, obj):
        total = obj.items.count()
        if total == 0:
            return 0.0
        completed = self.get_completed_books_count(obj)
        return round(min(100.0, (completed / total) * 100.0), 1)


class UserAudioQueueItemSerializer(serializers.ModelSerializer):
    book = BookListSerializer(read_only=True)

    class Meta:
        model = UserAudioQueueItem
        fields = ('id', 'book', 'order', 'added_at')

