from django.contrib.auth.models import AbstractUser
from django.db import models

class UserRole(models.TextChoices):
    ADMIN = 'ADMIN'
    STAFF = 'STAFF'
    CUSTOMER = 'CUSTOMER'

class OrderStatusEnum(models.TextChoices):
    PENDING = 'PENDING'
    SHIPPING = 'SHIPPING'
    COMPLETED = 'COMPLETED'
    CANCELED = 'CANCELED'

class PaymentStatusEnum(models.TextChoices):
    UNPAID = 'UNPAID'
    PAID = 'PAID'

class VoucherTypeEnum(models.TextChoices):
    DISCOUNT = 'DISCOUNT'
    SHIPPING = 'SHIPPING'

class DiscountTypeEnum(models.TextChoices):
    PERCENT = 'PERCENT'
    AMOUNT = 'AMOUNT'


class User(AbstractUser):
    role = models.CharField(max_length=20, choices=UserRole.choices, default=UserRole.CUSTOMER)
    address = models.CharField(max_length=200, null=False, blank=False)
    phone = models.CharField(max_length=20, null=False, blank=False)
    created_at = models.DateTimeField(auto_now_add=True)


class Customer(models.Model):
    user = models.OneToOneField('account.User', on_delete=models.CASCADE, primary_key=True)
    coins = models.DecimalField(max_digits=10, decimal_places=2, default=0)


class Staff(models.Model):
    user = models.OneToOneField('account.User', on_delete=models.CASCADE, primary_key=True)
    salary = models.DecimalField(max_digits=10, decimal_places=2, default=0)

class Cart(models.Model):
    user = models.OneToOneField('account.User', on_delete=models.CASCADE)
    updated_at = models.DateTimeField(auto_now=True)

class CartItem(models.Model):
    cart = models.ForeignKey('cart.Cart', on_delete=models.CASCADE)
    product = models.ForeignKey('catalog.Product', on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint( #Khách sẽ thấy 2 dòng áo thay vì 1 dòng số lượng 2 nếu ko có contrainst này
                fields=['cart', 'product'],
                name='unique_cart_product'
            )
        ]


class Category(models.Model):
    name = models.CharField(max_length=50, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class Product(models.Model):
    category = models.ForeignKey('catalog.Category', on_delete=models.CASCADE)
    name = models.CharField(max_length=150,null=False, blank=False)
    description = models.TextField(max_length=500)
    cost_price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    sell_price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    stock_quantity = models.PositiveIntegerField(default=0)
    weight = models.FloatField(default=0)
    thumbnail = models.CharField(max_length=500)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class ProductImage(models.Model):
    product = models.ForeignKey('catalog.Product', on_delete=models.CASCADE)
    img = models.CharField(max_length=500)
    created_at = models.DateTimeField(auto_now_add=True)

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

class Review(models.Model):
    user = models.ForeignKey('account.User', on_delete=models.CASCADE)
    order_item = models.OneToOneField('order.OrderDetail', on_delete=models.CASCADE)
    product = models.ForeignKey('catalog.Product', on_delete=models.CASCADE)
    comment = models.TextField(max_length=500)
    rating = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

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