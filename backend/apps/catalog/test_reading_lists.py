import uuid
from django.urls import reverse
from rest_framework.test import APITestCase

from apps.accounts.models import User
from apps.catalog.models import Author, Book, Category, UserReadingList, UserReadingListItem


class ReadingListApiTests(APITestCase):
    def setUp(self):
        self.user1 = User.objects.create_user(
            username='user1',
            email='user1@example.com',
            password='password123',
        )
        self.user2 = User.objects.create_user(
            username='user2',
            email='user2@example.com',
            password='password123',
        )

        self.author = Author.objects.create(name='Malcolm Gladwell')
        self.category = Category.objects.create(name='Psychology', slug='psychology')
        self.book1 = Book.objects.create(
            title='Outliers',
            slug='outliers',
            author=self.author,
            description='The story of success.',
            estimated_read_time_minutes=15,
        )
        self.book1.categories.add(self.category)

        self.book2 = Book.objects.create(
            title='Blink',
            slug='blink',
            author=self.author,
            description='The power of thinking without thinking.',
            estimated_read_time_minutes=12,
        )
        self.book2.categories.add(self.category)

    def test_create_and_list_spaces(self):
        self.client.force_authenticate(self.user1)

        # Create space
        create_resp = self.client.post(
            reverse('user_reading_lists'),
            data={
                'title': 'Morning Mindset',
                'description': 'Books to start my day',
                'emoji': '🌅',
                'color_hex': '#10B981',
                'is_public': True,
            },
            format='json',
        )
        self.assertEqual(create_resp.status_code, 201)
        self.assertEqual(create_resp.data['title'], 'Morning Mindset')
        self.assertEqual(create_resp.data['emoji'], '🌅')
        self.assertEqual(create_resp.data['color_hex'], '#10B981')
        self.assertTrue(create_resp.data['is_public'])
        self.assertTrue(create_resp.data['is_owner'])
        space_id = create_resp.data['id']

        # List spaces
        list_resp = self.client.get(reverse('user_reading_lists'))
        self.assertEqual(list_resp.status_code, 200)
        self.assertEqual(len(list_resp.data), 1)
        self.assertEqual(list_resp.data[0]['id'], space_id)
        self.assertEqual(list_resp.data[0]['items_count'], 0)

    def test_add_remove_books_and_membership(self):
        self.client.force_authenticate(self.user1)
        space = UserReadingList.objects.create(
            user=self.user1,
            title='Deep Work',
            emoji='🧠',
        )

        # Add book1
        add_resp = self.client.post(
            reverse('user_reading_list_add_book', kwargs={'pk': space.id}),
            data={'book_slug': self.book1.slug, 'note': 'Key chapter 1'},
            format='json',
        )
        self.assertEqual(add_resp.status_code, 200)
        self.assertEqual(add_resp.data['items_count'], 1)
        self.assertTrue(
            UserReadingListItem.objects.filter(reading_list=space, book=self.book1).exists()
        )

        # Add book2
        add_resp2 = self.client.post(
            reverse('user_reading_list_add_book', kwargs={'pk': space.id}),
            data={'book_slug': self.book2.slug},
            format='json',
        )
        self.assertEqual(add_resp2.status_code, 200)
        self.assertEqual(add_resp2.data['items_count'], 2)

        # Query membership for book1
        member_resp = self.client.get(
            reverse('user_reading_list_membership') + f'?book_slug={self.book1.slug}'
        )
        self.assertEqual(member_resp.status_code, 200)
        self.assertIn(space.id, member_resp.data['list_ids'])

        # Remove book1
        del_resp = self.client.delete(
            reverse(
                'user_reading_list_remove_book',
                kwargs={'pk': space.id, 'book_slug': self.book1.slug},
            )
        )
        self.assertEqual(del_resp.status_code, 200)
        self.assertEqual(del_resp.data['items_count'], 1)

        # Check membership again
        member_resp2 = self.client.get(
            reverse('user_reading_list_membership') + f'?book_slug={self.book1.slug}'
        )
        self.assertEqual(member_resp2.status_code, 200)
        self.assertNotIn(space.id, member_resp2.data['list_ids'])

    def test_reorder_books(self):
        self.client.force_authenticate(self.user1)
        space = UserReadingList.objects.create(user=self.user1, title='Reorder Space')
        item1 = UserReadingListItem.objects.create(
            reading_list=space, book=self.book1, order=1
        )
        item2 = UserReadingListItem.objects.create(
            reading_list=space, book=self.book2, order=2
        )

        # Reorder to book2, book1
        reorder_resp = self.client.post(
            reverse('user_reading_list_reorder', kwargs={'pk': space.id}),
            data={'book_slugs': [self.book2.slug, self.book1.slug]},
            format='json',
        )
        self.assertEqual(reorder_resp.status_code, 200)

        item1.refresh_from_db()
        item2.refresh_from_db()
        self.assertEqual(item2.order, 1)
        self.assertEqual(item1.order, 2)

    def test_privacy_and_user_isolation(self):
        # User 1 creates private space
        space = UserReadingList.objects.create(
            user=self.user1,
            title='Private Space',
            is_public=False,
        )

        # User 2 tries to view without token -> 403
        self.client.force_authenticate(self.user2)
        get_resp = self.client.get(
            reverse('user_reading_list_detail', kwargs={'pk': space.id})
        )
        self.assertEqual(get_resp.status_code, 403)

        # User 2 tries to edit User 1's space -> 403
        patch_resp = self.client.patch(
            reverse('user_reading_list_detail', kwargs={'pk': space.id}),
            data={'title': 'Hacked Title'},
            format='json',
        )
        self.assertEqual(patch_resp.status_code, 403)

        # User 2 tries to delete User 1's space -> 403
        del_resp = self.client.delete(
            reverse('user_reading_list_detail', kwargs={'pk': space.id})
        )
        self.assertEqual(del_resp.status_code, 403)

        # User 2 views private space WITH correct token -> 200
        token_resp = self.client.get(
            reverse('user_reading_list_detail', kwargs={'pk': space.id})
            + f'?token={space.share_token}'
        )
        self.assertEqual(token_resp.status_code, 200)
        self.assertFalse(token_resp.data['is_owner'])

    def test_public_sharing_and_cloning(self):
        space = UserReadingList.objects.create(
            user=self.user1,
            title='Curated Gems',
            description='A great list',
            emoji='💎',
            color_hex='#6366F1',
        )
        UserReadingListItem.objects.create(
            reading_list=space, book=self.book1, order=1, note='Essential'
        )

        # Anonymous user views via share token endpoint
        anon_client = self.client_class()
        share_resp = anon_client.get(
            reverse('shared_reading_list_detail', kwargs={'token': space.share_token})
        )
        self.assertEqual(share_resp.status_code, 200)
        self.assertEqual(share_resp.data['title'], 'Curated Gems')
        self.assertEqual(len(share_resp.data['items']), 1)
        self.assertEqual(share_resp.data['items'][0]['book']['slug'], self.book1.slug)

        # User 2 clones space
        self.client.force_authenticate(self.user2)
        clone_resp = self.client.post(
            reverse('shared_reading_list_clone', kwargs={'token': space.share_token})
        )
        self.assertEqual(clone_resp.status_code, 201)
        self.assertEqual(clone_resp.data['title'], 'Curated Gems (Saved)')
        self.assertTrue(clone_resp.data['is_owner'])
        self.assertEqual(len(clone_resp.data['items']), 1)

        # Cloned space belongs to User 2 in DB
        self.assertTrue(
            UserReadingList.objects.filter(
                user=self.user2, title='Curated Gems (Saved)'
            ).exists()
        )
