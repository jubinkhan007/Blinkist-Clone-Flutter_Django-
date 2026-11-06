from django.urls import reverse
from rest_framework.test import APITestCase

from apps.catalog.models import Author, Book, Category
from apps.summaries.models import SummarySection


class SummariesApiTests(APITestCase):
    def setUp(self):
        author = Author.objects.create(name='Author')
        category = Category.objects.create(name='Science', slug='science')
        self.book = Book.objects.create(
            title='Brief Answers',
            subtitle='',
            slug='brief-answers',
            author=author,
            description='desc',
            what_you_will_learn='learn',
        )
        self.book.categories.add(category)
        self.section = SummarySection.objects.create(
            book=self.book,
            slug='intro',
            order=1,
            title='Intro',
            content='hello',
            plain_text='hello',
            duration_seconds=60,
            estimated_read_minutes=1,
        )

    def test_summary_list_endpoint(self):
        response = self.client.get(
            reverse('summary_section_list', kwargs={'book_slug': self.book.slug})
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['slug'], 'intro')
        self.assertEqual(response.data[0]['plainText'], 'hello')

    def test_summary_detail_endpoint(self):
        response = self.client.get(
            reverse(
                'summary_section_detail',
                kwargs={'book_slug': self.book.slug, 'slug': self.section.slug},
            )
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['content'], 'hello')

    def test_summary_list_404s_for_unknown_book(self):
        response = self.client.get(
            reverse('summary_section_list', kwargs={'book_slug': 'missing-book'})
        )
        self.assertEqual(response.status_code, 404)


class UserHighlightApiTests(APITestCase):
    def setUp(self):
        from apps.accounts.models import User
        from apps.summaries.models import UserHighlight

        self.user_a = User.objects.create_user(email='user_a@test.com', username='user_a', password='password123')
        self.user_b = User.objects.create_user(email='user_b@test.com', username='user_b', password='password123')

        author = Author.objects.create(name='James Clear')
        self.book = Book.objects.create(
            title='Atomic Habits',
            slug='atomic-habits',
            author=author,
            description='Habits guide',
        )
        self.section = SummarySection.objects.create(
            book=self.book,
            slug='cue',
            order=1,
            title='1. The Cue',
            content='Make it obvious.',
        )

    def test_create_highlight(self):
        self.client.force_authenticate(self.user_a)
        url = reverse('user_highlight_list_create')
        payload = {
            'book_slug': self.book.slug,
            'section_id': self.section.id,
            'selected_text': 'Make it obvious.',
            'note': 'Key trigger principle',
            'color': 'green',
        }
        resp = self.client.post(url, payload, format='json')
        self.assertEqual(resp.status_code, 201)
        self.assertEqual(resp.data['selected_text'], 'Make it obvious.')
        self.assertEqual(resp.data['note'], 'Key trigger principle')
        self.assertEqual(resp.data['color'], 'green')
        self.assertEqual(resp.data['book']['slug'], self.book.slug)
        self.assertEqual(resp.data['section']['title'], self.section.title)

    def test_list_and_filter_highlights_with_user_isolation(self):
        from apps.summaries.models import UserHighlight

        h1 = UserHighlight.objects.create(
            user=self.user_a,
            book=self.book,
            section=self.section,
            selected_text='User A quote',
            color='yellow',
        )
        h2 = UserHighlight.objects.create(
            user=self.user_b,
            book=self.book,
            section=self.section,
            selected_text='User B quote',
            color='pink',
        )

        url = reverse('user_highlight_list_create')

        # User A only sees User A's highlight
        self.client.force_authenticate(self.user_a)
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        results = resp.data.get('results', resp.data)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['selected_text'], 'User A quote')

        # Filter by book_slug
        resp = self.client.get(f"{url}?book_slug={self.book.slug}")
        self.assertEqual(resp.status_code, 200)
        results = resp.data.get('results', resp.data)
        self.assertEqual(len(results), 1)

        # Filter by non-matching book_slug
        resp = self.client.get(f"{url}?book_slug=non-existent")
        self.assertEqual(resp.status_code, 200)
        results = resp.data.get('results', resp.data)
        self.assertEqual(len(results), 0)

    def test_delete_highlight(self):
        from apps.summaries.models import UserHighlight

        highlight = UserHighlight.objects.create(
            user=self.user_a,
            book=self.book,
            section=self.section,
            selected_text='To be deleted',
        )

        # User B cannot delete User A's highlight
        self.client.force_authenticate(self.user_b)
        url = reverse('user_highlight_detail', kwargs={'pk': highlight.id})
        resp = self.client.delete(url)
        self.assertEqual(resp.status_code, 404)

        # User A can delete
        self.client.force_authenticate(self.user_a)
        resp = self.client.delete(url)
        self.assertEqual(resp.status_code, 204)
        self.assertFalse(UserHighlight.objects.filter(id=highlight.id).exists())


class UserAudioBookmarkApiTests(APITestCase):
    def setUp(self):
        from apps.accounts.models import User
        from apps.summaries.models import UserAudioBookmark

        self.user_a = User.objects.create_user(email='listener_a@test.com', username='listener_a', password='password123')
        self.user_b = User.objects.create_user(email='listener_b@test.com', username='listener_b', password='password123')

        author = Author.objects.create(name='James Clear')
        self.book = Book.objects.create(
            title='Atomic Habits',
            slug='atomic-habits',
            author=author,
            description='Habit guide',
        )
        self.section = SummarySection.objects.create(
            book=self.book,
            slug='make-it-obvious',
            order=1,
            title='Make It Obvious',
            duration_seconds=300,
        )

    def test_unauthenticated_cannot_access(self):
        url = reverse('audio_bookmark_list_create')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 401)

        resp = self.client.post(url, {'book_slug': self.book.slug, 'timestamp_seconds': 45})
        self.assertEqual(resp.status_code, 401)

    def test_create_audio_bookmark(self):
        self.client.force_authenticate(self.user_a)
        url = reverse('audio_bookmark_list_create')
        data = {
            'book_slug': self.book.slug,
            'section_id': self.section.id,
            'timestamp_seconds': 142,
            'title': 'Cue trigger tip',
            'note': 'Always stack this cue after morning espresso',
        }
        resp = self.client.post(url, data)
        self.assertEqual(resp.status_code, 201)
        self.assertEqual(resp.data['timestamp_seconds'], 142)
        self.assertEqual(resp.data['formatted_timestamp'], '02:22')
        self.assertEqual(resp.data['title'], 'Cue trigger tip')
        self.assertEqual(resp.data['note'], 'Always stack this cue after morning espresso')
        self.assertEqual(resp.data['book']['slug'], self.book.slug)
        self.assertEqual(resp.data['section']['id'], self.section.id)

    def test_list_and_filter_audio_bookmarks(self):
        from apps.summaries.models import UserAudioBookmark

        UserAudioBookmark.objects.create(
            user=self.user_a,
            book=self.book,
            section=self.section,
            timestamp_seconds=60,
            note='User A note',
        )
        UserAudioBookmark.objects.create(
            user=self.user_b,
            book=self.book,
            section=self.section,
            timestamp_seconds=90,
            note='User B note',
        )

        url = reverse('audio_bookmark_list_create')
        self.client.force_authenticate(self.user_a)
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        results = resp.data.get('results', resp.data)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['note'], 'User A note')

        # Filter matching slug
        resp = self.client.get(f"{url}?book_slug={self.book.slug}")
        self.assertEqual(resp.status_code, 200)
        results = resp.data.get('results', resp.data)
        self.assertEqual(len(results), 1)

        # Filter non-matching slug
        resp = self.client.get(f"{url}?book_slug=other-book")
        self.assertEqual(resp.status_code, 200)
        results = resp.data.get('results', resp.data)
        self.assertEqual(len(results), 0)

    def test_update_and_delete_audio_bookmark(self):
        from apps.summaries.models import UserAudioBookmark

        bookmark = UserAudioBookmark.objects.create(
            user=self.user_a,
            book=self.book,
            section=self.section,
            timestamp_seconds=120,
            note='Initial note',
        )

        detail_url = reverse('audio_bookmark_detail', kwargs={'pk': bookmark.id})

        # User B cannot update or delete
        self.client.force_authenticate(self.user_b)
        resp = self.client.patch(detail_url, {'note': 'Hacked'})
        self.assertEqual(resp.status_code, 404)
        resp = self.client.delete(detail_url)
        self.assertEqual(resp.status_code, 404)

        # User A updates note
        self.client.force_authenticate(self.user_a)
        resp = self.client.patch(detail_url, {'note': 'Updated reflection'})
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['note'], 'Updated reflection')

        # User A deletes
        resp = self.client.delete(detail_url)
        self.assertEqual(resp.status_code, 204)
        self.assertFalse(UserAudioBookmark.objects.filter(id=bookmark.id).exists())


class MultiVoiceNarrationApiTests(APITestCase):
    def setUp(self):
        from apps.accounts.models import User
        self.user = User.objects.create_user(
            email='listener@example.com',
            username='listener',
            password='Password123!',
            is_premium=False,
        )
        self.premium_user = User.objects.create_user(
            email='premium_listener@example.com',
            username='premium_listener',
            password='Password123!',
            is_premium=True,
        )

        author = Author.objects.create(name='James Clear')
        category = Category.objects.create(name='Productivity', slug='productivity')
        self.book = Book.objects.create(
            title='Atomic Habits',
            subtitle='An Easy & Proven Way to Build Good Habits',
            slug='atomic-habits-voice-test',
            author=author,
            description='Tiny changes, remarkable results.',
            what_you_will_learn='Four laws of behavior change.',
            is_premium=False,
        )
        self.book.categories.add(category)

        self.section = SummarySection.objects.create(
            book=self.book,
            slug='the-fundamentals',
            order=1,
            title='The Fundamentals: Why Tiny Changes Make a Big Difference',
            content='Habits are the compound interest of self-improvement.',
            plain_text='Habits are the compound interest of self-improvement.',
            duration_seconds=180,
            estimated_read_minutes=3,
        )

    def test_voice_catalog_endpoint(self):
        url = reverse('voice_catalog')
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertIn('voices', response.data)
        voices = response.data['voices']
        self.assertEqual(len(voices), 5)

        voice_ids = [v['id'] for v in voices]
        self.assertIn('christopher', voice_ids)
        self.assertIn('jenny', voice_ids)
        self.assertIn('guy', voice_ids)
        self.assertIn('sonia', voice_ids)
        self.assertIn('brian', voice_ids)

        self.assertEqual(response.data['default_voice'], 'christopher')

    def test_section_voice_audio_default_voice(self):
        url = reverse(
            'summary_section_voice_audio',
            kwargs={'book_slug': self.book.slug, 'slug': self.section.slug},
        )
        response = self.client.get(f"{url}?voice=christopher")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['voice'], 'christopher')
        self.assertEqual(response.data['voice_name'], 'Christopher')
        self.assertEqual(response.data['voice_persona'], 'The Thoughtful Strategist')

    def test_section_voice_audio_free_tier_custom_voice(self):
        url = reverse(
            'summary_section_voice_audio',
            kwargs={'book_slug': self.book.slug, 'slug': self.section.slug},
        )
        response = self.client.get(f"{url}?voice=jenny")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['voice'], 'jenny')
        self.assertEqual(response.data['voice_name'], 'Jenny')
        self.assertEqual(response.data['voice_persona'], 'The Calm Storyteller')

    def test_section_voice_audio_premium_voice_gating(self):
        url = reverse(
            'summary_section_voice_audio',
            kwargs={'book_slug': self.book.slug, 'slug': self.section.slug},
        )

        # 1. Anonymous or Free user requesting premium voice (Sonia) -> 403
        response = self.client.get(f"{url}?voice=sonia")
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.data['error'], 'premium_voice_required')
        self.assertTrue(response.data['upgrade_required'])

        # 2. Premium user requesting premium voice (Sonia) -> 200
        self.client.force_authenticate(self.premium_user)
        response = self.client.get(f"{url}?voice=sonia")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['voice'], 'sonia')
        self.assertEqual(response.data['voice_name'], 'Sonia')

    def test_user_voice_preference_get_and_post(self):
        url = reverse('voice_preference')

        # Get default
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['preferred_voice'], 'christopher')

        # Free user cannot set premium voice
        self.client.force_authenticate(self.user)
        response = self.client.post(url, {'voice': 'sonia'})
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.data['error'], 'premium_voice_required')

        # Free user can set free voice (Guy)
        response = self.client.post(url, {'voice': 'guy'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['preferred_voice'], 'guy')

        # Invalid voice returns 400
        response = self.client.post(url, {'voice': 'non_existent_robot'})
        self.assertEqual(response.status_code, 400)

        # Premium user can set premium voice
        self.client.force_authenticate(self.premium_user)
        response = self.client.post(url, {'voice': 'brian'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['preferred_voice'], 'brian')

    def test_summary_section_serializer_exposes_available_voices(self):
        url = reverse(
            'summary_section_detail',
            kwargs={'book_slug': self.book.slug, 'slug': self.section.slug},
        )
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertIn('availableVoices', response.data)
        self.assertEqual(len(response.data['availableVoices']), 5)


