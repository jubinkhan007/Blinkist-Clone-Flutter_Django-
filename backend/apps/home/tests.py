from datetime import timedelta

from django.core.cache import cache
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APITestCase

from apps.accounts.models import User
from apps.catalog.models import Author, Book, Category, DailyPick
from unittest.mock import patch
from apps.progress.models import UserAudioProgress, UserSummaryProgress
from apps.summaries.models import SummarySection


class HomeFeedTests(APITestCase):
    def setUp(self):
        cache.clear()
        self.embedding_patcher = patch('apps.home.services.get_book_embedding', return_value=None)
        self.embedding_patcher.start()
        self.addCleanup(self.embedding_patcher.stop)
        self.user = User.objects.create_user(
            email='reader@example.com',
            username='reader',
            password='pass12345',
        )
        self.author = Author.objects.create(name='Author')
        self.category = Category.objects.create(name='Productivity', slug='productivity')

    def _book(self, slug, title):
        book = Book.objects.create(
            title=title,
            subtitle='',
            slug=slug,
            author=self.author,
            description='desc',
            what_you_will_learn='learn',
            estimated_read_time_minutes=15,
        )
        book.categories.add(self.category)
        return book

    def _section(self, book, order, slug):
        return SummarySection.objects.create(
            book=book,
            slug=slug,
            order=order,
            title=f'Section {order}',
            content='content',
            plain_text='content',
            estimated_read_minutes=2,
        )

    def test_anonymous_users_get_empty_continue_reading(self):
        response = self.client.get(reverse('home_merchandising'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['continue_reading'], [])

    def test_authenticated_users_receive_continue_reading_with_latest_mode(self):
        self.client.force_authenticate(self.user)
        summary_book = self._book('deep-work', 'Deep Work')
        listen_book = self._book('atomic-habits', 'Atomic Habits')

        for index in range(1, 5):
            self._section(summary_book, index, f'summary-{index}')
            self._section(listen_book, index, f'audio-{index}')

        summary_section = summary_book.sections.get(order=2)
        audio_section = listen_book.sections.get(order=3)

        UserSummaryProgress.objects.create(
            user=self.user,
            book=summary_book,
            current_section=summary_section,
            completed_sections_count=2,
        )
        UserSummaryProgress.objects.filter(user=self.user, book=summary_book).update(
            last_read_at=timezone.now() - timedelta(hours=2)
        )

        UserAudioProgress.objects.create(
            user=self.user,
            book=listen_book,
            current_section=audio_section,
            current_position_seconds=42,
        )
        UserAudioProgress.objects.filter(user=self.user, book=listen_book).update(
            last_listened_at=timezone.now() - timedelta(hours=1)
        )

        response = self.client.get(reverse('home_merchandising'))

        self.assertEqual(response.status_code, 200)
        continue_reading = response.data['continue_reading']
        self.assertEqual(len(continue_reading), 2)
        self.assertEqual(continue_reading[0]['slug'], 'atomic-habits')
        self.assertEqual(continue_reading[0]['last_mode'], 'listen')
        self.assertEqual(continue_reading[1]['slug'], 'deep-work')
        self.assertEqual(continue_reading[1]['percent_complete'], 50.0)

    def test_recommended_books_prioritize_preferred_categories(self):
        self.client.force_authenticate(self.user)
        engaged_book = self._book('focus', 'Focus')
        other_category = Category.objects.create(name='Health', slug='health')
        fallback_book = Book.objects.create(
            title='Sleep Better',
            subtitle='',
            slug='sleep-better',
            author=self.author,
            description='desc',
            what_you_will_learn='learn',
            estimated_read_time_minutes=15,
        )
        fallback_book.categories.add(other_category)
        SummarySection.objects.create(
            book=engaged_book,
            slug='intro',
            order=1,
            title='Intro',
            content='content',
            plain_text='content',
        )
        UserSummaryProgress.objects.create(
            user=self.user,
            book=engaged_book,
            completed_sections_count=1,
        )

        response = self.client.get(reverse('home_merchandising'))

        self.assertEqual(response.status_code, 200)
        recommended_slugs = [item['slug'] for item in response.data['recommended']]
        self.assertIn('focus', recommended_slugs)

    def test_home_feed_includes_daily_pick(self):
        book = self._book('daily-pick-slug', 'Daily Pick Title')
        book.is_premium = True
        book.save()
        DailyPick.objects.create(book=book, date=timezone.now().date())

        response = self.client.get(reverse('home_merchandising'))
        self.assertEqual(response.status_code, 200)
        self.assertIsNotNone(response.data['daily_pick'])
        self.assertEqual(response.data['daily_pick']['slug'], 'daily-pick-slug')
        self.assertTrue(response.data['daily_pick']['is_daily_free'])
