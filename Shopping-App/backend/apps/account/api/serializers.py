from django.db import transaction
from rest_framework import serializers, permissions

from apps import cart
from apps.account.models import Staff, Customer, User, UserRole
from apps.cart.models import Cart
from core.permissions import IsStaffOrAdmin

class SimpleUserSerializer(serializers.ModelSerializer): #STAFF
    class Meta:
        model = User
        fields = ['id', 'role', 'first_name', 'last_name', 'email', 'phone', 'address','created_at','avatar']

        read_only_fields = ['id', 'role', 'created_at']

class UserSerializer(serializers.ModelSerializer): #ADMIN
    class Meta:
        model = SimpleUserSerializer.Meta.model
        fields = SimpleUserSerializer.Meta.fields + ['username', 'password']
        extra_kwargs = {
            'password': {
                'write_only': True
            }
        }

    def create(self, validated_data):
        with transaction.atomic():
            user = User(**validated_data)

            user.set_password(user.password)
            user.save()

            if user.role == UserRole.CUSTOMER:
                Customer.objects.create(user=user)
                Cart.objects.create(user=user)
            elif user.role == UserRole.STAFF:
                Staff.objects.create(user=user)

            return user

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        if password:
            instance.set_password(password)

        instance.save()
        return instance

class CurrentUserSerializer(serializers.ModelSerializer): #CURENT-USER
    class Meta:
        model = SimpleUserSerializer.Meta.model
        fields = SimpleUserSerializer.Meta.fields + ['username', 'password']

        read_only_fields = ['id', 'role', 'created_at']

        extra_kwargs = {
            'password': {
                'write_only': True,
                'required': False
            }
        }

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        if password:
            instance.set_password(password)

        instance.save()
        return instance