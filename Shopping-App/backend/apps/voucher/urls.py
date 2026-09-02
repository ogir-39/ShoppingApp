from django.urls import path, include
from rest_framework.routers import DefaultRouter

from apps.voucher.api.views import VoucherViewSet

router = DefaultRouter()
router.register('', VoucherViewSet, basename='voucher')

urlpatterns = [
    path('', include(router.urls)),
]