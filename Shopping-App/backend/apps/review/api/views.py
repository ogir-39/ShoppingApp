from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import viewsets, permissions

from apps.review.api.serializers import ReviewSerializer
from apps.review.models import Review
from core.permissions import ReviewPermission


class ReviewViewSet(viewsets.ModelViewSet):
    queryset = Review.objects.all()
    serializer_class = ReviewSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['product']

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS:
            return [permissions.AllowAny()]

        return [ReviewPermission()]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def perform_update(self, serializer):
        serializer.save(user=self.request.user)