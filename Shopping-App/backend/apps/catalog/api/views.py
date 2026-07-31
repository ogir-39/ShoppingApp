from django.shortcuts import render
from django.utils.decorators import method_decorator
from drf_yasg.utils import swagger_auto_schema
from rest_framework import viewsets, generics

from apps.catalog.api.serializers import CategorySerializer, ProductSerializer, ProductImageSerializer
from apps.catalog.models import Product, Category, ProductImage
from core.permissions import IsStaffOrAdmin


@method_decorator(name="list", decorator=swagger_auto_schema(tags=['category']))
@method_decorator(name="create", decorator=swagger_auto_schema(tags=['category']))
@method_decorator(name="update", decorator=swagger_auto_schema(tags=['category']))
@method_decorator(name="partial_update", decorator=swagger_auto_schema(tags=['category']))
class CategoryViewSet(viewsets.ViewSet,generics.ListAPIView,generics.CreateAPIView,generics.UpdateAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [IsStaffOrAdmin]

@method_decorator(name="list", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="create", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="update", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="partial_update", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="retrieve", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="destroy", decorator=swagger_auto_schema(tags=['product']))
class ProductViewSet(viewsets.ViewSet,generics.ListAPIView,generics.CreateAPIView,generics.UpdateAPIView,generics.RetrieveAPIView,generics.DestroyAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [IsStaffOrAdmin]

@method_decorator(name="list", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="create", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="update", decorator=swagger_auto_schema(tags=['product']))
@method_decorator(name="partial_update", decorator=swagger_auto_schema(tags=['product']))
class ProductImageViewSet(viewsets.ViewSet,generics.ListAPIView,generics.CreateAPIView,generics.UpdateAPIView):
    queryset = ProductImage.objects.all()
    serializer_class = ProductImageSerializer
    permission_classes = [IsStaffOrAdmin]