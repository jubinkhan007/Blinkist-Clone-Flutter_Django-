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


class UserReadingStatsTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='gamify@example.com',
            username='gamifyuser',
            password='secret123',
        )
        self.client.force_authenticate(self.user)
        author = Author.objects.create(name='Habit Author')
        category = Category.objects.create(name='Productivity', slug='productivity')
        self.book = Book.objects.create(
            title='Atomic Habits',
            slug='atomic-habits',
            author=author,
            description='desc',
        )
        self.book.categories.add(category)
        from apps.summaries.models import SummarySection
        self.section1 = SummarySection.objects.create(
            book=self.book,
            slug='section-1',
            title='Section 1',
            order=1,
            content='Content 1',
        )
        self.section2 = SummarySection.objects.create(
            book=self.book,
            slug='section-2',
            title='Section 2',
            order=2,
            content='Content 2',
        )

    def test_record_activity_endpoint(self):
        response = self.client.post(reverse('record_activity'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'success')
        self.assertEqual(response.data['current_streak'], 1)
        self.assertTrue(response.data['is_active_today'])

    def test_mark_section_read_triggers_streak(self):
        response = self.client.post(
            reverse('mark_section_read', kwargs={'book_id': self.book.id, 'section_id': self.section1.id})
        )
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.current_streak, 1)
        self.assertIsNotNone(self.user.last_active_date)

    def test_reading_stats_endpoint(self):
        # Mark one section read
        self.client.post(
            reverse('mark_section_read', kwargs={'book_id': self.book.id, 'section_id': self.section1.id})
        )
        # Save audio progress (120 seconds = 2 minutes)
        self.client.post(
            reverse('audio_progress', kwargs={'book_id': self.book.id}),
            {'section_id': self.section1.id, 'position_seconds': 120.0, 'is_finished': True},
            format='json',
        )

        response = self.client.get(reverse('reading_stats'))
        self.assertEqual(response.status_code, 200)
        data = response.data
        self.assertEqual(data['current_streak'], 1)
        self.assertEqual(data['total_sections_read'], 1)
        self.assertEqual(data['total_audio_minutes'], 2)
        self.assertTrue(data['is_active_today'])
        self.assertEqual(len(data['weekly_activity']), 7)
        self.assertTrue(any(data['weekly_activity']))

        # Test weekly and monthly period breakdowns
        self.assertIn('weekly', data)
        self.assertIn('monthly', data)
        self.assertGreaterEqual(data['weekly']['total_minutes'], 2)
        self.assertGreaterEqual(data['monthly']['total_minutes'], 2)

        # Test 84-day activity heatmap
        self.assertIn('activity_heatmap', data)
        self.assertEqual(len(data['activity_heatmap']), 84)
        last_day = data['activity_heatmap'][-1]
        self.assertTrue(last_day['is_active'])
        self.assertGreaterEqual(last_day['total_minutes'], 2)

        # Test badges preview in stats
        self.assertIn('unlocked_badges_count', data)
        self.assertGreaterEqual(data['unlocked_badges_count'], 1)
        self.assertIn('recent_badges', data)

    def test_user_badges_endpoint(self):
        # Trigger some progress
        self.client.post(
            reverse('mark_section_read', kwargs={'book_id': self.book.id, 'section_id': self.section1.id})
        )
        self.client.post(
            reverse('audio_progress', kwargs={'book_id': self.book.id}),
            {'section_id': self.section1.id, 'position_seconds': 60.0, 'is_finished': False},
            format='json',
        )

        response = self.client.get(reverse('user_badges'))
        from apps.progress.badges import BADGES
        self.assertEqual(response.data['total_badges'], len(BADGES))
        self.assertGreaterEqual(response.data['unlocked_count'], 2)

        badges_dict = {b['key']: b for b in response.data['badges']}
        self.assertTrue(badges_dict['first_spark']['is_unlocked'])
        self.assertTrue(badges_dict['first_listen']['is_unlocked'])
        self.assertFalse(badges_dict['streak_30']['is_unlocked'])
        self.assertEqual(badges_dict['streak_30']['progress_percent'], round(1.0 / 30.0, 2))

    def test_book_completion_unlocks_first_blink_badge(self):
        # Complete all sections of the book
        self.client.post(
            reverse('mark_section_read', kwargs={'book_id': self.book.id, 'section_id': self.section1.id})
        )
        self.client.post(
            reverse('mark_section_read', kwargs={'book_id': self.book.id, 'section_id': self.section2.id})
        )

        response = self.client.get(reverse('user_badges'))
        self.assertEqual(response.status_code, 200)
        badges_dict = {b['key']: b for b in response.data['badges']}
        self.assertTrue(badges_dict['first_blink']['is_unlocked'])
        self.assertEqual(badges_dict['first_blink']['current_progress'], 1)


class ActionPlanApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='habits@example.com',
            username='habituser',
            password='secret123',
        )
        self.client.force_authenticate(self.user)
        author = Author.objects.create(name='James Clear')
        category = Category.objects.create(name='Productivity', slug='productivity')
        self.book = Book.objects.create(
            title='Atomic Habits',
            subtitle='An Easy & Proven Way to Build Good Habits & Break Bad Ones',
            slug='atomic-habits',
            author=author,
            description='A practical guide on how to form good habits and break bad ones.',
            what_you_will_learn='How small changes can lead to remarkable results.',
        )
        self.book.categories.add(category)
        from apps.summaries.models import SummarySection, UserHighlight
        self.section1 = SummarySection.objects.create(
            book=self.book,
            title='The Surprising Power of Atomic Habits',
            slug='the-surprising-power',
            content='1% better every day adds up to 37x improvement in a single year.',
            plain_text='1% better every day adds up to 37x improvement in a single year.',
            order=1,
        )
        self.section2 = SummarySection.objects.create(
            book=self.book,
            title='How Your Habits Shape Your Identity',
            slug='how-habits-shape-identity',
            content='The ultimate form of intrinsic motivation is when a habit becomes part of your identity.',
            plain_text='The ultimate form of intrinsic motivation is when a habit becomes part of your identity.',
            order=2,
        )

    def test_generate_action_plan_7_days(self):
        response = self.client.post(
            reverse('action_plan_generate', kwargs={'book_identifier': self.book.slug}),
            {'duration_days': 7},
            format='json',
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['book_slug'], self.book.slug)
        self.assertEqual(response.data['duration_days'], 7)
        self.assertEqual(len(response.data['items']), 7)
        self.assertEqual(response.data['progress_percent'], 0)
        self.assertFalse(response.data['is_completed'])

    def test_generate_action_plan_14_days(self):
        response = self.client.post(
            reverse('action_plan_generate', kwargs={'book_identifier': self.book.slug}),
            {'duration_days': 14},
            format='json',
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['duration_days'], 14)
        self.assertEqual(len(response.data['items']), 14)

    def test_action_plan_merges_user_highlights(self):
        from apps.summaries.models import UserHighlight
        UserHighlight.objects.create(
            user=self.user,
            book=self.book,
            section=self.section1,
            selected_text='1% better every day adds up',
            note='Focus on micro improvements daily',
        )

        response = self.client.post(
            reverse('action_plan_generate', kwargs={'book_identifier': self.book.slug}),
            {'duration_days': 7, 'force_regenerate': True},
            format='json',
        )
        self.assertEqual(response.status_code, 201)
        # Check that highlight text or note is present in one of the item quotes
        first_item = response.data['items'][0]
        self.assertIn('1% better every day', first_item['associated_quote'])
        self.assertIn('Focus on micro improvements daily', first_item['associated_quote'])

    def test_toggle_item_completion_and_streak(self):
        gen_res = self.client.post(
            reverse('action_plan_generate', kwargs={'book_identifier': self.book.slug}),
            {'duration_days': 7},
            format='json',
        )
        plan_id = gen_res.data['id']
        first_item_id = gen_res.data['items'][0]['id']

        # Toggle item complete
        toggle_res = self.client.patch(
            reverse('action_plan_item_toggle', kwargs={'pk': plan_id, 'item_id': first_item_id}),
            {'is_completed': True},
            format='json',
        )
        self.assertEqual(toggle_res.status_code, 200)
        self.assertEqual(toggle_res.data['completed_items_count'], 1)
        self.assertEqual(toggle_res.data['progress_percent'], 14)  # 1/7 = ~14%
        self.assertTrue(toggle_res.data['items'][0]['is_completed'])

        # Verify daily activity / habit recorded
        from apps.progress.models import UserDailyActivity
        from django.utils import timezone
        activity = UserDailyActivity.objects.filter(user=self.user, date=timezone.localdate()).first()
        self.assertIsNotNone(activity)
        self.assertGreater(activity.reading_minutes, 0)

    def test_export_action_plan(self):
        gen_res = self.client.post(
            reverse('action_plan_generate', kwargs={'book_identifier': self.book.slug}),
            {'duration_days': 7},
            format='json',
        )
        plan_id = gen_res.data['id']

        # Default JSON export
        export_res = self.client.get(reverse('action_plan_export', kwargs={'pk': plan_id}))
        self.assertEqual(export_res.status_code, 200)
        self.assertIn('markdown', export_res.data)
        self.assertIn('notion_text', export_res.data)
        self.assertIn('ics_content', export_res.data)
        self.assertIn('BEGIN:VCALENDAR', export_res.data['ics_content'])

        # Markdown attachment export
        md_res = self.client.get(reverse('action_plan_export', kwargs={'pk': plan_id}), {'export_format': 'md'})
        self.assertEqual(md_res.status_code, 200)
        self.assertEqual(md_res['Content-Type'], 'text/markdown; charset=utf-8')

        # Calendar attachment export
        ics_res = self.client.get(reverse('action_plan_export', kwargs={'pk': plan_id}), {'export_format': 'ics'})
        self.assertEqual(ics_res.status_code, 200)
        self.assertEqual(ics_res['Content-Type'], 'text/calendar; charset=utf-8')



