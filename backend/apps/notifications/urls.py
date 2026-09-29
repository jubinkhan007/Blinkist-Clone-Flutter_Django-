from django.urls import path
from .views import (
    NotificationListView,
    MarkNotificationReadView,
    MarkAllNotificationsReadView,
    UnreadNotificationCountView,
    NotificationPreferenceView,
)

urlpatterns = [
    path('', NotificationListView.as_view(), name='notification_list'),
    path('<int:pk>/read/', MarkNotificationReadView.as_view(), name='notification_mark_read'),
    path('read-all/', MarkAllNotificationsReadView.as_view(), name='notification_read_all'),
    path('unread-count/', UnreadNotificationCountView.as_view(), name='notification_unread_count'),
    path('preferences/', NotificationPreferenceView.as_view(), name='notification_preferences'),
]
