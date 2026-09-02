from oauth2_provider.contrib.rest_framework import permissions
from rest_framework import viewsets, generics, status
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.account.models import UserRole
from apps.notification.api.serializers import NotificationSerializer
from apps.notification.models import Notification


class NotificationViewSet(viewsets.ViewSet, generics.ListAPIView, generics.CreateAPIView):
    queryset = Notification.objects.all()
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if not user.is_authenticated:
            return Notification.objects.none()

        if user.role == UserRole.ADMIN:
            return Notification.objects.all()

        return Notification.objects.filter(user=user)

    def perform_create(self, serializer):
        return serializer.save(user=self.request.user)

    @action(methods=['patch'],detail=True,url_path='read')
    def mark_as_read(self, request, pk=None):
        notification = self.get_object()

        # Không cho user đánh dấu notification của người khác
        if (
                request.user.role != UserRole.ADMIN
                and notification.user != request.user
        ):
            return Response({"detail": "You do not have permission to modify this notification."},status=status.HTTP_403_FORBIDDEN)

        notification.is_read = True
        notification.save(update_fields=['is_read'])

        return Response(NotificationSerializer(notification).data,status=status.HTTP_200_OK)

    @action(methods=['patch'],detail=False,url_path='read-all')
    def mark_all_as_read(self, request):
        updated_count = Notification.objects.filter(
            user=request.user,
            is_read=False
        ).update(is_read=True)

        return Response({"message": "All notifications marked as read.","updated_count": updated_count})
