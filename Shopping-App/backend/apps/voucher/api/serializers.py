from rest_framework import serializers

from apps.voucher.models import Voucher, VoucherUsage

class VoucherSerializer(serializers.ModelSerializer):
    class Meta:
        model = Voucher
        fields = '__all__'
        read_only_fields = ['id', 'used_count', 'created_at']