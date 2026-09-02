from rest_framework import serializers

from apps.order.models import Order, OrderDetail, Payment


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = '__all__'

class OrderDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderDetail
        fields = '__all__'

class OrderSerializer(serializers.ModelSerializer):
    details = OrderDetailSerializer(source='orderdetail_set',many=True,required=False)
    payment = PaymentSerializer(required=False)
    class Meta:
        model = Order
        fields = '__all__'

