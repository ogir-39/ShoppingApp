from django.db import transaction
from rest_framework import serializers, permissions

from apps import cart
from apps.account.models import Staff, Customer, User, UserRole
from apps.cart.models import Cart
from core.permissions import IsStaffOrAdmin

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username','password','role', 'first_name', 'last_name', 'email', 'phone', 'address','created_at']
        extra_kwargs = {
            'password': {
                'write_only': True
            }
        }

    def create(self, validated_data):
        with transaction.atomic():
            user = User.objects.create_user(**validated_data)
            if user.role == UserRole.CUSTOMER:
                Customer.objects.create(user=user)
                Cart.objects.create(user=user)
            elif user.role == UserRole.STAFF:
                Staff.objects.create(user=user)
                Cart.objects.create(user=user)

            return user