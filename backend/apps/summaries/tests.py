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
