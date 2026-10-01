from io import StringIO
from unittest.mock import MagicMock, patch

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


class BookFilterAndSortApiTests(APITestCase):
    def setUp(self):
        self.author = Author.objects.create(name='Test Author')
        self.cat_prod = Category.objects.create(name='Productivity', slug='productivity')
        self.cat_lead = Category.objects.create(name='Leadership', slug='leadership')
        self.cat_tech = Category.objects.create(name='Technology', slug='technology')

        # Book 1: Short duration (8m), High rating (4.9), Audio available
        self.book1 = Book.objects.create(
            title='Quick Lead',
            slug='quick-lead',
            author=self.author,
            estimated_read_time_minutes=8,
            rating=4.9,
            rating_count=300,
        )
        self.book1.categories.add(self.cat_lead)
        SummarySection.objects.create(
            book=self.book1,
            slug='sec-1',
            order=1,
            title='Intro',
            audio_file='audio/sample.mp3',
        )

        # Book 2: Medium duration (15m), Medium rating (4.7), No audio
        self.book2 = Book.objects.create(
            title='Habits Master',
            slug='habits-master',
            author=self.author,
            estimated_read_time_minutes=15,
            rating=4.7,
            rating_count=150,
        )
        self.book2.categories.add(self.cat_prod)

        # Book 3: Long duration (25m), Lower rating (4.5), Audio available
        self.book3 = Book.objects.create(
            title='Tech Architecture',
            slug='tech-architecture',
            author=self.author,
            estimated_read_time_minutes=25,
            rating=4.5,
            rating_count=80,
        )
        self.book3.categories.add(self.cat_tech)
        SummarySection.objects.create(
            book=self.book3,
            slug='sec-tech-1',
            order=1,
            title='Architecture Key',
            audio_file='audio/tech.mp3',
        )

    def test_filter_by_category(self):
        url = reverse('book_list')
        response = self.client.get(url, {'categories__slug': 'leadership'})
        self.assertEqual(response.status_code, 200)
        slugs = [b['slug'] for b in response.data['results']]
        self.assertIn('quick-lead', slugs)
        self.assertNotIn('habits-master', slugs)
        self.assertNotIn('tech-architecture', slugs)

    def test_filter_by_format_audio(self):
        url = reverse('book_list')
        response = self.client.get(url, {'book_format': 'audio'})
        self.assertEqual(response.status_code, 200)
        slugs = [b['slug'] for b in response.data['results']]
        self.assertIn('quick-lead', slugs)
        self.assertIn('tech-architecture', slugs)
        self.assertNotIn('habits-master', slugs)

        # Also test with has_audio=true
        resp_audio = self.client.get(url, {'has_audio': 'true'})
        self.assertEqual(resp_audio.status_code, 200)
        slugs_audio = [b['slug'] for b in resp_audio.data['results']]
        self.assertEqual(slugs_audio, slugs)

    def test_filter_by_duration(self):
        url = reverse('book_list')

        # Short: < 10m
        resp_short = self.client.get(url, {'duration': 'short'})
        slugs_short = [b['slug'] for b in resp_short.data['results']]
        self.assertIn('quick-lead', slugs_short)
        self.assertNotIn('habits-master', slugs_short)

        # Medium: 10-20m
        resp_med = self.client.get(url, {'duration': 'medium'})
        slugs_med = [b['slug'] for b in resp_med.data['results']]
        self.assertIn('habits-master', slugs_med)
        self.assertNotIn('quick-lead', slugs_med)

        # Long: > 20m
        resp_long = self.client.get(url, {'duration': 'long'})
        slugs_long = [b['slug'] for b in resp_long.data['results']]
        self.assertIn('tech-architecture', slugs_long)
        self.assertNotIn('quick-lead', slugs_long)

    def test_sort_by_highest_rated(self):
        url = reverse('book_list')
        response = self.client.get(url, {'sort_by': 'highest_rated'})
        self.assertEqual(response.status_code, 200)
        results = response.data['results']
        ratings = [float(b['rating']) for b in results]
        # Verify descending order
        self.assertEqual(ratings, sorted(ratings, reverse=True))

    def test_sort_by_popularity(self):
        # Create a user and bookmark book 2
        user = User.objects.create_user(email='fan@example.com', username='fan', password='pw')
        UserLibraryItem.objects.create(user=user, book=self.book2)

        url = reverse('book_list')
        response = self.client.get(url, {'sort_by': 'popularity'})
        self.assertEqual(response.status_code, 200)
        results = response.data['results']
        # book2 has 1 bookmark, so should appear before book1 and book3
        self.assertEqual(results[0]['slug'], 'habits-master')


class BookAskAiApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='reader@example.com',
            username='reader',
            password='password123',
        )
        self.author = Author.objects.create(name='James Clear', bio='Author and speaker.')
        self.category = Category.objects.create(name='Productivity', slug='productivity')
        self.book = Book.objects.create(
            title='Atomic Habits',
            subtitle='An Easy & Proven Way to Build Good Habits & Break Bad Ones',
            slug='atomic-habits',
            author=self.author,
            description='A practical guide on how small changes can lead to remarkable results.',
            what_you_will_learn='Build good habits.\nBreak bad habits.\nMaster the tiny behaviors that lead to remarkable results.',
            estimated_read_time_minutes=15,
        )
        self.book.categories.add(self.category)

        self.section1 = SummarySection.objects.create(
            book=self.book,
            slug='the-fundamentals',
            order=1,
            title='The Fundamentals: Why Tiny Changes Make a Big Difference',
            plain_text='Small habits compound over time like interest on money. Getting 1% better every day counts for a lot.',
            content='<p>Small habits compound over time like interest on money.</p>',
            duration_seconds=180,
            estimated_read_minutes=3,
        )
        self.section2 = SummarySection.objects.create(
            book=self.book,
            slug='make-it-easy',
            order=2,
            title='The 3rd Law: Make It Easy',
            plain_text='Reduce the friction of good behaviors using the Two-Minute Rule. When you start a habit, it should take less than two minutes.',
            content='<p>Reduce the friction of good behaviors using the Two-Minute Rule.</p>',
            duration_seconds=240,
            estimated_read_minutes=4,
        )

    def test_ask_ai_with_valid_question(self):
        url = reverse('book_ask_ai', kwargs={'slug': self.book.slug})
        payload = {
            'question': 'What is the main premise of Atomic Habits?',
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertIn('answer', response.data)
        self.assertIn('Atomic Habits', response.data['book_title'])
        self.assertIn('suggested_followups', response.data)
        self.assertIsInstance(response.data['suggested_followups'], list)
        self.assertGreater(len(response.data['suggested_followups']), 0)

    def test_ask_ai_with_section_context(self):
        url = reverse('book_ask_ai', kwargs={'slug': self.book.slug})
        payload = {
            'question': 'How does the two-minute rule work?',
            'section_slug': 'make-it-easy',
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['section_title'], 'The 3rd Law: Make It Easy')
        self.assertIn('answer', response.data)

    def test_ask_ai_action_steps_prompt(self):
        url = reverse('book_ask_ai', kwargs={'slug': self.book.slug})
        payload = {
            'question': 'What actionable steps can I implement tomorrow?',
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertIn('1.', response.data['answer'])

    def test_ask_ai_real_world_example_prompt(self):
        url = reverse('book_ask_ai', kwargs={'slug': self.book.slug})
        payload = {
            'question': 'Give me a real-world example of this in action',
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertTrue(len(response.data['answer']) > 50)

    def test_ask_ai_missing_question(self):
        url = reverse('book_ask_ai', kwargs={'slug': self.book.slug})
        response = self.client.post(url, {'question': '   '}, format='json')
        self.assertEqual(response.status_code, 400)
        self.assertIn('error', response.data)

    def test_ask_ai_nonexistent_book(self):
        url = reverse('book_ask_ai', kwargs={'slug': 'non-existent-book'})
        response = self.client.post(url, {'question': 'Hello?'}, format='json')
        self.assertEqual(response.status_code, 404)

    def test_ask_ai_with_history(self):
        url = reverse('book_ask_ai', kwargs={'slug': self.book.slug})
        payload = {
            'question': 'Can you expand on that?',
            'history': [
                {'role': 'user', 'content': 'What is compounding?'},
                {'role': 'assistant', 'content': 'Compounding is small gains building over time.'},
            ],
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertIn('answer', response.data)

    @patch('apps.catalog.ai_service.configure_gemini', return_value=True)
    @patch('google.generativeai.GenerativeModel')
    def test_ask_ai_with_gemini_mocked(self, mock_model_class, mock_configure):
        mock_instance = MagicMock()
        mock_instance.generate_content.return_value = MagicMock(
            text="In Atomic Habits, James Clear proves that 1% improvements compound into dramatic results over time.\n\nFOLLOWUP: How do I overcome habit friction?\nFOLLOWUP: What is the 2-minute rule?\nFOLLOWUP: Can you give a practical example?"
        )
        mock_model_class.return_value = mock_instance

        from apps.catalog.ai_service import ask_book_ai
        result = ask_book_ai(
            book=self.book,
            question="Tell me about compounding",
            force_gemini=True,
        )
        self.assertIn("1% improvements compound", result['answer'])
        self.assertEqual(len(result['suggested_followups']), 3)
        self.assertEqual(result['suggested_followups'][1], "What is the 2-minute rule?")


