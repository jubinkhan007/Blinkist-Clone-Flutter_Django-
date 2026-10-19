from rest_framework import views, generics, permissions, response, status
from django.shortcuts import get_object_or_404
from .models import Notification, NotificationPreference
from .serializers import NotificationSerializer, NotificationPreferenceSerializer


class NotificationListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = NotificationSerializer

    def get_queryset(self):
        qs = Notification.objects.filter(user=self.request.user)
        if self.request.query_params.get('unread') == 'true':
            qs = qs.filter(is_read=False)
        return qs


class MarkNotificationReadView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        notification = get_object_or_404(Notification, pk=pk, user=request.user)
        notification.is_read = True
        notification.save(update_fields=['is_read'])
        return response.Response({'status': 'marked_read', 'id': notification.id})


class MarkAllNotificationsReadView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        updated_count = Notification.objects.filter(
            user=request.user, is_read=False
        ).update(is_read=True)
        return response.Response({
            'status': 'all_marked_read',
            'updated_count': updated_count,
        })


class UnreadNotificationCountView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        count = Notification.objects.filter(
            user=request.user, is_read=False
        ).count()
        return response.Response({'unread_count': count})


class NotificationPreferenceView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        pref, _ = NotificationPreference.objects.get_or_create(user=request.user)
        return response.Response(NotificationPreferenceSerializer(pref).data)

    def patch(self, request):
        pref, _ = NotificationPreference.objects.get_or_create(user=request.user)
        serializer = NotificationPreferenceSerializer(pref, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return response.Response(serializer.data)


class NotificationDeleteView(generics.DestroyAPIView):
    """Allows user to delete a single notification from their inbox."""
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)


class SimulateNotificationView(views.APIView):
    """Developer/testing endpoint to trigger a simulated notification for the current user."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        notification_type = request.data.get('notification_type', Notification.NotificationType.SYSTEM)
        title = request.data.get('title', '🔔 Test Notification')
        message = request.data.get('message', 'This is a test notification generated for testing deep linking.')
        action_url = request.data.get('action_url', '/explore')

        valid_types = [choice[0] for choice in Notification.NotificationType.choices]
        if notification_type not in valid_types:
            notification_type = Notification.NotificationType.SYSTEM

        notification = Notification.objects.create(
            user=request.user,
            title=title,
            message=message,
            notification_type=notification_type,
            action_url=action_url,
        )
        return response.Response(
            NotificationSerializer(notification).data,
            status=status.HTTP_201_CREATED,
        )


class RegisterDeviceTokenView(views.APIView):
    """Allows mobile client to register or update their FCM / APNs device push token."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        fcm_token = request.data.get('fcm_token', '').strip()
        if not fcm_token:
            return response.Response(
                {'error': 'fcm_token is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        pref, _ = NotificationPreference.objects.get_or_create(user=request.user)
        pref.fcm_token = fcm_token
        pref.save(update_fields=['fcm_token', 'updated_at'])

        return response.Response({
            'status': 'token_registered',
            'fcm_token': fcm_token,
        })


class DispatchMorningDigestView(views.APIView):
    """Admin/developer trigger to dispatch morning Daily Digest alerts immediately."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        from .tasks import dispatch_daily_digest_notifications
        count = dispatch_daily_digest_notifications()
        return response.Response({
            'status': 'morning_digest_dispatched',
            'created_count': count,
        })


class DispatchEveningStreakView(views.APIView):
    """Admin/developer trigger to dispatch evening streak-saver reminders with recommendations."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        from .tasks import dispatch_evening_streak_saver_notifications
        count = dispatch_evening_streak_saver_notifications()
        return response.Response({
            'status': 'evening_streak_saver_dispatched',
            'created_count': count,
        })


