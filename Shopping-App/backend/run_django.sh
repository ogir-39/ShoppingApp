#!/bin/bash

# Ép Python sử dụng UTF-8 trên mọi môi trường terminal
export PYTHONUTF8=1

echo "=== 1. Xóa và Tạo lại Database ==="
# ĐÃ SỬA ĐƯỜNG DẪN THÀNH MySQL Server 8.0 THEO ẢNH CỦA BẠN
"/c/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -p123456 -e "DROP DATABASE IF EXISTS shoppingdb; CREATE DATABASE shoppingdb;"

echo "=== 2. Cài đặt thư viện từ requirements.txt ==="
pip install -r requirements.txt

echo "=== 3. Dọn dẹp file migration cũ ==="
find . -path "*/migrations/*.py" -not -name "__init__.py" -delete
find . -path "*/migrations/*.pyc"  -delete

echo "=== 4. Khởi tạo và Migrate cơ sở dữ liệu ==="
# Để trống để Django tự động dò tìm và sắp xếp tất cả các app
python manage.py makemigrations
python manage.py migrate

echo "=== 5. Tạo Superuser (Admin) tự động ==="
export DJANGO_SUPERUSER_USERNAME=admin
export DJANGO_SUPERUSER_EMAIL=admin@shopping.com
export DJANGO_SUPERUSER_PASSWORD=123

python manage.py createsuperuser --no-input || echo "SuperUser đã tồn tại!"

echo "=== 6. Chèn dữ liệu mẫu cho toàn bộ hệ thống Mua sắm ==="
# Lưu code seeding ra một file tạm để tránh hoàn toàn lỗi IndentationError của shell
cat << 'EOF' > seed_temp.py
import random
from django.utils import timezone
from datetime import timedelta
from django.apps import apps
from django.contrib.auth import get_user_model
from django.db import transaction

User = get_user_model()
Customer = apps.get_model('account', 'Customer')
Staff = apps.get_model('account', 'Staff')
Category = apps.get_model('catalog', 'Category')
Product = apps.get_model('catalog', 'Product')
ProductImage = apps.get_model('catalog', 'ProductImage')
Cart = apps.get_model('cart', 'Cart')
CartItem = apps.get_model('cart', 'CartItem')
Voucher = apps.get_model('voucher', 'Voucher')
VoucherUsage = apps.get_model('voucher', 'VoucherUsage')
Order = apps.get_model('order', 'Order')
OrderDetail = apps.get_model('order', 'OrderDetail')
OrderStatusLog = apps.get_model('order', 'OrderStatusLog')
Payment = apps.get_model('order', 'Payment')
Review = apps.get_model('review', 'Review')
Notification = apps.get_model('notification', 'Notification')

today = timezone.now()

print(">>> 6.1 Đang tạo Danh mục, Sản phẩm & Hình ảnh (ProductImage)...")
c_tech, _ = Category.objects.get_or_create(name='Điện thoại & Laptop')
c_home, _ = Category.objects.get_or_create(name='Đồ gia dụng')
c_fashion, _ = Category.objects.get_or_create(name='Thời trang')

products_data = [
    (c_tech, 'iPhone 15 Pro Max 256GB', 'Điện thoại Apple cao cấp', 25000000, 29000000, 50, 0.2),
    (c_tech, 'MacBook Pro M3 14 inch', 'Laptop Apple chuyên nghiệp', 35000000, 39990000, 20, 1.6),
    (c_home, 'Nồi chiên không dầu Philips', 'Dung tích 5L, công suất 2000W', 1500000, 2200000, 100, 5.0),
    (c_fashion, 'Áo thun nam Cotton', 'Thoáng mát, thấm hút tốt', 80000, 150000, 200, 0.2),
]

all_products = []
for cat, name, desc, cost, sell, qty, weight in products_data:
    p, _ = Product.objects.get_or_create(
        name=name,
        defaults={
            'category': cat, 'description': desc, 'cost_price': cost,
            'sell_price': sell, 'stock_quantity': qty, 'weight': weight
        }
    )
    all_products.append(p)
    if not ProductImage.objects.filter(product=p).exists():
        ProductImage.objects.create(product=p, image=f'thumbnail_{p.id}.png', is_thumbnail=True, sort_order=1)
        ProductImage.objects.create(product=p, image=f'detail1_{p.id}.png', is_thumbnail=False, sort_order=2)

print(">>> 6.2 Đang tạo Tài khoản (Staff & Customer) & Giỏ hàng (Cart)...")
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
        cart = Cart.objects.create(user=u)

        sampled_products = random.sample(all_products, 2)
        for prod in sampled_products:
            CartItem.objects.get_or_create(cart=cart, product=prod, defaults={'quantity': random.randint(1, 3)})

print(">>> 6.3 Đang tạo Voucher...")
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

print(">>> 6.4 Đang tạo Đơn hàng, Lịch sử & Sử dụng Voucher...")
all_users = [c.user for c in Customer.objects.all()]

for user in all_users:
    status_choice = random.choice(['COMPLETED', 'PENDING', 'SHIPPING', 'CANCELED'])

    order = Order.objects.create(
        user=user,
        status=status_choice,
        payment_status=random.choice(['PAID', 'UNPAID']),
        recipient_name=user.username,
        recipient_phone=user.phone,
        shipping_address=user.address,
        shipping_fee=15000,
        total_amount=0,
        coin_used=0,
        coin_earned=1000,
        discount_voucher_amount=0,
        shipping_voucher_amount=0,
        final_amount=0,
    )

    OrderStatusLog.objects.create(order=order, old_status='PENDING', new_status='PENDING')
    if status_choice in ['SHIPPING', 'COMPLETED']:
        OrderStatusLog.objects.create(order=order, old_status='PENDING', new_status='SHIPPING')
    if status_choice == 'COMPLETED':
        OrderStatusLog.objects.create(order=order, old_status='SHIPPING', new_status='COMPLETED')
    elif status_choice == 'CANCELED':
        OrderStatusLog.objects.create(order=order, old_status='PENDING', new_status='CANCELED')

    if random.random() > 0.5:
        order.discount_voucher = v_discount
        order.discount_voucher_amount = 50000
        VoucherUsage.objects.get_or_create(user=user, voucher=v_discount, order=order)

    num_items = random.randint(1, 3)
    order_total = 0
    sampled_order_products = random.sample(all_products, min(num_items, len(all_products)))
    for prod in sampled_order_products:
        qty = random.randint(1, 2)
        price = prod.sell_price
        order_total += price * qty
        OrderDetail.objects.create(order=order, product=prod, quantity=qty, price=price)

    order.total_amount = order_total
    order.final_amount = max(0, (order_total + order.shipping_fee) - order.discount_voucher_amount)
    order.save()

    if order.payment_status == 'PAID':
        Payment.objects.create(order=order, transaction_id=f'TXN{order.id}{random.randint(1000,9999)}', amount=order.final_amount, status='PAID')

        if order.status == 'COMPLETED' and random.random() > 0.5:
            first_item = order.orderdetail_set.first()
            if first_item and not Review.objects.filter(order_item=first_item).exists():
                Review.objects.create(
                    user=user, order_item=first_item, product=first_item.product,
                    rating=random.randint(4, 5), comment="Sản phẩm rất tốt, giao hàng nhanh!"
                )

print(">>> 6.5 Đang tạo Thông báo (Notification)...")
for u in all_users:
    Notification.objects.create(
        user=u,
        type='SYSTEM',
        title='Chào mừng đến với Shopping App',
        content='Cảm ơn bạn đã đăng ký tài khoản. Chúc bạn mua sắm vui vẻ!',
        is_read=random.choice([True, False])
    )

    user_order = Order.objects.filter(user=u).first()
    if user_order:
        Notification.objects.create(
            user=u,
            type='ORDER',
            title=f'Cập nhật đơn hàng #{user_order.id}',
            content=f'Đơn hàng của bạn đang ở trạng thái {user_order.status}',
            order=user_order,
            is_read=False
        )

print(">>> TẤT CẢ CÁC BẢNG TRONG DATABASE ĐÃ CÓ DỮ LIỆU MẪU!")
EOF

# Yêu cầu Django chạy file tạm, sau đó dọn dẹp file đi
python manage.py shell -c "exec(open('seed_temp.py', encoding='utf-8').read())"
rm seed_temp.py

echo "=== 7. Chạy server Django ==="
python manage.py runserver