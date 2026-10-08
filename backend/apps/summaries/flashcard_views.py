from django.shortcuts import get_object_or_404
from django.utils import timezone
from datetime import timedelta
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.models import Book
from apps.progress.badges import evaluate_and_award_badges
from .models import BookFlashcard, UserFlashcardReview
from .flashcard_service import generate_or_get_flashcards, get_daily_review_deck
from .flashcard_serializers import (
    BookFlashcardSerializer,
    FlashcardReviewCreateSerializer,
    FlashcardDeckResponseSerializer,
)


class BookFlashcardListView(APIView):
    """
    GET: Returns the flashcard deck for the specified book.
    If flashcards don't exist yet, they are automatically generated and saved.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, book_slug):
        book = get_object_or_404(
            Book.objects.prefetch_related('sections', 'author'),
            slug=book_slug,
        )
        force_regen = request.query_params.get('force_regenerate', '').lower() in ['true', '1']
        
        cards = generate_or_get_flashcards(book, force_regenerate=force_regen)
        serializer = BookFlashcardSerializer(cards, many=True, context={'request': request})

        user = request.user
        mastered_count = 0
        if user and user.is_authenticated:
            mastered_count = UserFlashcardReview.objects.filter(
                user=user,
                flashcard__book=book,
                status='mastered',
            ).count()

        cover_url = None
        if book.cover_image:
            cover_url = request.build_absolute_uri(book.cover_image.url)

        data = {
            'book_slug': book.slug,
            'book_title': book.title,
            'book_author': book.author.name,
            'cover_image_url': cover_url,
            'total_cards': len(cards),
            'mastered_count': mastered_count,
            'cards': serializer.data,
        }
        return Response(data, status=status.HTTP_200_OK)


class FlashcardReviewView(APIView):
    """
    POST: Records or updates the user's review outcome for a flashcard.
    status: 'mastered' | 'review_later'
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        flashcard = get_object_or_404(BookFlashcard.objects.select_related('book'), pk=pk)
        serializer = FlashcardReviewCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        new_status = serializer.validated_data['status']
        now = timezone.now()

        # Spaced repetition scheduling
        # 'mastered' schedules review 3 days out; 'review_later' schedules review in 4 hours
        next_interval = timedelta(days=3) if new_status == 'mastered' else timedelta(hours=4)
        next_review_at = now + next_interval

        review, created = UserFlashcardReview.objects.get_or_create(
            user=request.user,
            flashcard=flashcard,
            defaults={
                'status': new_status,
                'times_reviewed': 1,
                'next_review_at': next_review_at,
            },
        )
        if not created:
            review.status = new_status
            review.times_reviewed += 1
            review.next_review_at = next_review_at
            review.save(update_fields=['status', 'times_reviewed', 'next_review_at', 'last_reviewed_at'])

        # Check for newly unlocked badges
        unlocked_badges = evaluate_and_award_badges(request.user)

        return Response({
            'message': 'Review saved successfully.',
            'flashcard_id': flashcard.id,
            'status': review.status,
            'times_reviewed': review.times_reviewed,
            'last_reviewed_at': review.last_reviewed_at.isoformat(),
            'next_review_at': review.next_review_at.isoformat() if review.next_review_at else None,
            'new_badges_unlocked': [b['title'] for b in unlocked_badges if b.get('is_unlocked')],
        }, status=status.HTTP_200_OK)


class DailyReviewDeckView(APIView):
    """
    GET: Returns a curated 3 to 5 card daily active recall session.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        limit = int(request.query_params.get('limit', 3))
        limit = max(1, min(limit, 10))
        user = request.user if request.user.is_authenticated else None

        cards = get_daily_review_deck(user=user, limit=limit)
        serializer = BookFlashcardSerializer(cards, many=True, context={'request': request})

        total_due = len(cards)
        mastered_today = 0
        if user:
            today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)
            mastered_today = UserFlashcardReview.objects.filter(
                user=user,
                status='mastered',
                last_reviewed_at__gte=today_start,
            ).count()

        return Response({
            'date': timezone.now().date().isoformat(),
            'total_cards': total_due,
            'mastered_today': mastered_today,
            'cards': serializer.data,
        }, status=status.HTTP_200_OK)
