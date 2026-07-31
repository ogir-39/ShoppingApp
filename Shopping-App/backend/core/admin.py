from django.contrib import admin

from apps.account.models import User, Staff, Customer
from apps.cart.models import CartItem, Cart
from apps.catalog.models import Category, Product, ProductImage
from apps.order.models import Order, OrderDetail, OrderStatusLog, Payment
from apps.review.models import Review
from apps.voucher.models import Voucher, VoucherUsage

class MyAdminSite(admin.AdminSite):
    site_header = 'SHOPPING MANAGEMENT SYSTEM'

admin_site = MyAdminSite(name='myadmin')

# Apps ACCOUNT
admin_site.register(User)
admin_site.register(Staff)
admin_site.register(Customer)

# Apps CART
admin_site.register(Cart)
admin_site.register(CartItem)

# Apps CATALOG
admin_site.register(Category)
admin_site.register(Product)
admin_site.register(ProductImage)

# Apps ORDER
admin_site.register(Order)
admin_site.register(OrderDetail)
admin_site.register(OrderStatusLog)
admin_site.register(Payment)

# Apps REVIEW
admin_site.register(Review)

# Apps VOUCHER
admin_site.register(Voucher)
admin_site.register(VoucherUsage)

