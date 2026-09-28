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


class UserStreakTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='streak@example.com',
            username='streakuser',
            password='secret123',
        )
        self.client.force_authenticate(self.user)

    def test_record_activity_starts_streak(self):
        from django.utils import timezone
        today = timezone.localdate()
        recorded = self.user.record_reading_activity(today=today)
        self.assertTrue(recorded)
        self.assertEqual(self.user.current_streak, 1)
        self.assertEqual(self.user.longest_streak, 1)
        self.assertEqual(self.user.last_active_date, today)
        self.assertEqual(self.user.get_current_streak(today=today), 1)

    def test_record_activity_same_day_is_idempotent(self):
        from django.utils import timezone
        today = timezone.localdate()
        self.user.record_reading_activity(today=today)
        second_call = self.user.record_reading_activity(today=today)
        self.assertFalse(second_call)
        self.assertEqual(self.user.current_streak, 1)

    def test_consecutive_days_increment_streak(self):
        from datetime import date, timedelta
        day1 = date(2026, 9, 26)
        day2 = date(2026, 9, 27)
        day3 = date(2026, 9, 28)

        self.user.record_reading_activity(today=day1)
        self.assertEqual(self.user.current_streak, 1)

        self.user.record_reading_activity(today=day2)
        self.assertEqual(self.user.current_streak, 2)
        self.assertEqual(self.user.longest_streak, 2)

        self.user.record_reading_activity(today=day3)
        self.assertEqual(self.user.current_streak, 3)
        self.assertEqual(self.user.longest_streak, 3)

    def test_missed_day_breaks_streak(self):
        from datetime import date
        day1 = date(2026, 9, 20)
        day2 = date(2026, 9, 21)
        day_after_gap = date(2026, 9, 25)

        self.user.record_reading_activity(today=day1)
        self.user.record_reading_activity(today=day2)
        self.assertEqual(self.user.current_streak, 2)
        self.assertEqual(self.user.longest_streak, 2)

        # Before reading on 9/25, streak is 0
        self.assertEqual(self.user.get_current_streak(today=day_after_gap), 0)

        # Now reading on 9/25 restarts streak at 1, while longest remains 2
        self.user.record_reading_activity(today=day_after_gap)
        self.assertEqual(self.user.current_streak, 1)
        self.assertEqual(self.user.longest_streak, 2)

    def test_user_profile_me_endpoint_includes_streak(self):
        from django.utils import timezone
        today = timezone.localdate()
        self.user.record_reading_activity(today=today)

        response = self.client.get(reverse('user_profile'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['current_streak'], 1)
        self.assertEqual(response.data['longest_streak'], 1)
        self.assertEqual(response.data['last_active_date'], str(today))

