from django.db import models

class OrderStatusEnum(models.TextChoices):
    PENDING = 'PENDING'
    SHIPPING = 'SHIPPING'
    COMPLETED = 'COMPLETED'
    CANCELED = 'CANCELED'

class PaymentStatusEnum(models.TextChoices):
    UNPAID = 'UNPAID'
    PAID = 'PAID'


class Order(models.Model):
    user = models.ForeignKey('account.User', on_delete=models.CASCADE)
    discount_voucher = models.ForeignKey('voucher.Voucher', on_delete=models.SET_NULL,related_name='discount_voucher', null=True,blank=True)
    shipping_voucher = models.ForeignKey('voucher.Voucher', on_delete=models.SET_NULL,related_name='shipping_voucher', null=True,blank=True)
    status = models.CharField(max_length=20,choices=OrderStatusEnum.choices, default=OrderStatusEnum.PENDING)
    payment_status = models.CharField(max_length=20,choices=PaymentStatusEnum.choices,default=PaymentStatusEnum.UNPAID)
    recipient_name= models.CharField(max_length=50,null=False,blank=False)
    recipient_phone = models.CharField(max_length=15,null=False,blank=False)
    shipping_address = models.TextField(max_length=500,null=False,blank=False)
    coin_used = models.DecimalField(max_digits=10, decimal_places=2)
    coin_earned = models.DecimalField(max_digits=10, decimal_places=2)
    discount_voucher_amount = models.DecimalField(max_digits=10, decimal_places=2)
    shipping_voucher_amount = models.DecimalField(max_digits=10, decimal_places=2)
    final_amount = models.DecimalField(max_digits=10, decimal_places=2)
    cancellation_reason = models.TextField(max_length=150)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class OrderDetail(models.Model):
    order = models.ForeignKey('order.Order', on_delete=models.CASCADE)
    product = models.ForeignKey('catalog.Product', on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=0)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

class OrderStatusLog(models.Model):
    order = models.ForeignKey('order.Order', on_delete=models.CASCADE)
    old_status = models.CharField(max_length=20,choices=OrderStatusEnum.choices)
    new_status = models.CharField(max_length=20, choices=OrderStatusEnum.choices)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class Payment(models.Model):
    order = models.ForeignKey('order.Order', on_delete=models.CASCADE)
    transaction_id = models.CharField(max_length=200)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20,choices= PaymentStatusEnum.choices, default=PaymentStatusEnum.UNPAID)

