from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase
from django.utils import timezone
from datetime import date, timedelta

from apps.catalog.models import Book, Author, Category, DailyPick
from .models import Notification, NotificationPreference
from .tasks import dispatch_daily_pick_notifications, dispatch_streak_reminder_notifications

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
