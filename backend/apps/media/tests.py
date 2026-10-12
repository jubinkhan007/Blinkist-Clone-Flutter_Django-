from datetime import date, timedelta
from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import User
from apps.catalog.models import Author, Book, Category
from apps.summaries.models import SummarySection
from .models import DailyAudioDigest, DailyAudioDigestItem, UserDailyDigestProgress
from .services import get_or_create_daily_digest


class DailyAudioDigestTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='morninglistener@example.com',
            username='morninglistener',
            password='securepassword123',
        )
        self.author = Author.objects.create(name='Test Author')
        self.category = Category.objects.create(name='Productivity', slug='productivity')

        self.books = []
        for i in range(3):
            book = Book.objects.create(
                title=f'Digest Book {i + 1}',
                subtitle=f'Subtitle {i + 1}',
                slug=f'digest-book-{i + 1}',
                author=self.author,
                description=f'Description for Book {i + 1}',
            )
            book.categories.add(self.category)
            # Create a section with audio
            audio_content = SimpleUploadedFile(f'audio_{i + 1}.mp3', b'dummy audio bytes', content_type='audio/mpeg')
            SummarySection.objects.create(
                book=book,
                slug=f'section-{i + 1}',
                order=1,
                title=f'Key Insight {i + 1}',
                content='Test content',
                audio_file=audio_content,
                duration_seconds=180,
            )
            self.books.append(book)

    def test_get_or_create_daily_digest_compilation(self):
        today = date(2026, 10, 12)
        digest = get_or_create_daily_digest(user=self.user, target_date=today)
        self.assertIsNotNone(digest)
        self.assertEqual(digest.date, today)
        self.assertEqual(digest.items.count(), 3)
        self.assertEqual(digest.total_duration_seconds, 180 * 3)

        # Re-fetching returns identical digest
        second_call = get_or_create_daily_digest(user=self.user, target_date=today)
        self.assertEqual(digest.id, second_call.id)

    def test_daily_digest_api_get_anonymous_and_authenticated(self):
        url = reverse('daily-audio-digest')

        # Anonymous request
        anon_response = self.client.get(url)
        self.assertEqual(anon_response.status_code, status.HTTP_200_OK)
        self.assertIn('items', anon_response.data)
        self.assertEqual(len(anon_response.data['items']), 3)
        self.assertIsNone(anon_response.data['user_progress'])

        # Authenticated request
        self.client.force_authenticate(user=self.user)
        auth_response = self.client.get(url)
        self.assertEqual(auth_response.status_code, status.HTTP_200_OK)
        first_item = auth_response.data['items'][0]
        self.assertIn('book_title', first_item)
        self.assertIn('audio_url', first_item)
        self.assertIn('insight_prompt', first_item)

    def test_daily_digest_progress_updates_and_completion(self):
        digest = get_or_create_daily_digest(user=self.user, target_date=timezone.localdate())
        self.client.force_authenticate(user=self.user)

        progress_url = reverse('daily-audio-digest-progress')

        # Step 1: Update progress (listening to track 2, 45 seconds in)
        res1 = self.client.post(progress_url, {
            'digest_id': digest.id,
            'current_item_index': 1,
            'current_position_seconds': 45,
            'is_completed': False,
        })
        self.assertEqual(res1.status_code, status.HTTP_200_OK)
        self.assertFalse(res1.data['progress']['is_completed'])
        self.assertEqual(res1.data['progress']['current_item_index'], 1)

        # Step 2: Complete the digest
        self.assertEqual(self.user.current_streak, 0)
        res2 = self.client.post(progress_url, {
            'digest_id': digest.id,
            'current_item_index': 2,
            'current_position_seconds': 180,
            'is_completed': True,
        })
        self.assertEqual(res2.status_code, status.HTTP_200_OK)
        self.assertTrue(res2.data['progress']['is_completed'])

        # Refresh user from DB to verify streak advancement
        self.user.refresh_from_db()
        self.assertEqual(self.user.current_streak, 1)
