from django.urls import path, include
from rest_framework.routers import DefaultRouter

from apps.catalog.api.views import CategoryViewSet, ProductViewSet, ProductImageViewSet

router = DefaultRouter()
router.register('categories', CategoryViewSet, basename='category')
router.register('products', ProductViewSet, basename='product')
router.register('product-images', ProductImageViewSet, basename='productimage')

urlpatterns = [
    path('', include(router.urls)),
]