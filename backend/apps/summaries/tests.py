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
