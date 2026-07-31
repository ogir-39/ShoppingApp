from rest_framework import serializers

from apps.cart.models import Cart, CartItem

class CartItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = CartItem
        fields = '__all__'

class CartSerializer(serializers.ModelSerializer):
    items = CartItemSerializer(required=False,many=True)
    class Meta:
        model = Cart
        fields = ['id','user','updated_at','items']

