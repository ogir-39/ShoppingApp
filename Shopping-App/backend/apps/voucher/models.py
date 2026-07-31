import datetime

from django.db import models

class VoucherTypeEnum(models.TextChoices):
    DISCOUNT = 'DISCOUNT'
    SHIPPING = 'SHIPPING'

class DiscountTypeEnum(models.TextChoices):
    PERCENT = 'PERCENT'
    AMOUNT = 'AMOUNT'


class Voucher(models.Model):
    code = models.CharField(max_length=10, unique=True)
    voucher_type = models.CharField(max_length=10, choices=VoucherTypeEnum.choices,blank=True,null=True)
    discount_type = models.CharField(max_length=10, choices=DiscountTypeEnum.choices,blank=True,null=True)
    discount_value = models.DecimalField(max_digits=10, decimal_places=2,null=False,blank=False)
    max_discount_value = models.DecimalField(max_digits=10, decimal_places=2,null=False,blank=False)
    min_order_value = models.DecimalField(max_digits=10, decimal_places=2,null=False,blank=False)
    end_date = models.DateTimeField(null=False,blank=False)
    start_date = models.DateTimeField(null=False,blank=False)
    total_usage_limit = models.IntegerField(default=0)
    user_usage_limit = models.IntegerField(default=0)
    used_count = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

class VoucherUsage(models.Model):
    user = models.ForeignKey('account.User', on_delete=models.CASCADE)
    voucher = models.ForeignKey('voucher.Voucher', on_delete=models.CASCADE)
    order = models.ForeignKey('order.Order', on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)