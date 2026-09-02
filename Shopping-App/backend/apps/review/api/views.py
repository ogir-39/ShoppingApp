from oauth2_provider.contrib.rest_framework import permissions
from rest_framework import viewsets

from apps.review.api.serializers import ReviewSerializer
from apps.review.models import Review
from core.permissions import ReviewPermission


class ReviewViewSet(viewsets.ModelViewSet):
    queryset = Review.objects.all()
    serializer_class = ReviewSerializer
    permission_classes = [ReviewPermission]

    def get_queryset(self):
        u = self.request.user
        if not u.is_authenticated:
            return Review.objects.none()

        if u.is_superuser or u.role in ['ADMIN', 'STAFF']:
            return Review.objects.all()

        return Review.objects.filter(user=u)

    def perform_update(self, serializer):
        serializer.save(user=self.request.user)