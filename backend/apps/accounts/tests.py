from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase

User = get_user_model()


class UserProfileTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='profile@example.com',
            username='profile',
            password='secret123',
            first_name='Before',
            last_name='User',
        )
        self.client.force_authenticate(self.user)

    def test_patch_profile_updates_allowed_fields(self):
        response = self.client.patch(
            reverse('user_profile'),
            {
                'first_name': 'After',
                'last_name': 'Name',
                'bio': 'Short bio',
                'avatar_url': 'https://example.com/avatar.png',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.first_name, 'After')
        self.assertEqual(self.user.last_name, 'Name')
        self.assertEqual(self.user.bio, 'Short bio')
        self.assertEqual(self.user.avatar_url, 'https://example.com/avatar.png')

    def test_patch_profile_does_not_allow_sensitive_fields(self):
        response = self.client.patch(
            reverse('user_profile'),
            {
                'email': 'hijack@example.com',
                'is_premium': True,
                'first_name': 'Safe',
                'last_name': 'Update',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.email, 'profile@example.com')
        self.assertFalse(self.user.is_premium)
