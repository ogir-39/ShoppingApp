from django.shortcuts import render
from oauth2_provider.contrib.rest_framework import permissions
from rest_framework import viewsets, generics

from apps.cart.api.serializers import CartItemSerializer, CartSerializer
from apps.cart.models import CartItem, Cart


class CartViewSet(viewsets.ViewSet,generics.ListAPIView,generics.RetrieveAPIView):
    queryset = Cart.objects.all()
    serializer_class = CartSerializer
    permission_classes = [permissions.IsAuthenticated]

class CartItemViewSet(viewsets.ViewSet,generics.ListAPIView,generics.RetrieveAPIView,generics.CreateAPIView,generics.DestroyAPIView,generics.UpdateAPIView):
    queryset = CartItem.objects.all()
    serializer_class = CartItemSerializer
    permission_classes = [permissions.IsAuthenticated]