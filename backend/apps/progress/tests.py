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
