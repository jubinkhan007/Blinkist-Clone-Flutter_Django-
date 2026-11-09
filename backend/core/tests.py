from django.test import TestCase, Client
from django.urls import reverse
from rest_framework.settings import api_settings


class ProductionHealthCheckTests(TestCase):
    def setUp(self):
        self.client = Client()

    def test_healthz_endpoint_returns_healthy(self):
        response = self.client.get(reverse('healthz'))
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data['status'], 'healthy')
        self.assertEqual(data['components']['database'], 'ok')
        self.assertIn('timestamp', data)
        self.assertIn('version', data)

    def test_api_health_endpoint_alias(self):
        response = self.client.get(reverse('api_health'))
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data['status'], 'healthy')

    def test_rate_limiting_throttles_configured(self):
        throttle_classes = [cls.__name__ for cls in api_settings.DEFAULT_THROTTLE_CLASSES]
        self.assertIn('AnonRateThrottle', throttle_classes)
        self.assertIn('UserRateThrottle', throttle_classes)
        self.assertIn('anon', api_settings.DEFAULT_THROTTLE_RATES)
        self.assertIn('user', api_settings.DEFAULT_THROTTLE_RATES)

    def test_metrics_endpoint_accessible(self):
        response = self.client.get(reverse('prometheus_metrics'))
        self.assertIn(response.status_code, [200, 503])

    def test_sentry_debug_endpoint_protected(self):
        response = self.client.get(reverse('sentry_debug'))
        # Unauthenticated user should be blocked with 403 if DEBUG is False
        from django.conf import settings
        if not settings.DEBUG:
            self.assertEqual(response.status_code, 403)

    def test_custom_prometheus_metrics_helpers(self):
        from core.metrics import (
            AUDIO_STREAMS_TOTAL,
            AI_QUERIES_TOTAL,
            AI_QUERY_LATENCY,
            ACTIVE_SYNC_SESSIONS,
            SYNC_HANDOFFS_TOTAL,
            track_ai_latency,
        )

        # Ensure metric operations execute without crashing
        AUDIO_STREAMS_TOTAL.labels(voice_id='jenny', book_slug='deep-work', source='test').inc()
        AI_QUERIES_TOTAL.labels(status='success', model='gemini').inc()
        AI_QUERY_LATENCY.labels(model='gemini', status='success').observe(0.45)
        ACTIVE_SYNC_SESSIONS.set(5)
        SYNC_HANDOFFS_TOTAL.labels(source_device='web', target_device='mobile').inc()

        @track_ai_latency(model='test-gemini')
        def sample_ai_task():
            return "ok"

        res = sample_ai_task()
        self.assertEqual(res, "ok")

