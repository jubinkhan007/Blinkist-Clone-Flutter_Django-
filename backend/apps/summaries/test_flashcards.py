from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import User
from apps.catalog.models import Author, Book, Category
from apps.progress.models import UserBadge
from apps.summaries.models import BookFlashcard, SummarySection, UserFlashcardReview
from apps.summaries.flashcard_service import generate_or_get_flashcards, get_daily_review_deck


class FlashcardsApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='learner',
            email='learner@example.com',
            password='testpassword123',
        )
        self.other_user = User.objects.create_user(
            username='other',
            email='other@example.com',
            password='testpassword123',
        )

        author = Author.objects.create(name='James Clear')
        category = Category.objects.create(name='Productivity', slug='productivity')

        self.book = Book.objects.create(
            title='Atomic Habits',
            subtitle='Tiny Changes, Remarkable Results',
            slug='atomic-habits',
            author=author,
            description='An easy and proven way to build good habits and break bad ones.',
            what_you_will_learn='• How to make habits obvious\n• How to make habits attractive\n• How to make habits easy\n• How to make habits satisfying',
            estimated_read_time_minutes=15,
        )
        self.book.categories.add(category)

        self.section1 = SummarySection.objects.create(
            book=self.book,
            slug='the-fundamentals',
            order=1,
            title='The Fundamentals: Why Tiny Changes Make a Big Difference',
            content='Habits are the compound interest of self-improvement. Getting 1 percent better every day counts for a lot in the long run.',
            plain_text='Habits are the compound interest of self-improvement. Getting 1 percent better every day counts for a lot in the long run.',
            duration_seconds=180,
            estimated_read_minutes=3,
        )
        self.section2 = SummarySection.objects.create(
            book=self.book,
            slug='the-first-law',
            order=2,
            title='The 1st Law: Make It Obvious',
            content='The most common cues are time and location. Implementation intentions design clear cues.',
            plain_text='The most common cues are time and location. Implementation intentions design clear cues.',
            duration_seconds=180,
            estimated_read_minutes=3,
        )

    def test_generate_or_get_flashcards_service(self):
        cards = generate_or_get_flashcards(self.book)
        self.assertGreaterEqual(len(cards), 2)
        
        for c in cards:
            self.assertEqual(c.book, self.book)
            self.assertTrue(len(c.front_prompt) > 0)
            self.assertTrue(len(c.back_answer) > 0)
            self.assertTrue(isinstance(c.quiz_options, list))
            self.assertEqual(len(c.quiz_options), 4)
            # Ensure exactly one option is marked correct
            correct_opts = [o for o in c.quiz_options if o.get('is_correct')]
            self.assertEqual(len(correct_opts), 1)

    def test_get_flashcard_deck_endpoint(self):
        url = reverse('book_flashcard_list', kwargs={'book_slug': self.book.slug})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['book_slug'], 'atomic-habits')
        self.assertGreaterEqual(response.data['total_cards'], 2)
        self.assertEqual(response.data['mastered_count'], 0)
        self.assertEqual(len(response.data['cards']), response.data['total_cards'])

    def test_review_card_requires_authentication(self):
        cards = generate_or_get_flashcards(self.book)
        card = cards[0]
        url = reverse('flashcard_review', kwargs={'pk': card.id})
        response = self.client.post(url, {'status': 'mastered'})
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_review_card_as_mastered_and_awards_badge(self):
        self.client.force_authenticate(user=self.user)
        cards = generate_or_get_flashcards(self.book)
        card = cards[0]

        url = reverse('flashcard_review', kwargs={'pk': card.id})
        response = self.client.post(url, {'status': 'mastered'})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'mastered')
        self.assertEqual(response.data['times_reviewed'], 1)
        self.assertIsNotNone(response.data['next_review_at'])

        # Check DB record
        review = UserFlashcardReview.objects.get(user=self.user, flashcard=card)
        self.assertEqual(review.status, 'mastered')

        # Check badge unlocked
        badge = UserBadge.objects.filter(user=self.user, badge_key='first_recall').first()
        self.assertIsNotNone(badge)

    def test_daily_review_deck_endpoint(self):
        self.client.force_authenticate(user=self.user)
        url = reverse('daily_review_deck')
        response = self.client.get(url, {'limit': 3})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('date', response.data)
        self.assertIn('cards', response.data)
        self.assertGreaterEqual(len(response.data['cards']), 1)
        self.assertLessEqual(len(response.data['cards']), 3)
