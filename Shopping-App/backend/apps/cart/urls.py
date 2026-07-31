from django.urls import path, include
from rest_framework.routers import DefaultRouter

from apps.cart.api.views import CartViewSet, CartItemViewSet

router = DefaultRouter()
router.register('cart', CartViewSet, basename='cart')
router.register('cartitem', CartItemViewSet, basename='cartitem')


urlpatterns = [
    path('', include(router.urls)),
]