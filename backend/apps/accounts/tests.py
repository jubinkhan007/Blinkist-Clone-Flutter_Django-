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


class UserOnboardingTests(APITestCase):
    def setUp(self):
        from apps.catalog.models import Category, Book, Author

        self.user = User.objects.create_user(
            email='newbie@example.com',
            username='newbie',
            password='secret123',
        )
        self.client.force_authenticate(self.user)

        self.author = Author.objects.create(name='James Clear')
        self.cat_prod, _ = Category.objects.get_or_create(
            slug='personal-development',
            defaults={'name': 'Personal Development'},
        )
        self.cat_science, _ = Category.objects.get_or_create(
            slug='science',
            defaults={'name': 'Science'},
        )
        self.book1 = Book.objects.create(
            title='Atomic Habits',
            slug='atomic-habits',
            author=self.author,
            description='Habit formation book',
        )
        self.book1.categories.add(self.cat_prod)

        self.book2 = Book.objects.create(
            title='Cosmos',
            slug='cosmos',
            author=self.author,
            description='Astrophysics book',
        )
        self.book2.categories.add(self.cat_science)

    def test_get_onboarding_topics(self):
        response = self.client.get(reverse('onboarding_topics'))
        self.assertEqual(response.status_code, 200)
        self.assertIn('topics', response.data)
        self.assertTrue(len(response.data['topics']) >= 4)
        topic_ids = [t['id'] for t in response.data['topics']]
        self.assertIn('productivity', topic_ids)
        self.assertIn('psychology', topic_ids)

    def test_post_onboarding_submission(self):
        payload = {
            'reading_goal': 'daily_15',
            'preferred_format': 'audio',
            'interest_topics': ['personal-development', 'psychology'],
        }
        response = self.client.post(reverse('onboarding_submit'), payload, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data['has_completed_onboarding'])
        self.assertEqual(response.data['reading_goal'], 'daily_15')
        self.assertEqual(response.data['preferred_format'], 'audio')
        self.assertEqual(response.data['interest_topics'], ['personal-development', 'psychology'])

        self.user.refresh_from_db()
        self.assertTrue(self.user.has_completed_onboarding)
        self.assertEqual(self.user.reading_goal, 'daily_15')
        self.assertEqual(self.user.preferred_format, 'audio')
        self.assertIn(self.cat_prod, self.user.interest_categories.all())

    def test_onboarding_unauthenticated_forbidden(self):
        self.client.logout()
        response = self.client.post(reverse('onboarding_submit'), {'reading_goal': 'casual'})
        self.assertEqual(response.status_code, 401)

    def test_home_feed_personalized_recommendation_from_interests(self):
        # User submits interest in science
        payload = {
            'reading_goal': 'career',
            'preferred_format': 'both',
            'interest_topics': ['science'],
        }
        self.client.post(reverse('onboarding_submit'), payload, format='json')

        # Check Home Feed
        from apps.home.services import get_home_feed_for_user
        feed = get_home_feed_for_user(self.user)
        recommended_books = list(feed['recommended'])
        self.assertTrue(len(recommended_books) > 0)
        # book2 (Cosmos, in Science) should be in recommended!
        self.assertIn(self.book2, recommended_books)


class AdminOverhaulTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='adminuser@example.com',
            username='adminuser',
            password='password123',
            is_premium=True,
            subscription_status=User.SubscriptionStatus.ACTIVE,
            current_streak=7,
            longest_streak=14,
            has_completed_onboarding=True,
            preferred_format='audio',
        )

    def test_custom_user_admin_badges(self):
        from django.contrib.admin.sites import AdminSite
        from apps.accounts.admin import CustomUserAdmin
        admin_instance = CustomUserAdmin(User, AdminSite())

        sub_badge = admin_instance.subscription_badge(self.user)
        self.assertIn('Active Pro', sub_badge)

        streak_badge = admin_instance.streak_badge(self.user)
        self.assertIn('7', streak_badge)
        self.assertIn('max 14', streak_badge)

        self.assertTrue(admin_instance.onboarding_badge(self.user))

        format_badge = admin_instance.format_badge(self.user)
        self.assertIn('Audio', format_badge)

    def test_custom_user_admin_actions(self):
        from django.contrib.admin.sites import AdminSite
        from apps.accounts.admin import CustomUserAdmin
        from unittest.mock import MagicMock
        admin_instance = CustomUserAdmin(User, AdminSite())
        mock_request = MagicMock()

        # Test grant 30-day subscription
        qs = User.objects.filter(id=self.user.id)
        admin_instance.grant_30_day_subscription(mock_request, qs)
        self.user.refresh_from_db()
        self.assertTrue(self.user.is_premium)
        self.assertEqual(self.user.subscription_status, User.SubscriptionStatus.ACTIVE)
        self.assertIsNotNone(self.user.subscription_end_date)

        # Test cancel subscription
        admin_instance.cancel_subscription_action(mock_request, qs)
        self.user.refresh_from_db()
        self.assertFalse(self.user.is_premium)
        self.assertEqual(self.user.subscription_status, User.SubscriptionStatus.CANCELLED)

        # Test reset streak
        admin_instance.reset_streak_action(mock_request, qs)
        self.user.refresh_from_db()
        self.assertEqual(self.user.current_streak, 0)

    def test_dashboard_callback_metrics(self):
        from core.admin_dashboard import dashboard_callback
        from unittest.mock import MagicMock
        context = {}
        result = dashboard_callback(MagicMock(), context)
        self.assertIn('kpi', result)
        kpi = result['kpi']
        self.assertIn('estimated_mrr_bdt', kpi)
        self.assertIn('active_subscribers', kpi)
        self.assertIn('total_flashcards', kpi)
        self.assertIn('mastery_rate', kpi)
        self.assertIn('total_reading_spaces', kpi)
        self.assertIn('digest_completions_today', kpi)

    def test_log_entry_admin_action_badge(self):
        from django.contrib.admin.sites import AdminSite
        from django.contrib.admin.models import ADDITION, CHANGE, DELETION, LogEntry
        from django.contrib.contenttypes.models import ContentType
        from core.admin_audit import LogEntryAdmin

        ct = ContentType.objects.get_for_model(User)
        entry = LogEntry(
            user=self.user,
            content_type=ct,
            object_id=str(self.user.id),
            object_repr='adminuser@example.com',
            action_flag=ADDITION,
            change_message='[{"added": {}}]',
        )
        admin_instance = LogEntryAdmin(LogEntry, AdminSite())
        self.assertEqual(admin_instance.action_badge(entry), 'Added')
        self.assertFalse(admin_instance.has_add_permission(None))
        self.assertFalse(admin_instance.has_delete_permission(None))



