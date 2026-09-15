from rest_framework import serializers
from apps.review.models import Review

class ReviewSerializer(serializers.ModelSerializer):
    user = serializers.ReadOnlyField(source='user.id')
    username = serializers.ReadOnlyField(source='user.username')

    class Meta:
        model = Review
        fields = '__all__'
        read_only_fields = ['id','user','product','created_at','updated_at','username']
        # THÊM ĐOẠN NÀY ĐỂ VIỆT HÓA LỖI TRÙNG LẶP
        extra_kwargs = {
            'order_item': {
                'error_messages': {
                    'unique': 'Bạn đã đánh giá sản phẩm này rồi!'
                }
            }
        }

    def validate_order_item(self, order_item):
        request = self.context['request']
        if order_item.order.user != request.user or order_item.order.status != 'COMPLETED':
            raise serializers.ValidationError(
                "Bạn chỉ được đánh giá sản phẩm mình đã mua!"
            )
        return order_item

    def create(self, validated_data):
        order_item = validated_data['order_item']
        validated_data['product'] = order_item.product
        return super().create(validated_data)