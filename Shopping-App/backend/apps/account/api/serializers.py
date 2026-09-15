from django.db import transaction
from rest_framework import serializers
from django.contrib.auth.hashers import check_password

from apps.account.models import Staff, Customer, User, UserRole
from apps.cart.models import Cart

class SimpleUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'role', 'first_name', 'last_name', 'email', 'phone', 'address', 'created_at', 'avatar','is_active']
        read_only_fields = ['id', 'created_at']

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = SimpleUserSerializer.Meta.model
        fields = SimpleUserSerializer.Meta.fields + ['username', 'password']
        extra_kwargs = {
            'password': {'write_only': True}
        }

    # CHỈ CHÈN COINS VÀO KHI ROLE LÀ CUSTOMER
    def to_representation(self, instance):
        data = super().to_representation(instance)
        if instance.role == UserRole.CUSTOMER:
            try:
                data['coins'] = float(instance.customer.coins)
            except Customer.DoesNotExist:
                data['coins'] = 0.0
        return data

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

class CurrentUserSerializer(serializers.ModelSerializer):
    old_password = serializers.CharField(write_only=True, required=False)

    class Meta:
        model = SimpleUserSerializer.Meta.model
        fields = SimpleUserSerializer.Meta.fields + ['username', 'password', 'old_password']
        read_only_fields = ['id', 'role', 'created_at']
        extra_kwargs = {
            'password': {'write_only': True, 'required': False}
        }

    # CHỈ CHÈN COINS VÀO KHI ROLE LÀ CUSTOMER
    def to_representation(self, instance):
        data = super().to_representation(instance)
        if instance.role == UserRole.CUSTOMER:
            try:
                data['coins'] = float(instance.customer.coins)
            except Customer.DoesNotExist:
                data['coins'] = 0.0
        return data

    def update(self, instance, validated_data):
        old_password = validated_data.pop('old_password', None)
        new_password = validated_data.pop('password', None)

        if new_password:
            if not old_password:
                raise serializers.ValidationError({"old_password": "Vui lòng nhập mật khẩu hiện tại."})
            if not check_password(old_password, instance.password):
                raise serializers.ValidationError({"old_password": "Mật khẩu hiện tại không đúng."})
            instance.set_password(new_password)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        instance.save()
        return instance