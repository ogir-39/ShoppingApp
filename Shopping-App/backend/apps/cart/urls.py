from django.urls import path, include
from rest_framework.routers import DefaultRouter

from apps.cart.api.views import CartViewSet, CartItemViewSet

router = DefaultRouter()
# router.register('cart', CartViewSet, basename='cart')
router.register('items', CartItemViewSet, basename='cart-item')


urlpatterns = [
    path('', CartViewSet.as_view({'get': 'list'}), name='my-cart'),
    path('', include(router.urls)),
]