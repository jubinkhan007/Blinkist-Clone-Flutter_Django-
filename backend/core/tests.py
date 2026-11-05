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
