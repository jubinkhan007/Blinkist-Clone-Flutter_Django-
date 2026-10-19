from __future__ import annotations

import logging
import json
from django.conf import settings

logger = logging.getLogger(__name__)


def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    action_url: str = '',
    notification_type: str = 'system',
    extra_data: dict | None = None,
) -> dict:
    """
    Sends a push notification via Firebase Cloud Messaging (FCM) v1 / APNs.
    If no FCM credentials are configured, safely logs the payload and returns simulated success.
    """
    if not fcm_token or not fcm_token.strip():
        return {'status': 'skipped', 'reason': 'empty_token'}

    payload = {
        'to': fcm_token.strip(),
        'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
        },
        'data': {
            'action_url': action_url,
            'notification_type': notification_type,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            **(extra_data or {}),
        },
    }

    # If FCM server key or credentials are provided in settings
    fcm_server_key = getattr(settings, 'FCM_SERVER_KEY', None)
    if fcm_server_key:
        try:
            import requests
            headers = {
                'Authorization': f'key={fcm_server_key}',
                'Content-Type': 'application/json',
            }
            resp = requests.post(
                'https://fcm.googleapis.com/fcm/send',
                data=json.dumps(payload),
                headers=headers,
                timeout=5,
            )
            logger.info("FCM push sent to token %s... Status: %s", fcm_token[:10], resp.status_code)
            return {'status': 'sent', 'status_code': resp.status_code, 'response': resp.text}
        except Exception as e:
            logger.warning("FCM push delivery failed: %s", e)
            return {'status': 'error', 'error': str(e)}

    # Default fallback for development/sandbox testing
    logger.info(
        "[PushService-Simulated] Push dispatched to %s... | Title: '%s' | URL: '%s'",
        fcm_token[:12],
        title,
        action_url,
    )
    return {'status': 'simulated_success', 'payload': payload}
