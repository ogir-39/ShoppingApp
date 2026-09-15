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
# 1. Tạo 10 Danh mục
category_names = [
    'Điện thoại & Phụ kiện', 'Laptop & Máy tính', 'Đồ gia dụng', 'Thời trang Nam',
    'Thời trang Nữ', 'Giày dép', 'Đồng hồ & Trang sức', 'Sức khỏe & Sắc đẹp',
    'Thể thao & Du lịch', 'Sách & Văn phòng phẩm'
]
categories = {}
for name in category_names:
    cat, _ = Category.objects.get_or_create(name=name)
    categories[name] = cat

# 2. Tạo 50 Sản phẩm (Mỗi danh mục 5 sản phẩm)
products_data = [
    # Điện thoại
    (categories['Điện thoại & Phụ kiện'], 'iPhone 15 Pro Max 256GB', 'Điện thoại Apple cao cấp', 25000000, 29000000, 50, 0.2),
    (categories['Điện thoại & Phụ kiện'], 'Samsung Galaxy S24 Ultra', 'Flagship Samsung 2024', 23000000, 27000000, 40, 0.2),
    (categories['Điện thoại & Phụ kiện'], 'Xiaomi 14 Pro', 'Camera Leica cực đỉnh', 18000000, 21000000, 30, 0.2),
    (categories['Điện thoại & Phụ kiện'], 'Oppo Reno 11 5G', 'Chuyên gia chân dung', 9000000, 11000000, 60, 0.2),
    (categories['Điện thoại & Phụ kiện'], 'Vivo V30', 'Thiết kế mỏng nhẹ', 8000000, 10000000, 45, 0.2),

    # Laptop
    (categories['Laptop & Máy tính'], 'MacBook Pro M3 14 inch', 'Laptop Apple chuyên nghiệp', 35000000, 39990000, 20, 1.6),
    (categories['Laptop & Máy tính'], 'Dell XPS 15 9530', 'Màn hình OLED viền mỏng', 38000000, 42000000, 15, 1.9),
    (categories['Laptop & Máy tính'], 'Lenovo ThinkPad X1 Carbon', 'Bàn phím gõ tốt nhất', 33000000, 37000000, 18, 1.1),
    (categories['Laptop & Máy tính'], 'Asus ROG Strix G15', 'Laptop Gaming mạnh mẽ', 25000000, 28000000, 25, 2.3),
    (categories['Laptop & Máy tính'], 'HP Envy x360', 'Laptop xoay gập cảm ứng', 20000000, 23000000, 30, 1.4),

    # Gia dụng
    (categories['Đồ gia dụng'], 'Nồi chiên không dầu Philips 5L', 'Công suất 2000W', 1500000, 2200000, 100, 5.0),
    (categories['Đồ gia dụng'], 'Máy lọc không khí Xiaomi 4 Pro', 'Lọc bụi mịn PM2.5', 2500000, 3200000, 80, 4.5),
    (categories['Đồ gia dụng'], 'Robot hút bụi Dreame L10s', 'Tự động giặt giẻ', 12000000, 15000000, 40, 6.0),
    (categories['Đồ gia dụng'], 'Lò vi sóng Sharp 20L', 'Có chức năng nướng', 1000000, 1300000, 120, 11.0),
    (categories['Đồ gia dụng'], 'Máy xay sinh tố Panasonic', 'Cối thủy tinh siêu bền', 800000, 1100000, 90, 2.5),

    # Thời trang Nam
    (categories['Thời trang Nam'], 'Áo thun nam Cotton Compact', 'Thoáng mát, thấm hút tốt', 80000, 150000, 200, 0.2),
    (categories['Thời trang Nam'], 'Áo sơ mi nam dài tay', 'Chống nhăn hiệu quả', 150000, 250000, 150, 0.3),
    (categories['Thời trang Nam'], 'Quần Jean nam Slimfit', 'Co giãn thoải mái', 200000, 350000, 180, 0.5),
    (categories['Thời trang Nam'], 'Áo khoác dù nam', 'Chống nước nhẹ', 250000, 400000, 100, 0.4),
    (categories['Thời trang Nam'], 'Quần Kaki nam ống suông', 'Phong cách thanh lịch', 180000, 280000, 120, 0.4),

    # Thời trang Nữ
    (categories['Thời trang Nữ'], 'Váy hoa nhí dáng dài', 'Phong cách Vintage', 150000, 250000, 150, 0.3),
    (categories['Thời trang Nữ'], 'Áo kiểu nữ cổ vuông', 'Tôn vóc dáng', 120000, 190000, 200, 0.2),
    (categories['Thời trang Nữ'], 'Quần ống rộng lưng cao', 'Hack dáng cực đỉnh', 180000, 280000, 180, 0.4),
    (categories['Thời trang Nữ'], 'Chân váy chữ A', 'Dễ phối đồ', 130000, 220000, 160, 0.2),
    (categories['Thời trang Nữ'], 'Áo khoác Cardigan len', 'Mềm mịn ấm áp', 160000, 260000, 100, 0.3),

    # Giày dép
    (categories['Giày dép'], 'Giày Sneaker nam trắng', 'Phong cách Hàn Quốc', 250000, 400000, 200, 0.8),
    (categories['Giày dép'], 'Giày cao gót nữ 7cm', 'Mũi nhọn đính đá', 200000, 350000, 150, 0.6),
    (categories['Giày dép'], 'Giày chạy bộ thể thao', 'Đế siêu nhẹ siêu êm', 400000, 600000, 120, 0.5),
    (categories['Giày dép'], 'Dép quai ngang nam', 'Chất liệu EVA chống trượt', 80000, 150000, 300, 0.3),
    (categories['Giày dép'], 'Sandal nữ dây chéo', 'Phù hợp đi dạo, đi biển', 120000, 200000, 180, 0.4),

    # Đồng hồ & Trang sức
    (categories['Đồng hồ & Trang sức'], 'Đồng hồ nam Casio Edifice', 'Dây kim loại', 1800000, 2500000, 50, 0.3),
    (categories['Đồng hồ & Trang sức'], 'Đồng hồ nữ DW Classic', 'Dây lưới thời trang', 2000000, 2800000, 60, 0.2),
    (categories['Đồng hồ & Trang sức'], 'Dây chuyền bạc 925 nữ', 'Mặt đính đá cz', 200000, 350000, 100, 0.1),
    (categories['Đồng hồ & Trang sức'], 'Bông tai ngọc trai', 'Thiết kế tinh xảo', 150000, 250000, 120, 0.1),
    (categories['Đồng hồ & Trang sức'], 'Vòng tay nam da thật', 'Khóa nam châm', 100000, 180000, 80, 0.1),

    # Sức khỏe & Sắc đẹp
    (categories['Sức khỏe & Sắc đẹp'], 'Kem chống nắng SPF 50+', 'Bảo vệ da toàn diện', 150000, 250000, 300, 0.1),
    (categories['Sức khỏe & Sắc đẹp'], 'Sữa rửa mặt tạo bọt', 'Làm sạch sâu', 90000, 150000, 250, 0.2),
    (categories['Sức khỏe & Sắc đẹp'], 'Nước tẩy trang Micellar', 'Dành cho da nhạy cảm', 120000, 180000, 200, 0.3),
    (categories['Sức khỏe & Sắc đẹp'], 'Son kem lì lâu trôi', 'Nhiều tone màu', 180000, 280000, 400, 0.1),
    (categories['Sức khỏe & Sắc đẹp'], 'Dầu gội phục hồi hư tổn', 'Dưỡng chất từ thiên nhiên', 140000, 210000, 150, 0.5),

    # Thể thao & Du lịch
    (categories['Thể thao & Du lịch'], 'Balo du lịch chống nước', 'Dung tích 40L', 250000, 450000, 100, 0.8),
    (categories['Thể thao & Du lịch'], 'Thảm tập Yoga TPE', 'Độ dày 8mm', 120000, 190000, 150, 1.0),
    (categories['Thể thao & Du lịch'], 'Lều cắm trại 4 người', 'Gấp gọn tiện lợi', 400000, 650000, 50, 2.5),
    (categories['Thể thao & Du lịch'], 'Vợt cầu lông Carbon', 'Siêu nhẹ siêu bền', 300000, 500000, 80, 0.2),
    (categories['Thể thao & Du lịch'], 'Bình giữ nhiệt inox', 'Giữ nóng lạnh 12h', 100000, 180000, 200, 0.4),

    # Sách & Văn phòng phẩm
    (categories['Sách & Văn phòng phẩm'], 'Sách Đắc Nhân Tâm', 'Sách kỹ năng sống', 50000, 80000, 300, 0.3),
    (categories['Sách & Văn phòng phẩm'], 'Combo 5 Bút bi mực xanh', 'Ngòi 0.5mm êm ái', 15000, 25000, 500, 0.1),
    (categories['Sách & Văn phòng phẩm'], 'Sổ tay ghi chép bìa da A5', '200 trang, giấy chống lóa', 40000, 65000, 200, 0.4),
    (categories['Sách & Văn phòng phẩm'], 'Balo học sinh chống gù', 'Nhiều ngăn chứa đồ', 150000, 250000, 120, 0.6),
    (categories['Sách & Văn phòng phẩm'], 'Sách Lược Sử Loài Người', 'Sách khoa học bán chạy', 120000, 180000, 100, 0.5),
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
    # Tự động tạo 2 ảnh giả lập cho mỗi sản phẩm
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