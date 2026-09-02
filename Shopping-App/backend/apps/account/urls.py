from django.urls import path, include
from rest_framework.routers import DefaultRouter

from apps.account.api.views import UserViewSet

router = DefaultRouter()
router.register('', UserViewSet, basename='Account')

urlpatterns = [
    path('', include(router.urls)),
]