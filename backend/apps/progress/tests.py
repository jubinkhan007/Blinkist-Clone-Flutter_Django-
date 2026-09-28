from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase

from apps.catalog.models import Author, Book, Category

User = get_user_model()


class FullBookProgressTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='progress@example.com',
            username='progress',
            password='secret123',
        )
        self.client.force_authenticate(self.user)
        author = Author.objects.create(name='Author')
        category = Category.objects.create(name='Category', slug='category')
        self.book = Book.objects.create(
            title='Full Book',
            subtitle='',
            slug='full-book',
            author=author,
            description='desc',
            what_you_will_learn='learn',
            full_text='full text',
        )
        self.book.categories.add(category)

    def test_get_full_book_progress_creates_default_progress(self):
        response = self.client.get(
            reverse('full_book_progress', kwargs={'book_id': self.book.id})
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['book'], self.book.id)
        self.assertEqual(response.data['current_page'], 0)
        self.assertEqual(response.data['current_offset'], 0.0)

    def test_post_full_book_progress_updates_page_and_offset(self):
        response = self.client.post(
            reverse('full_book_progress', kwargs={'book_id': self.book.id}),
            {'current_page': 12, 'current_offset': 0.42},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['current_page'], 12)
        self.assertEqual(response.data['current_offset'], 0.42)


class UserReadingStatsTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='gamify@example.com',
            username='gamifyuser',
            password='secret123',
        )
        self.client.force_authenticate(self.user)
        author = Author.objects.create(name='Habit Author')
        category = Category.objects.create(name='Productivity', slug='productivity')
        self.book = Book.objects.create(
            title='Atomic Habits',
            slug='atomic-habits',
            author=author,
            description='desc',
        )
        self.book.categories.add(category)
        from apps.summaries.models import SummarySection
        self.section1 = SummarySection.objects.create(
            book=self.book,
            slug='section-1',
            title='Section 1',
            order=1,
            content='Content 1',
        )
        self.section2 = SummarySection.objects.create(
            book=self.book,
            slug='section-2',
            title='Section 2',
            order=2,
            content='Content 2',
        )

    def test_record_activity_endpoint(self):
        response = self.client.post(reverse('record_activity'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'success')
        self.assertEqual(response.data['current_streak'], 1)
        self.assertTrue(response.data['is_active_today'])

    def test_mark_section_read_triggers_streak(self):
        response = self.client.post(
            reverse('mark_section_read', kwargs={'book_id': self.book.id, 'section_id': self.section1.id})
        )
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.current_streak, 1)
        self.assertIsNotNone(self.user.last_active_date)

    def test_reading_stats_endpoint(self):
        # Mark one section read
        self.client.post(
            reverse('mark_section_read', kwargs={'book_id': self.book.id, 'section_id': self.section1.id})
        )
        # Save audio progress (120 seconds = 2 minutes)
        self.client.post(
            reverse('audio_progress', kwargs={'book_id': self.book.id}),
            {'section_id': self.section1.id, 'position_seconds': 120.0, 'is_finished': True},
            format='json',
        )

        response = self.client.get(reverse('reading_stats'))
        self.assertEqual(response.status_code, 200)
        data = response.data
        self.assertEqual(data['current_streak'], 1)
        self.assertEqual(data['total_sections_read'], 1)
        self.assertEqual(data['total_audio_minutes'], 2)
        self.assertTrue(data['is_active_today'])
        self.assertEqual(len(data['weekly_activity']), 7)
        self.assertTrue(any(data['weekly_activity']))

