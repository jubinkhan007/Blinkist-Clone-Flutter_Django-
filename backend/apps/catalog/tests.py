from io import StringIO

from django.core.management import call_command
from django.urls import reverse
from rest_framework.test import APITestCase

from apps.accounts.models import User
from apps.catalog.models import Author, Book, Category, UserLibraryItem, Collection, CollectionItem
from apps.summaries.models import SummarySection


class LibraryApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='library@example.com',
            username='library',
            password='pass12345',
        )
        self.author = Author.objects.create(name='Author')
        self.category = Category.objects.create(name='Business', slug='business')
        self.book = Book.objects.create(
            title='The Goal',
            subtitle='',
            slug='the-goal',
            author=self.author,
            description='desc',
            what_you_will_learn='learn',
        )
        self.book.categories.add(self.category)

    def test_toggle_library_item(self):
        self.client.force_authenticate(self.user)

        save_response = self.client.post(
            reverse('user_library_toggle', kwargs={'book_slug': self.book.slug})
        )
        self.assertEqual(save_response.status_code, 200)
        self.assertEqual(save_response.data, {'saved': True})
        self.assertTrue(
            UserLibraryItem.objects.filter(user=self.user, book=self.book).exists()
        )

        unsave_response = self.client.post(
            reverse('user_library_toggle', kwargs={'book_slug': self.book.slug})
        )
        self.assertEqual(unsave_response.status_code, 200)
        self.assertEqual(unsave_response.data, {'saved': False})

    def test_library_list_and_catalog_serializer_include_is_saved(self):
        self.client.force_authenticate(self.user)
        UserLibraryItem.objects.create(user=self.user, book=self.book)

        library_response = self.client.get(reverse('user_library'))
        self.assertEqual(library_response.status_code, 200)
        self.assertEqual(len(library_response.data), 1)
        self.assertTrue(library_response.data[0]['is_saved'])

        catalog_response = self.client.get(reverse('book_list'))
        self.assertEqual(catalog_response.status_code, 200)
        self.assertTrue(catalog_response.data['results'][0]['is_saved'])


class DemoDataCommandTests(APITestCase):
    def test_seed_demo_data_is_idempotent_and_clear_removes_demo_user(self):
        output = StringIO()

        call_command('seed_demo_data', stdout=output)
        first_book_count = Book.objects.count()
        self.assertTrue(User.objects.filter(email='demo@blinkist.com').exists())
        self.assertGreaterEqual(first_book_count, 10)

        call_command('seed_demo_data', stdout=output)
        self.assertEqual(Book.objects.count(), first_book_count)

        call_command('clear_demo_data', stdout=output)
        self.assertFalse(User.objects.filter(email='demo@blinkist.com').exists())


class DailyPickTests(APITestCase):
    def setUp(self):
        self.author = Author.objects.create(name='Author')
        self.category = Category.objects.create(name='Tech', slug='tech')
        self.premium_book = Book.objects.create(
            title='Premium Title',
            subtitle='',
            slug='premium-title',
            author=self.author,
            description='premium desc',
            what_you_will_learn='learn',
            is_premium=True,
        )
        self.section = SummarySection.objects.create(
            book=self.premium_book,
            slug='ch-1',
            order=1,
            title='Chapter 1',
            content='Super secret insight',
            plain_text='Super secret insight',
        )

    def test_daily_pick_rotates_and_unlocks_summary_for_anonymous_user(self):
        from apps.catalog.daily_pick import get_or_create_daily_pick

        # Before becoming daily pick, anonymous user cannot access content of premium book
        detail_url = reverse('book_detail', kwargs={'slug': self.premium_book.slug})
        resp = self.client.get(detail_url)
        self.assertEqual(resp.status_code, 200)
        self.assertFalse(resp.data['is_daily_free'])
        self.assertIsNone(resp.data['sections'][0]['content'])

        # Now assign as daily pick
        pick = get_or_create_daily_pick()
        self.assertIsNotNone(pick)

        # Re-fetch: should now show is_daily_free=True and unlock content
        resp = self.client.get(detail_url)
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.data['is_daily_free'])
        self.assertEqual(resp.data['sections'][0]['content'], 'Super secret insight')

    def test_extract_cover_from_pdf(self):
        import fitz
        import os
        import tempfile
        from apps.catalog.tasks import extract_cover_from_pdf

        doc = fitz.open()
        page = doc.new_page()
        page.draw_rect(fitz.Rect(10, 10, 100, 100), color=(1, 0, 0), fill=(0, 1, 0))
        with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as f:
            pdf_path = f.name
            doc.save(pdf_path)
            doc.close()

        try:
            cover_png = extract_cover_from_pdf(pdf_path)
            self.assertIsNotNone(cover_png)
            self.assertTrue(cover_png.startswith(b'\x89PNG'))
        finally:
            if os.path.exists(pdf_path):
                os.remove(pdf_path)


class CollectionApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='col_reader@example.com',
            username='col_reader',
            password='pass12345',
        )
        self.author = Author.objects.create(name='Productivity Guru')
        self.book1 = Book.objects.create(
            title='Deep Work Mastery',
            slug='deep-work-mastery',
            author=self.author,
            estimated_read_time_minutes=15,
        )
        self.book2 = Book.objects.create(
            title='Atomic Habits Essentials',
            slug='atomic-habits-essentials',
            author=self.author,
            estimated_read_time_minutes=12,
        )
        self.collection = Collection.objects.create(
            title='7 Days to Peak Productivity',
            subtitle='Transform your daily output',
            slug='7-days-peak-productivity',
            description='A curated curriculum to master focus.',
            target_duration_days=7,
            is_featured=True,
            order=1,
        )
        self.item1 = CollectionItem.objects.create(
            collection=self.collection,
            book=self.book1,
            order=1,
            note='Day 1: Eliminate distraction',
        )
        self.item2 = CollectionItem.objects.create(
            collection=self.collection,
            book=self.book2,
            order=2,
            note='Day 2: Build unbreakable habits',
        )

    def test_collection_list_api(self):
        url = reverse('collection_list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(len(response.data), 1)
        col = response.data[0]
        self.assertEqual(col['title'], '7 Days to Peak Productivity')
        self.assertEqual(col['books_count'], 2)
        self.assertEqual(col['total_estimated_minutes'], 27)

    def test_collection_detail_and_progress_tracking(self):
        url = reverse('collection_detail', kwargs={'slug': self.collection.slug})
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['title'], '7 Days to Peak Productivity')
        self.assertEqual(len(response.data['items']), 2)
        self.assertEqual(response.data['completed_books_count'], 0)
        self.assertEqual(response.data['progress_percent'], 0.0)

        # Authenticate and mark book 1 as finished
        self.client.force_authenticate(self.user)
        from apps.progress.models import UserBookProgress
        UserBookProgress.objects.create(
            user=self.user,
            book=self.book1,
            is_completed=True,
        )


        auth_response = self.client.get(url)
        self.assertEqual(auth_response.status_code, 200)
        self.assertEqual(auth_response.data['completed_books_count'], 1)
        self.assertEqual(auth_response.data['progress_percent'], 50.0)
        self.assertTrue(auth_response.data['items'][0]['is_completed'])
        self.assertFalse(auth_response.data['items'][1]['is_completed'])

    def test_home_feed_includes_collections(self):
        home_url = reverse('home_merchandising')
        response = self.client.get(home_url)
        self.assertEqual(response.status_code, 200)
        self.assertIn('collections', response.data)
        self.assertGreaterEqual(len(response.data['collections']), 1)

