import django_filters
from django.shortcuts import render
from django.utils.decorators import method_decorator
from django_filters.rest_framework import DjangoFilterBackend
from drf_yasg.utils import swagger_auto_schema
from rest_framework import viewsets, generics, request, permissions, filters

from apps.catalog.api.serializers import CategorySerializer, ProductSerializer, ProductImageSerializer
from apps.catalog.models import Product, Category, ProductImage
from core import paginators
from core.permissions import IsStaffOrAdmin

class ProductFilter(django_filters.FilterSet):
    stock_lt = django_filters.NumberFilter(field_name="stock_quantity", lookup_expr='lt') # Tìm stock_quantity < (less than)

    class Meta:
        model = Product
        fields = ['category', 'is_active', 'stock_lt']

@method_decorator(name="list", decorator=swagger_auto_schema(tags=['category']))
@method_decorator(name="create", decorator=swagger_auto_schema(tags=['category']))
@method_decorator(name="update", decorator=swagger_auto_schema(tags=['category']))
@method_decorator(name="partial_update", decorator=swagger_auto_schema(tags=['category']))
class CategoryViewSet(viewsets.ViewSet,generics.ListAPIView,generics.CreateAPIView,generics.UpdateAPIView):
    queryset = Category.objects.order_by('name')
    serializer_class = CategorySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter,filters.OrderingFilter]
    filterset_fields = ['name']
    search_fields = ['name']
    ordering_fields = ['name']

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS:
            return [permissions.AllowAny()]

        return [IsStaffOrAdmin()]

@method_decorator(name="list", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="create", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="update", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="partial_update", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="retrieve", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="destroy", decorator=swagger_auto_schema(tags=['product']))
class ProductViewSet(viewsets.ViewSet,generics.ListAPIView,generics.CreateAPIView,generics.UpdateAPIView,generics.RetrieveAPIView,generics.DestroyAPIView):
    serializer_class = ProductSerializer
    pagination_class = paginators.ItemPaginator
    filter_backends = [filters.SearchFilter,DjangoFilterBackend]
    filterset_fields = ['is_active']
    filterset_class = ProductFilter
    search_fields = ['name']

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS:
            return [permissions.AllowAny()]

        return [IsStaffOrAdmin()]

    def get_queryset(self):
        user = self.request.user
        if user.is_authenticated and user.role in ['ADMIN', 'STAFF']:
            return Product.objects.all()
        return Product.objects.filter(stock_quantity__gt=0)

@method_decorator(name="list", decorator=swagger_auto_schema(tags=['ProductImage']))
@method_decorator(name="create", decorator=swagger_auto_schema(tags=['ProductImage']))
@method_decorator(name="update", decorator=swagger_auto_schema(tags=['ProductImage']))
@method_decorator(name="partial_update", decorator=swagger_auto_schema(tags=['ProductImage']))
class ProductImageViewSet(viewsets.ViewSet,generics.ListAPIView,generics.CreateAPIView,generics.UpdateAPIView):
    queryset = ProductImage.objects.all()
    serializer_class = ProductImageSerializer

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS:
            return [permissions.AllowAny()]

        return [IsStaffOrAdmin()]