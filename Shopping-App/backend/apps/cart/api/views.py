from django.shortcuts import render
from django.utils.decorators import method_decorator
from drf_yasg.utils import swagger_auto_schema
from oauth2_provider.contrib.rest_framework import permissions
from rest_framework import viewsets, generics

from apps.cart.api.serializers import CartItemSerializer, CartSerializer
from apps.cart.models import CartItem, Cart


class CartViewSet(viewsets.ViewSet,generics.ListAPIView,generics.RetrieveAPIView):
    serializer_class = CartSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return Cart.objects.none()

        return Cart.objects.filter(user=self.request.user)

@method_decorator(name="list", decorator=swagger_auto_schema(tags=['CartItem']))
@method_decorator(name="create", decorator=swagger_auto_schema(tags=['CartItem']))
@method_decorator(name="update", decorator=swagger_auto_schema(tags=['CartItem']))
@method_decorator(name="partial_update", decorator=swagger_auto_schema(tags=['CartItem']))
@method_decorator(name="destroy", decorator=swagger_auto_schema(tags=['CartItem']))
class CartItemViewSet(viewsets.ModelViewSet):
    serializer_class = CartItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return CartItem.objects.none()

        return CartItem.objects.filter(
            cart__user=self.request.user
        )

    def perform_create(self, serializer):
        cart,_ = Cart.objects.get_or_create(user=self.request.user)
        product = serializer.validated_data['product']

        cart_item, created = CartItem.objects.get_or_create(
            cart=cart,
            product=product,
            defaults={'quantity': 1}
        )

        if not created:
            cart_item.quantity += 1
            cart_item.save()

        serializer.instance = cart_item