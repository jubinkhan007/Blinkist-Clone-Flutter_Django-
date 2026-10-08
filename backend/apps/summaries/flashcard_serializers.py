from rest_framework import serializers
from .models import BookFlashcard, UserFlashcardReview


class BookFlashcardSerializer(serializers.ModelSerializer):
    book_id = serializers.IntegerField(source='book.id', read_only=True)
    book_slug = serializers.CharField(source='book.slug', read_only=True)
    book_title = serializers.CharField(source='book.title', read_only=True)
    book_author = serializers.CharField(source='book.author.name', read_only=True)
    cover_image_url = serializers.SerializerMethodField()
    section_id = serializers.IntegerField(source='section.id', read_only=True, allow_null=True)
    section_title = serializers.CharField(source='section.title', read_only=True, allow_null=True)
    
    is_mastered = serializers.SerializerMethodField()
    review_status = serializers.SerializerMethodField()
    times_reviewed = serializers.SerializerMethodField()
    last_reviewed_at = serializers.SerializerMethodField()

    class Meta:
        model = BookFlashcard
        fields = [
            'id',
            'book_id',
            'book_slug',
            'book_title',
            'book_author',
            'cover_image_url',
            'section_id',
            'section_title',
            'front_prompt',
            'back_answer',
            'key_quote',
            'quiz_options',
            'order',
            'is_mastered',
            'review_status',
            'times_reviewed',
            'last_reviewed_at',
        ]

    def _get_user_review(self, obj):
        request = self.context.get('request')
        if not request or not request.user or not request.user.is_authenticated:
            return None
        # Use prefetched reviews if available
        if hasattr(obj, 'prefetched_user_reviews'):
            reviews = [r for r in obj.prefetched_user_reviews if r.user_id == request.user.id]
            return reviews[0] if reviews else None
        return UserFlashcardReview.objects.filter(user=request.user, flashcard=obj).first()

    def get_cover_image_url(self, obj):
        if obj.book.cover_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.book.cover_image.url)
            return obj.book.cover_image.url
        return None

    def get_is_mastered(self, obj):
        review = self._get_user_review(obj)
        return review.status == 'mastered' if review else False

    def get_review_status(self, obj):
        review = self._get_user_review(obj)
        return review.status if review else None

    def get_times_reviewed(self, obj):
        review = self._get_user_review(obj)
        return review.times_reviewed if review else 0

    def get_last_reviewed_at(self, obj):
        review = self._get_user_review(obj)
        return review.last_reviewed_at.isoformat() if review and review.last_reviewed_at else None


class FlashcardReviewCreateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=['mastered', 'review_later'])


class FlashcardDeckResponseSerializer(serializers.Serializer):
    book_slug = serializers.CharField()
    book_title = serializers.CharField()
    book_author = serializers.CharField()
    cover_image_url = serializers.CharField(allow_null=True)
    total_cards = serializers.IntegerField()
    mastered_count = serializers.IntegerField()
    cards = BookFlashcardSerializer(many=True)
