from rest_framework import serializers

from apps.cart.models import Cart, CartItem


class CartItemSerializer(serializers.ModelSerializer):
    cart = serializers.PrimaryKeyRelatedField(read_only=True)
    sell_price= serializers.DecimalField(source='product.sell_price',max_digits=10,decimal_places=2,read_only=True)
    total_price = serializers.SerializerMethodField()
    product_name = serializers.ReadOnlyField(source='product.name')
    class Meta:
        model = CartItem
        fields = '__all__'

    def get_total_price(self, obj):
        return obj.quantity * obj.product.sell_price

class CartSerializer(serializers.ModelSerializer):
    items = CartItemSerializer(source='cartitem_set',required=False,many=True)
    total_quantity = serializers.SerializerMethodField()
    class Meta:
        model = Cart
        fields = ['id','user','updated_at','items','total_quantity']

    def get_total_quantity(self, obj):
        return sum(item.quantity for item in obj.cartitem_set.all())