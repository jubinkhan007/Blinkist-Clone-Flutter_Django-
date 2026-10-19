from django.urls import path
from .views import (
    NotificationListView,
    MarkNotificationReadView,
    MarkAllNotificationsReadView,
    UnreadNotificationCountView,
    NotificationPreferenceView,
    NotificationDeleteView,
    SimulateNotificationView,
    RegisterDeviceTokenView,
    DispatchMorningDigestView,
    DispatchEveningStreakView,
)

urlpatterns = [
    path('', NotificationListView.as_view(), name='notification_list'),
    path('<int:pk>/', NotificationDeleteView.as_view(), name='notification_delete'),
    path('<int:pk>/read/', MarkNotificationReadView.as_view(), name='notification_mark_read'),
    path('read-all/', MarkAllNotificationsReadView.as_view(), name='notification_read_all'),
    path('unread-count/', UnreadNotificationCountView.as_view(), name='notification_unread_count'),
    path('preferences/', NotificationPreferenceView.as_view(), name='notification_preferences'),
    path('register-token/', RegisterDeviceTokenView.as_view(), name='notification_register_token'),
    path('dispatch-morning-digest/', DispatchMorningDigestView.as_view(), name='notification_dispatch_morning_digest'),
    path('dispatch-evening-streak/', DispatchEveningStreakView.as_view(), name='notification_dispatch_evening_streak'),
    path('simulate/', SimulateNotificationView.as_view(), name='notification_simulate'),
]
