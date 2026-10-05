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

