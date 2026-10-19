from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase
from django.utils import timezone
from datetime import date, timedelta

from apps.catalog.models import Book, Author, Category, DailyPick, Collection
from apps.media.models import DailyAudioDigest, DailyAudioDigestItem
from apps.progress.models import UserBookProgress
from .models import Notification, NotificationPreference
from .tasks import (
    dispatch_daily_pick_notifications,
    dispatch_daily_digest_notifications,
    dispatch_streak_reminder_notifications,
    dispatch_evening_streak_saver_notifications,
    dispatch_new_book_notifications,
    dispatch_collection_notifications,
)

User = get_user_model()


class NotificationApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='notifier@example.com',
            username='notifier',
            password='secret123',
        )
        self.other_user = User.objects.create_user(
            email='other@example.com',
            username='otheruser',
            password='secret123',
        )
        self.client.force_authenticate(self.user)

    def test_list_notifications_user_isolated(self):
        Notification.objects.create(
            user=self.user,
            title='My Alert',
            message='Hello User',
            notification_type=Notification.NotificationType.SYSTEM,
        )
        Notification.objects.create(
            user=self.other_user,
            title='Other Alert',
            message='Hello Other',
            notification_type=Notification.NotificationType.SYSTEM,
        )

        response = self.client.get(reverse('notification_list'))
        self.assertEqual(response.status_code, 200)
        data = response.data['results'] if 'results' in response.data else response.data
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['title'], 'My Alert')

    def test_mark_single_notification_read(self):
        notif = Notification.objects.create(
            user=self.user,
            title='Unread Alert',
            message='Please read me',
            is_read=False,
        )
        response = self.client.post(reverse('notification_mark_read', kwargs={'pk': notif.id}))
        self.assertEqual(response.status_code, 200)
        notif.refresh_from_db()
        self.assertTrue(notif.is_read)

    def test_mark_all_read(self):
        Notification.objects.create(user=self.user, title='N1', message='M1', is_read=False)
        Notification.objects.create(user=self.user, title='N2', message='M2', is_read=False)

        response = self.client.post(reverse('notification_read_all'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['updated_count'], 2)
        self.assertEqual(Notification.objects.filter(user=self.user, is_read=False).count(), 0)

    def test_unread_count(self):
        Notification.objects.create(user=self.user, title='N1', message='M1', is_read=False)
        Notification.objects.create(user=self.user, title='N2', message='M2', is_read=True)

        response = self.client.get(reverse('notification_unread_count'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['unread_count'], 1)

    def test_notification_preferences_get_and_patch(self):
        # GET creates default
        res_get = self.client.get(reverse('notification_preferences'))
        self.assertEqual(res_get.status_code, 200)
        self.assertTrue(res_get.data['daily_pick_enabled'])
        self.assertTrue(res_get.data['streak_reminder_enabled'])

        # PATCH updates
        res_patch = self.client.patch(
            reverse('notification_preferences'),
            {'daily_pick_enabled': False, 'reminder_time': '09:00:00'},
            format='json',
        )
        self.assertEqual(res_patch.status_code, 200)
        self.assertFalse(res_patch.data['daily_pick_enabled'])
        self.assertEqual(res_patch.data['reminder_time'], '09:00:00')

    def test_dispatch_daily_pick_task(self):
        author = Author.objects.create(name='Pick Author')
        category = Category.objects.create(name='Business', slug='business')
        book = Book.objects.create(
            title='Daily Pick Book',
            slug='daily-pick-book',
            author=author,
            description='Test book',
        )
        book.categories.add(category)
        today = timezone.localdate()
        DailyPick.objects.create(book=book, date=today)

        count = dispatch_daily_pick_notifications()
        self.assertGreaterEqual(count, 1)

        # Check notification created for user
        notif = Notification.objects.filter(
            user=self.user,
            notification_type=Notification.NotificationType.DAILY_PICK,
        ).first()
        self.assertIsNotNone(notif)
        self.assertIn('Daily Pick Book', notif.title)
        self.assertEqual(notif.action_url, '/books/daily-pick-book/read')

    def test_dispatch_streak_reminder_task(self):
        # Set user streak to 3, last active yesterday
        today = timezone.localdate()
        yesterday = today - timedelta(days=1)
        self.user.current_streak = 3
        self.user.longest_streak = 5
        self.user.last_active_date = yesterday
        self.user.save(update_fields=['current_streak', 'longest_streak', 'last_active_date'])

        count = dispatch_streak_reminder_notifications()
        self.assertGreaterEqual(count, 1)

        notif = Notification.objects.filter(
            user=self.user,
            notification_type=Notification.NotificationType.STREAK_REMINDER,
        ).first()
        self.assertIsNotNone(notif)
        self.assertIn('3-day streak', notif.title)

    def test_delete_notification(self):
        notif = Notification.objects.create(
            user=self.user,
            title='Delete Me',
            message='Dismissable alert',
        )
        response = self.client.delete(reverse('notification_delete', kwargs={'pk': notif.id}))
        self.assertEqual(response.status_code, 204)
        self.assertFalse(Notification.objects.filter(id=notif.id).exists())

    def test_delete_notification_cross_user_forbidden(self):
        other_notif = Notification.objects.create(
            user=self.other_user,
            title='Other User Alert',
            message='Cannot touch this',
        )
        response = self.client.delete(reverse('notification_delete', kwargs={'pk': other_notif.id}))
        self.assertEqual(response.status_code, 404)
        self.assertTrue(Notification.objects.filter(id=other_notif.id).exists())

    def test_simulate_notification(self):
        payload = {
            'notification_type': 'daily_pick',
            'title': 'Test Deep Link Notification',
            'message': 'Testing navigation to book detail',
            'action_url': '/books/deep-work/read',
        }
        response = self.client.post(reverse('notification_simulate'), payload, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['title'], 'Test Deep Link Notification')
        self.assertEqual(response.data['action_url'], '/books/deep-work/read')

        notif = Notification.objects.filter(user=self.user, title='Test Deep Link Notification').first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.notification_type, Notification.NotificationType.DAILY_PICK)

    def test_dispatch_new_book_task(self):
        author = Author.objects.create(name='Cal Newport')
        book = Book.objects.create(
            title='Deep Work',
            slug='deep-work',
            author=author,
            description='Rules for focused success.',
        )
        count = dispatch_new_book_notifications(book.id)
        self.assertGreaterEqual(count, 1)

        notif = Notification.objects.filter(
            user=self.user,
            notification_type=Notification.NotificationType.NEW_BOOK,
        ).first()
        self.assertIsNotNone(notif)
        self.assertIn('Deep Work', notif.title)
        self.assertEqual(notif.action_url, '/books/deep-work')

    def test_dispatch_collection_task(self):
        collection = Collection.objects.create(
            title='Productivity Masterclass',
            slug='productivity-masterclass',
            description='Master the art of focused work and peak productivity.',
        )
        count = dispatch_collection_notifications(collection.id)
        self.assertGreaterEqual(count, 1)

        notif = Notification.objects.filter(
            user=self.user,
            action_url='/collections/productivity-masterclass',
        ).first()
        self.assertIsNotNone(notif)
        self.assertIn('Productivity Masterclass', notif.title)

    def test_register_device_token_endpoint(self):
        url = reverse('notification_register_token')
        resp = self.client.post(url, {'fcm_token': 'fcm_test_token_999'})
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['status'], 'token_registered')

        pref = NotificationPreference.objects.get(user=self.user)
        self.assertEqual(pref.fcm_token, 'fcm_test_token_999')

    def test_dispatch_morning_daily_digest_task(self):
        today = timezone.localdate()
        digest = DailyAudioDigest.objects.create(
            date=today,
            title="Daily Blink • Morning Digest",
            theme="Focus, Habits & Mental Agility",
            total_duration_seconds=900,
        )

        pref, _ = NotificationPreference.objects.get_or_create(user=self.user)
        pref.daily_pick_enabled = True
        pref.fcm_token = 'device-token-123'
        pref.save()

        count = dispatch_daily_digest_notifications()
        self.assertGreaterEqual(count, 1)

        notif = Notification.objects.filter(
            user=self.user,
            notification_type=Notification.NotificationType.DAILY_DIGEST,
        ).first()
        self.assertIsNotNone(notif)
        self.assertIn("Focus, Habits & Mental Agility", notif.title)
        self.assertIn("/daily-blink?autoplay=true", notif.action_url)

        # Ensure calling again does not create duplicate notification
        dup_count = dispatch_daily_digest_notifications()
        self.assertEqual(dup_count, 0)

    def test_dispatch_evening_streak_saver_with_personalized_recommendation(self):
        cat_psych = Category.objects.create(name='Psychology', slug='psychology')
        author = Author.objects.create(name='Daniel Kahneman')

        # User finished reading Book 1 in Psychology
        book_finished = Book.objects.create(
            title='Thinking, Fast and Slow',
            slug='thinking-fast-and-slow',
            author=author,
            description='System 1 and System 2',
        )
        book_finished.categories.add(cat_psych)

        UserBookProgress.objects.create(
            user=self.user,
            book=book_finished,
            percent_complete=100,
            is_completed=True,
        )

        # Candidate recommendation book in Psychology
        book_rec = Book.objects.create(
            title='Noise',
            slug='noise-a-flaw-in-human-judgment',
            author=author,
            description='Flaws in human judgment',
            rating=4.9,
        )
        book_rec.categories.add(cat_psych)

        # Set user streak to 4 days, with no reading today
        self.user.current_streak = 4
        self.user.last_active_date = timezone.localdate() - timedelta(days=1)
        self.user.save()

        pref, _ = NotificationPreference.objects.get_or_create(user=self.user)
        pref.streak_reminder_enabled = True
        pref.fcm_token = 'streak-token-456'
        pref.save()

        count = dispatch_evening_streak_saver_notifications()
        self.assertGreaterEqual(count, 1)

        notif = Notification.objects.filter(
            user=self.user,
            notification_type=Notification.NotificationType.STREAK_REMINDER,
        ).first()
        self.assertIsNotNone(notif)
        self.assertIn("Protect your 4-day streak", notif.title)
        self.assertIn("Noise", notif.message)
        self.assertIn("Psychology", notif.message)
        self.assertEqual(notif.action_url, f"/books/{book_rec.slug}/read")

    def test_dispatch_endpoints_api(self):
        url_morning = reverse('notification_dispatch_morning_digest')
        resp_m = self.client.post(url_morning)
        self.assertEqual(resp_m.status_code, 200)
        self.assertEqual(resp_m.data['status'], 'morning_digest_dispatched')

        url_evening = reverse('notification_dispatch_evening_streak')
        resp_e = self.client.post(url_evening)
        self.assertEqual(resp_e.status_code, 200)
        self.assertEqual(resp_e.data['status'], 'evening_streak_saver_dispatched')


