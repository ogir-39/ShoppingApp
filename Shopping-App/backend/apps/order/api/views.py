from django.db import transaction
from django.utils import timezone
from django.utils.decorators import method_decorator
from drf_yasg.utils import swagger_auto_schema
from oauth2_provider.contrib.rest_framework import permissions
from rest_framework import viewsets, generics, status
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

import uuid
import hmac
import hashlib
import json
import requests
from django.conf import settings

from apps.cart.models import CartItem, Cart
from apps.order.api.serializers import OrderSerializer, OrderDetailSerializer, PaymentSerializer
from apps.order.models import Order, OrderDetail, Payment
from apps.voucher.models import VoucherUsage, Voucher
from core.permissions import OrderPermission, IsStaffOrAdminStrict


# Create your views here.
@method_decorator(name="list", decorator=swagger_auto_schema(tags=['order']))
@method_decorator(name="retrieve", decorator=swagger_auto_schema(tags=['order']))
class OrderViewSet(viewsets.ViewSet,generics.ListAPIView,generics.RetrieveAPIView):
    queryset = Order.objects.all()
    serializer_class = OrderSerializer
    permission_classes = [OrderPermission]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['user']

    def get_queryset(self):
        user = self.request.user
        if user.role in ['ADMIN', 'STAFF']:
            return Order.objects.all()
        return Order.objects.filter(user=user)

    @swagger_auto_schema(tags=['order'], operation_summary="Khách hàng tự hủy đơn hàng của mình")
    @action(detail=True, methods=['patch'], permission_classes=[OrderPermission])
    def cancel(self, request, pk=None):
        order = self.get_object()

        if order.status != 'PENDING':
            return Response(
                {"detail": "Chỉ có thể hủy đơn hàng đang chờ xử lý."},
                status=status.HTTP_400_BAD_REQUEST
            )

        order.status = 'CANCELLED'
        order.save()

        return Response({"detail": "Hủy đơn hàng thành công."}, status=status.HTTP_200_OK)

    @swagger_auto_schema(tags=['order'], operation_summary="Thanh toán chốt đơn từ giỏ hàng")
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAuthenticated], url_path='checkout', url_name='checkout')
    def checkout(self, request):
        user = request.user
        data = request.data

        shipping_address = data.get('shipping_address', '')
        voucher_code = data.get('voucher_code', '')
        coin_used = float(data.get('coin_used', 0))

        if not shipping_address:
            return Response({"detail": "Vui lòng cung cấp địa chỉ giao hàng."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic():
                # 1. Lấy giỏ hàng
                cart = Cart.objects.get(user=user)
                cart_items = CartItem.objects.filter(cart=cart).select_related('product')

                if not cart_items.exists():
                    raise ValueError("Giỏ hàng đang trống.")

                # 2. Tính tiền hàng thô & Kiểm tra tồn kho
                total_goods_value = 0
                for item in cart_items:
                    if item.product.stock_quantity < item.quantity:
                        raise ValueError(
                            f"Sản phẩm '{item.product.name}' chỉ còn {item.product.stock_quantity} cái trong kho.")
                    total_goods_value += float(item.product.sell_price) * item.quantity

                # 3. Tính phí ship (Yêu cầu 6)
                address_lower = shipping_address.lower()
                shipping_fee = 20000 if 'hcm' in address_lower or 'hồ chí minh' in address_lower else 30000

                # 4. Xử lý Voucher (Yêu cầu 5 & 8)
                discount_voucher_amount = 0
                shipping_voucher_amount = 0
                applied_voucher = None

                if voucher_code:
                    applied_voucher = Voucher.objects.get(code=voucher_code)
                    now = timezone.now()

                    # Rào chắn Voucher
                    if not applied_voucher.is_active or not (
                            applied_voucher.start_date <= now <= applied_voucher.end_date):
                        raise ValueError("Mã giảm giá không hợp lệ hoặc đã hết hạn.")
                    if applied_voucher.used_count >= applied_voucher.total_usage_limit:
                        raise ValueError("Mã giảm giá đã hết lượt sử dụng trên toàn hệ thống.")
                    if total_goods_value < applied_voucher.min_order_value:
                        raise ValueError(
                            f"Đơn hàng chưa đạt giá trị tối thiểu {applied_voucher.min_order_value}đ để dùng mã này.")

                    user_used_count = VoucherUsage.objects.filter(user=user, voucher=applied_voucher).count()
                    if user_used_count >= applied_voucher.user_usage_limit:
                        raise ValueError("Bạn đã hết lượt sử dụng mã giảm giá này.")

                    # Tính tiền giảm
                    if applied_voucher.voucher_type == 'SHIPPING':
                        shipping_voucher_amount = min(float(applied_voucher.discount_value), shipping_fee)
                    elif applied_voucher.voucher_type == 'DISCOUNT':
                        if applied_voucher.discount_type == 'PERCENT':
                            calc_discount = (total_goods_value * float(applied_voucher.discount_value)) / 100
                        else:
                            calc_discount = float(applied_voucher.discount_value)
                        discount_voucher_amount = min(calc_discount, float(applied_voucher.max_discount_value))

                # 5. Chốt tổng tiền (Yêu cầu 7 & 8)
                total_amount = total_goods_value + shipping_fee
                final_amount = total_amount - discount_voucher_amount - shipping_voucher_amount - coin_used
                final_amount = max(final_amount, 0)  # Đảm bảo không bị âm tiền

                # 6. Tạo Order
                order = Order.objects.create(
                    user=user,
                    status='PENDING',
                    payment_status='UNPAID',
                    shipping_address=shipping_address,
                    recipient_name=user.username,
                    coin_used=coin_used,
                    coin_earned=final_amount * 0.01,  # Ví dụ: Tích lũy 1% xu
                    discount_voucher_amount=discount_voucher_amount,
                    shipping_voucher_amount=shipping_voucher_amount,
                    total_amount=total_amount,
                    final_amount=final_amount
                )

                # 7. Tạo OrderDetail & Trừ kho
                for item in cart_items:
                    OrderDetail.objects.create(
                        order=order,
                        product=item.product,
                        quantity=item.quantity,
                        price=item.product.sell_price
                    )
                    item.product.stock_quantity -= item.quantity
                    item.product.save()

                # 8. Ghi nhận lịch sử Voucher & Tăng used_count
                if applied_voucher:
                    VoucherUsage.objects.create(user=user, voucher=applied_voucher, order=order)
                    applied_voucher.used_count += 1
                    applied_voucher.save()

                # 9. Xóa rỗng giỏ hàng
                cart_items.delete()

            return Response({
                "detail": "Đặt hàng thành công!",
                "order_id": order.id,
                "final_amount": final_amount
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    @swagger_auto_schema(tags=['order'],
                         operation_summary="Nhân viên xác nhận đơn hàng (Chuyển sang trạng thái Chờ lấy hàng/Đang xử lý)")
    @action(detail=True, methods=['patch'], permission_classes=[OrderPermission])
    def confirm(self, request, pk=None):
        user = request.user
        if user.role not in ['ADMIN', 'STAFF']:
            return Response({"detail": "Bạn không có quyền thực hiện thao tác này."}, status=status.HTTP_403_FORBIDDEN)

        order = self.get_object()
        if order.status != 'PENDING':
            return Response({"detail": "Chỉ có thể xác nhận đơn hàng đang ở trạng thái chờ xử lý."},
                            status=status.HTTP_400_BAD_REQUEST)

        # Cập nhật trạng thái (Ví dụ chuyển sang READY hoặc tùy chỉnh theo model của bạn)
        order.status = 'READY'  # Hoặc trạng thái tương đương cho "chờ lấy hàng"
        order.save()
        return Response({"detail": "Đã xác nhận đơn hàng thành công."}, status=status.HTTP_200_OK)

    @swagger_auto_schema(tags=['order'], operation_summary="Nhân viên bàn giao đơn cho đơn vị vận chuyển")
    @action(detail=True, methods=['patch'], permission_classes=[OrderPermission])
    def ship(self, request, pk=None):
        user = request.user
        if user.role not in ['ADMIN', 'STAFF']:
            return Response({"detail": "Bạn không có quyền thực hiện thao tác này."}, status=status.HTTP_403_FORBIDDEN)

        order = self.get_object()
        if order.status not in ['PENDING', 'READY']:
            return Response({"detail": "Đơn hàng chưa sẵn sàng để giao cho vận chuyển."},
                            status=status.HTTP_400_BAD_REQUEST)

        order.status = 'SHIPPING'
        order.save()
        return Response({"detail": "Đã chuyển trạng thái đơn hàng sang Đang giao."}, status=status.HTTP_200_OK)

    @swagger_auto_schema(tags=['order'], operation_summary="Nhân viên cập nhật đơn hàng đã hoàn thành")
    @action(detail=True, methods=['patch'], permission_classes=[OrderPermission])
    def complete(self, request, pk=None):
        user = request.user
        if user.role not in ['ADMIN', 'STAFF']:
            return Response({"detail": "Bạn không có quyền thực hiện thao tác này."}, status=status.HTTP_403_FORBIDDEN)

        order = self.get_object()
        if order.status != 'SHIPPING':
            return Response({"detail": "Chỉ có thể hoàn thành các đơn hàng đang được giao."},
                            status=status.HTTP_400_BAD_REQUEST)

        order.status = 'COMPLETED'
        order.payment_status = 'PAID'  # Thường khi hoàn thành thì đơn cũng được ghi nhận đã thanh toán
        order.save()
        return Response({"detail": "Đã cập nhật đơn hàng thành công hoàn thành."}, status=status.HTTP_200_OK)

    @swagger_auto_schema(tags=['payment'], operation_summary="Tạo link thanh toán MoMo cho đơn hàng")
    @action(detail=True, methods=['post'], permission_classes=[OrderPermission])
    def pay_momo(self, request, pk=None):
        order = self.get_object()

        if order.payment_status == 'PAID':
            return Response({"detail": "Đơn hàng này đã được thanh toán."}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Chuẩn bị dữ liệu theo tài liệu MoMo v2
        order_info = f"Thanh toán đơn hàng {order.id}"
        amount = str(int(order.final_amount))  # MoMo yêu cầu số tiền là string số nguyên
        order_id = f"{order.id}_{uuid.uuid4().hex[:8]}"  # Tránh trùng mã đơn hàng khi test nhiều lần
        request_id = str(uuid.uuid4())
        request_type = "captureWallet"
        extra_data = ""

        # 2. Tạo chuỗi ký tự (Signature string) đúng thứ tự
        raw_signature = (
            f"accessKey={settings.MOMO_ACCESS_KEY}&amount={amount}&extraData={extra_data}"
            f"&ipnUrl={settings.MOMO_IPN_URL}&orderId={order_id}&orderInfo={order_info}"
            f"&partnerCode={settings.MOMO_PARTNER_CODE}&redirectUrl={settings.MOMO_REDIRECT_URL}"
            f"&requestId={request_id}&requestType={request_type}"
        )

        # 3. Mã hóa HMAC-SHA256
        signature = hmac.new(
            bytes(settings.MOMO_SECRET_KEY, 'utf-8'),
            bytes(raw_signature, 'utf-8'),
            hashlib.sha256
        ).hexdigest()

        # 4. Đóng gói JSON và gửi request sang MoMo
        data = {
            "partnerCode": settings.MOMO_PARTNER_CODE,
            "partnerName": "Test Store",
            "storeId": "MomoTestStore",
            "requestId": request_id,
            "amount": amount,
            "orderId": order_id,
            "orderInfo": order_info,
            "redirectUrl": settings.MOMO_REDIRECT_URL,
            "ipnUrl": settings.MOMO_IPN_URL,
            "lang": "vi",
            "extraData": extra_data,
            "requestType": request_type,
            "signature": signature
        }

        response = requests.post(settings.MOMO_ENDPOINT, json=data)
        result = response.json()

        if result.get('resultCode') == 0:
            return Response({"payUrl": result.get('payUrl')}, status=status.HTTP_200_OK)
        return Response({"detail": "Lỗi tạo thanh toán MoMo", "momo_response": result},
                        status=status.HTTP_400_BAD_REQUEST)

    @swagger_auto_schema(tags=['payment'], operation_summary="Webhook nhận kết quả thanh toán từ MoMo")
    @action(detail=False, methods=['post'], permission_classes=[AllowAny])
    def momo_webhook(self, request):
        data = request.data

        # Lấy thông tin từ MoMo trả về
        result_code = data.get('resultCode')
        order_id_momo = data.get('orderId')  # Ví dụ: "15_abc123"

        # Tách lấy ID đơn hàng thật trong Database
        try:
            real_order_id = order_id_momo.split('_')[0]
            order = Order.objects.get(id=real_order_id)
        except (IndexError, Order.DoesNotExist):
            return Response(status=status.HTTP_204_NO_CONTENT)

        # Kiểm tra mã kết quả (0 là thành công)
        if result_code == 0:
            if order.payment_status != 'PAID':
                order.payment_status = 'PAID'
                order.save()

                # Tại đây bạn có thể gọi Signals để tạo Notification "Thanh toán thành công"

        return Response(status=status.HTTP_204_NO_CONTENT)  # Phản hồi 204 để MoMo biết đã nhận được

@method_decorator(name="list", decorator=swagger_auto_schema(tags=['OrderDetail']))
@method_decorator(name="retrieve", decorator=swagger_auto_schema(tags=['OrderDetail']))
class OrderDetailViewSet(viewsets.ViewSet,generics.ListAPIView,generics.RetrieveAPIView):
    queryset = OrderDetail.objects.all()
    serializer_class = OrderDetailSerializer
    permission_classes = [OrderPermission]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['order']

    def get_queryset(self):
        user = self.request.user
        if user.role in ['ADMIN', 'STAFF']:
            return OrderDetail.objects.all()
        # Lọc chi tiết đơn hàng thuộc về user đang đăng nhập
        return OrderDetail.objects.filter(order__user=user)


@method_decorator(name="list", decorator=swagger_auto_schema(tags=['payment']))
@method_decorator(name="retrieve", decorator=swagger_auto_schema(tags=['payment']))
class PaymentViewSet(viewsets.ViewSet,generics.ListAPIView,generics.RetrieveAPIView):
    queryset = Payment.objects.all()
    serializer_class = PaymentSerializer
    permission_classes = [IsStaffOrAdminStrict]