from rest_framework import serializers
from apps.order.models import Order, OrderDetail, Payment
from apps.review.models import Review # QUAN TRỌNG: Nhớ import model Review

class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = '__all__'

class OrderDetailSerializer(serializers.ModelSerializer):
    product_name = serializers.ReadOnlyField(source='product.name')
    # THÊM TRƯỜNG NÀY:
    is_reviewed = serializers.SerializerMethodField()

    class Meta:
        model = OrderDetail
        fields = '__all__'

    # KIỂM TRA XEM ORDER_ITEM NÀY ĐÃ CÓ TRONG BẢNG REVIEW CHƯA
    def get_is_reviewed(self, obj):
        return Review.objects.filter(order_item=obj).exists()

class OrderSerializer(serializers.ModelSerializer):
    details = OrderDetailSerializer(source='orderdetail_set', many=True, required=False)
    payment = PaymentSerializer(required=False)
    class Meta:
        model = Order
        fields = '__all__'