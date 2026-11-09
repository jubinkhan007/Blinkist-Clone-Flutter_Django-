from __future__ import annotations

import logging
import time
from functools import wraps
from typing import Any, Callable, Dict, Optional

logger = logging.getLogger(__name__)

# Resilient Prometheus metric initialization
try:
    from prometheus_client import Counter, Histogram, Gauge

    HAVE_PROMETHEUS = True
except ImportError:
    HAVE_PROMETHEUS = False


if HAVE_PROMETHEUS:
    # ── 1. Audio Narration & Multi-Voice APM Metrics ─────────────────────────
    AUDIO_STREAMS_TOTAL = Counter(
        'blinkist_audio_streams_total',
        'Total number of audio streams initiated or requested',
        ['voice_id', 'book_slug', 'source'],
    )

    AUDIO_STREAM_DURATION = Histogram(
        'blinkist_audio_stream_duration_seconds',
        'Duration of audio playback sessions in seconds',
        ['voice_id', 'device_type'],
        buckets=(15, 30, 60, 120, 300, 600, 900, 1200, 1800, 3600),
    )

    # ── 2. Content Consumption & Reading Metrics ─────────────────────────────
    SUMMARY_READS_TOTAL = Counter(
        'blinkist_summary_reads_total',
        'Total summary section read views completed',
        ['book_slug', 'section_order'],
    )

    # ── 3. AI Pipeline & "Ask the Book" Telemetry ────────────────────────────
    AI_QUERIES_TOTAL = Counter(
        'blinkist_ai_queries_total',
        'Total "Ask the Book" AI Q&A queries processed',
        ['status', 'model'],
    )

    AI_QUERY_LATENCY = Histogram(
        'blinkist_ai_query_duration_seconds',
        'Latency of Gemini AI queries in seconds',
        ['model', 'status'],
        buckets=(0.2, 0.5, 1.0, 2.0, 3.5, 5.0, 8.0, 12.0, 20.0, 30.0),
    )

    # ── 4. Cross-Platform Real-Time Sync Telemetry ───────────────────────────
    ACTIVE_SYNC_SESSIONS = Gauge(
        'blinkist_active_sync_sessions',
        'Currently active cross-platform playback sync sessions',
    )

    SYNC_HANDOFFS_TOTAL = Counter(
        'blinkist_sync_handoffs_total',
        'Total device-to-device playback handoffs executed',
        ['source_device', 'target_device'],
    )

    # ── 5. Monetization & Subscription Funnel Metrics ────────────────────────
    SUBSCRIPTION_EVENTS_TOTAL = Counter(
        'blinkist_subscription_events_total',
        'Subscription conversion, checkout, and webhook events',
        ['plan', 'gateway', 'status'],
    )

else:
    # Lightweight dummy fallback metrics when prometheus_client is not installed
    class _DummyMetric:
        def inc(self, amount: float = 1, *args: Any, **kwargs: Any) -> None:
            pass

        def dec(self, amount: float = 1, *args: Any, **kwargs: Any) -> None:
            pass

        def set(self, value: float, *args: Any, **kwargs: Any) -> None:
            pass

        def observe(self, amount: float, *args: Any, **kwargs: Any) -> None:
            pass

        def labels(self, *args: Any, **kwargs: Any) -> _DummyMetric:
            return self

    AUDIO_STREAMS_TOTAL = _DummyMetric()
    AUDIO_STREAM_DURATION = _DummyMetric()
    SUMMARY_READS_TOTAL = _DummyMetric()
    AI_QUERIES_TOTAL = _DummyMetric()
    AI_QUERY_LATENCY = _DummyMetric()
    ACTIVE_SYNC_SESSIONS = _DummyMetric()
    SYNC_HANDOFFS_TOTAL = _DummyMetric()
    SUBSCRIPTION_EVENTS_TOTAL = _DummyMetric()


def track_ai_latency(model: str = "gemini"):
    """
    Decorator to measure latency and record success/error status for AI tasks.
    """
    def decorator(func: Callable):
        @wraps(func)
        def wrapper(*args, **kwargs):
            start = time.time()
            try:
                res = func(*args, **kwargs)
                duration = time.time() - start
                AI_QUERY_LATENCY.labels(model=model, status="success").observe(duration)
                AI_QUERIES_TOTAL.labels(status="success", model=model).inc()
                return res
            except Exception as e:
                duration = time.time() - start
                AI_QUERY_LATENCY.labels(model=model, status="error").observe(duration)
                AI_QUERIES_TOTAL.labels(status="error", model=model).inc()
                raise e
        return wrapper
    return decorator
