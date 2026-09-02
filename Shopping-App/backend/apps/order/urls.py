from django.urls import path, include
from rest_framework.routers import DefaultRouter

from apps.order.api.views import OrderViewSet, OrderDetailViewSet, PaymentViewSet

router = DefaultRouter()
router.register('', OrderViewSet, basename='order')
router.register('orders-details', OrderDetailViewSet, basename='orderdetail')
router.register('payments', PaymentViewSet, basename='payment')

urlpatterns = [
    path('', include(router.urls)),
]