import os
import sys
from django.db import connection
from django.core.cache import cache
from django.http import JsonResponse
from django.utils import timezone


def health_check(request):
    """
    Production health check endpoint for container orchestrators,
    load balancers, Kubernetes liveness/readiness probes, and uptime monitors.
    Returns HTTP 200 when healthy, HTTP 503 if any core subsystem is unavailable.
    """
    status_code = 200
    components = {}

    # 1. Database Connectivity Check
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1;")
            cursor.fetchone()
        components['database'] = 'ok'
    except Exception as exc:
        components['database'] = f'error: {str(exc)}'
        status_code = 503

    # 2. Cache Availability Check
    try:
        test_key = '_health_liveness_check'
        cache.set(test_key, 1, timeout=10)
        cached_val = cache.get(test_key)
        if cached_val == 1:
            components['cache'] = 'ok'
        else:
            components['cache'] = 'degraded'
    except Exception as exc:
        components['cache'] = f'error: {str(exc)}'
        # Do not fail overall health if cache is degraded, but flag it

    overall_status = 'healthy' if status_code == 200 else 'unhealthy'

    return JsonResponse(
        {
            'status': overall_status,
            'timestamp': timezone.now().isoformat(),
            'components': components,
            'environment': 'production' if not os.environ.get('DEBUG', 'False').lower() in ('true', '1') else 'development',
            'version': '1.0.0',
        },
        status=status_code,
    )


def metrics_view(request):
    """
    Prometheus metrics export endpoint.
    Serves Prometheus text format metrics for scrapers.
    """
    try:
        from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
        from django.http import HttpResponse

        return HttpResponse(generate_latest(), content_type=CONTENT_TYPE_LATEST)
    except Exception as exc:
        return JsonResponse(
            {
                'error': 'prometheus_metrics_unavailable',
                'message': str(exc),
            },
            status=503,
        )


def trigger_sentry_error(request):
    """
    Diagnostic endpoint to verify Sentry exception reporting and alerting rules.
    Accessible only in development mode (DEBUG=True) or by staff administrators.
    """
    from django.conf import settings

    if not settings.DEBUG and not (request.user and request.user.is_staff):
        return JsonResponse(
            {
                'error': 'forbidden',
                'message': 'Sentry diagnostic test is only available in DEBUG mode or to staff users.',
            },
            status=403,
        )

    # Trigger intentional division by zero to verify Sentry capture
    division_by_zero = 1 / 0
    return JsonResponse({'status': 'ok', 'result': division_by_zero})

