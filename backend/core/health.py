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
