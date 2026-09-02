import datetime

from django.db import models
from rest_framework.exceptions import ValidationError


class VoucherTypeEnum(models.TextChoices):
    DISCOUNT = 'DISCOUNT'
    SHIPPING = 'SHIPPING'

class DiscountTypeEnum(models.TextChoices):
    PERCENT = 'PERCENT'
    AMOUNT = 'AMOUNT'


class Voucher(models.Model):
    code = models.CharField(max_length=10, unique=True)
    voucher_type = models.CharField(max_length=10, choices=VoucherTypeEnum.choices)
    discount_type = models.CharField(max_length=10, choices=DiscountTypeEnum.choices)

    discount_value = models.DecimalField(max_digits=10, decimal_places=2,null=False,blank=False) #Giá trị giảm của voucher (Ví dụ voucher giảm 10% thì discount_value=order.total_amount * 10%)
    max_discount_value = models.DecimalField(max_digits=10, decimal_places=2,null=False,blank=False) #Với voucher giảm 10% có max_discount_value = 20.000 VNĐ, thì nếu discount_value > 20.000 thì discount_value = 20.000
    min_order_value = models.DecimalField(max_digits=10, decimal_places=2,null=False,blank=False) #Điều kiện để customer dùng được voucher đó, chỉ các đơn hàng có giá trị từ min_order_value trở lên mới được dùng voucher này
    end_date = models.DateTimeField(null=False,blank=False) #Ngày hết hạn, qua ngày hết hạn thì is_active=FALSE
    start_date = models.DateTimeField(null=False,blank=False) #Ngày bắt đầu, tới ngày bắt đầu thì is_active=TRUE
    total_usage_limit = models.PositiveIntegerField() #Tổng số lần TỐI ĐA voucher này dược sử dụng bởi TẤT CẢ các customer
    user_usage_limit = models.PositiveIntegerField() #Số lần tối đa mà 1 customer có thể sử dụng voucher này
    used_count = models.PositiveIntegerField(default=0) #Tổng số lầnvoucher này đã dược sử dụng bởi TẤT CẢ các customer
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def clean(self):
        if self.discount_type == DiscountTypeEnum.PERCENT and (self.discount_value > 100 or self.discount_value <= 0):
            raise ValidationError({'discount_value':['Value must be between 0 and 100']})
        if self.discount_type == DiscountTypeEnum.AMOUNT and (self.discount_value <= 0):
            raise ValidationError({'discount_value':['Value must be greater than 0']})
        if self.max_discount_value <= 0:
            raise ValidationError({'max_discount_value':['Value must be greater than 0']})
        if self.min_order_value <= 0:
            raise ValidationError({'min_order_value':['Value must be greater than 0']})
        if self.end_date < self.start_date:
            raise ValidationError({'end_date':['End date must be greater than or equal to start_date']})

class VoucherUsage(models.Model):
    user = models.ForeignKey('account.User', on_delete=models.CASCADE)
    voucher = models.ForeignKey('voucher.Voucher', on_delete=models.CASCADE)
    order = models.ForeignKey('order.Order', on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["order", "voucher"],
                name="unique_order_voucher"
            )
        ]