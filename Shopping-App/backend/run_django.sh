#!/bin/bash

# Ép Python sử dụng UTF-8 trên mọi môi trường terminal
export PYTHONUTF8=1

# Tùy chỉnh lại tên Database thành shoppingdb theo dự án của bạn
"/c/Program Files/MySQL/MySQL Server 9.4/bin/mysql.exe" -u root -p123456 -e "DROP DATABASE IF EXISTS shoppingdb; CREATE DATABASE shoppingdb;"

echo "=== 1. Cài đặt thư viện từ requirements.txt ==="
pip install -r requirements.txt

echo "=== 2. Thực thi migrate cơ sở dữ liệu ==="
# Cập nhật danh sách các app của Shopping App
python manage.py makemigrations account cart catalog order review voucher
python manage.py migrate account
python manage.py migrate cart
python manage.py migrate catalog
python manage.py migrate order
python manage.py migrate review
python manage.py migrate voucher
python manage.py migrate

echo "=== 3. Tạo Superuser (Admin) tự động ==="
export DJANGO_SUPERUSER_USERNAME=admin
export DJANGO_SUPERUSER_EMAIL=admin@shopping.com
export DJANGO_SUPERUSER_PASSWORD=123

python manage.py createsuperuser --no-input || echo "SuperUser đã tồn tại!"

echo "=== 4. Chèn dữ liệu mẫu cho hệ thống Mua sắm ==="
python manage.py shell << 'EOF'
import random
from django.utils import timezone
from datetime import timedelta
from django.apps import apps
from django.contrib.auth import get_user_model
from django.db import transaction

# Tải các Model từ hệ thống Shopping App
User = get_user_model()
Customer = apps.get_model('account', 'Customer')
Staff = apps.get_model('account', 'Staff')
Category = apps.get_model('catalog', 'Category')
Product = apps.get_model('catalog', 'Product')
Voucher = apps.get_model('voucher', 'Voucher')
Order = apps.get_model('order', 'Order')
OrderDetail = apps.get_model('order', 'OrderDetail')
Payment = apps.get_model('order', 'Payment')
Review = apps.get_model('review', 'Review')

today = timezone.now()

print(">>> Đang tạo dữ liệu Master Data: Danh mục & Sản phẩm...")
c_tech, _ = Category.objects.get_or_create(name='Điện thoại & Laptop')
c_home, _ = Category.objects.get_or_create(name='Đồ gia dụng')
c_fashion, _ = Category.objects.get_or_create(name='Thời trang')

products_data = [
    (c_tech, 'iPhone 15 Pro Max 256GB', 'Điện thoại Apple cao cấp', 25000000, 29000000, 50, 0.2),
    (c_tech, 'MacBook Pro M3 14 inch', 'Laptop Apple chuyên nghiệp', 35000000, 39990000, 20, 1.6),
    (c_home, 'Nồi chiên không dầu Philips', 'Dung tích 5L, công suất 2000W', 1500000, 2200000, 100, 5.0),
    (c_fashion, 'Áo thun nam Cotton', 'Thoáng mát, thấm hút tốt', 80000, 150000, 200, 0.2),
]

for cat, name, desc, cost, sell, qty, weight in products_data:
    Product.objects.get_or_create(
        name=name,
        defaults={
            'category': cat, 'description': desc, 'cost_price': cost,
            'sell_price': sell, 'stock_quantity': qty, 'weight': weight, 'thumbnail': 'default.png'
        }
    )

print(">>> Đang tạo dữ liệu Tài khoản (Staff & Customer)...")
for i in range(1, 4):
    username = f'staff{i}'
    if not User.objects.filter(username=username).exists():
        u = User.objects.create_user(username=username, password='123', role='STAFF', address='Store', phone=f'090000010{i}')
        Staff.objects.create(user=u, salary=10000000 + (i * 1000000))

customers = []
for i in range(1, 11):
    username = f'customer{i}'
    if not User.objects.filter(username=username).exists():
        u = User.objects.create_user(username=username, password='123', role='CUSTOMER', address=f'12{i} CMT8, HCM', phone=f'09888880{i:02d}')
        cust = Customer.objects.create(user=u, coins=random.choice([0, 10000, 50000]))
        customers.append(cust)

print(">>> Đang tạo dữ liệu Voucher...")
v_discount, _ = Voucher.objects.get_or_create(
    code='SALE10',
    defaults={
        'voucher_type': 'DISCOUNT', 'discount_type': 'PERCENT', 'discount_value': 10,
        'max_discount_value': 50000, 'min_order_value': 100000,
        'start_date': today, 'end_date': today + timedelta(days=30),
        'total_usage_limit': 100, 'user_usage_limit': 1
    }
)

v_ship, _ = Voucher.objects.get_or_create(
    code='FREESHIP',
    defaults={
        'voucher_type': 'SHIPPING', 'discount_type': 'AMOUNT', 'discount_value': 30000,
        'max_discount_value': 30000, 'min_order_value': 150000,
        'start_date': today, 'end_date': today + timedelta(days=30),
        'total_usage_limit': 500, 'user_usage_limit': 2
    }
)

print(">>> Đang tạo dữ liệu Đơn hàng (Orders & OrderDetails)...")
all_products = list(Product.objects.all())
all_users = [c.user for c in Customer.objects.all()]

orders_to_create = []
for i in range(20):
    user = random.choice(all_users)
    order = Order.objects.create(
        user=user,
        status=random.choice(['COMPLETED', 'PENDING', 'SHIPPING']),
        payment_status=random.choice(['PAID', 'UNPAID']),
        recipient_name=user.username,
        recipient_phone=user.phone,
        shipping_address=user.address,
        coin_used=0,
        coin_earned=1000,
        discount_voucher_amount=0,
        shipping_voucher_amount=0,
        final_amount=0,
    )

    # Thêm sản phẩm vào đơn hàng
    num_items = random.randint(1, 3)
    order_total = 0
    for _ in range(num_items):
        prod = random.choice(all_products)
        qty = random.randint(1, 2)
        price = prod.sell_price
        order_total += price * qty
        OrderDetail.objects.create(order=order, product=prod, quantity=qty, price=price)

    # Cập nhật tổng tiền đơn hàng
    order.final_amount = order_total
    order.save()

    # Tạo thanh toán nếu đã PAID
    if order.payment_status == 'PAID':
        Payment.objects.create(order=order, transaction_id=f'TXN{order.id}{random.randint(1000,9999)}', amount=order_total, status='PAID')

        # Nếu đã hoàn thành thì tạo Review ngẫu nhiên
        if order.status == 'COMPLETED' and random.random() > 0.5:
            first_item = order.orderdetail_set.first()
            if not Review.objects.filter(order_item=first_item).exists():
                Review.objects.create(
                    user=user, order_item=first_item, product=first_item.product,
                    rating=random.randint(4, 5), comment="Sản phẩm rất tốt, giao hàng nhanh!"
                )

print(">>> TẤT CẢ DỮ LIỆU ĐÃ ĐƯỢC KHỞI TẠO THÀNH CÔNG!")
EOF

echo "=== 5. Chạy server Django ==="
python manage.py runserver