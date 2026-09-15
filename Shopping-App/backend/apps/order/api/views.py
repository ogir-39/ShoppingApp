from datetime import datetime

from django.db import transaction
from django.utils import timezone
from django.utils.decorators import method_decorator
from drf_yasg.utils import swagger_auto_schema
from oauth2_provider.contrib.rest_framework import permissions
from rest_framework import viewsets, generics, status, filters
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
import urllib.parse
import hmac
import hashlib
from django.conf import settings

from apps.cart.models import CartItem, Cart
from apps.order.api.serializers import OrderSerializer, OrderDetailSerializer, PaymentSerializer
from apps.order.models import Order, OrderDetail, Payment
from apps.voucher.models import VoucherUsage, Voucher
from core import paginators
from core.permissions import OrderPermission, IsStaffOrAdminStrict
from core.vnpay import vnpay


@method_decorator(name="list", decorator=swagger_auto_schema(tags=['order']))
@method_decorator(name="retrieve", decorator=swagger_auto_schema(tags=['order']))
class OrderViewSet(viewsets.ViewSet, generics.ListAPIView, generics.RetrieveAPIView):
    queryset = Order.objects.all()
    serializer_class = OrderSerializer
    permission_classes = [OrderPermission]
    filter_backends = [DjangoFilterBackend,filters.SearchFilter]
    filterset_fields = ['status','payment_status']
    search_fields = ['recipient_name','recipient_phone']
    pagination_class = paginators.OrderPaginator

    def get_queryset(self):
        user = self.request.user
        if user.role in ['ADMIN', 'STAFF']:
            q = Order.objects.all().order_by('-created_at')
        else:
            q = Order.objects.filter(user=user).order_by('-created_at')

        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')

        if start_date:
            q = q.filter(created_at__date__gte=start_date)
        if end_date:
            q = q.filter(created_at__date__lte=end_date)

        return q.order_by('-created_at')

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
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAuthenticated], url_path='checkout',
            url_name='checkout')
    def checkout(self, request):
        user = request.user
        data = request.data

        shipping_address = data.get('shipping_address', '')
        discount_voucher_code = data.get('discount_voucher_code', '')
        shipping_voucher_code = data.get('shipping_voucher_code', '')
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

                # 3. Tính phí ship
                address_lower = shipping_address.lower()
                shipping_fee = 20000 if 'hcm' in address_lower or 'hồ chí minh' in address_lower else 30000

                # 4. Xử lý Voucher (Hỗ trợ 2 loại cùng lúc)
                discount_voucher_amount = 0
                shipping_voucher_amount = 0
                applied_discount_voucher = None
                applied_shipping_voucher = None
                now = timezone.now()

                def validate_and_apply_voucher(code, v_type):
                    v = Voucher.objects.get(code=code)
                    if v.voucher_type != v_type:
                        raise ValueError(f"Mã {code} không phải là loại {v_type}.")
                    if not v.is_active or not (v.start_date <= now <= v.end_date):
                        raise ValueError(f"Mã {code} không hợp lệ hoặc đã hết hạn.")
                    if v.used_count >= v.total_usage_limit:
                        raise ValueError(f"Mã {code} đã hết lượt sử dụng trên toàn hệ thống.")
                    if total_goods_value < v.min_order_value:
                        raise ValueError(f"Đơn hàng chưa đạt giá trị tối thiểu để dùng mã {code}.")
                    if VoucherUsage.objects.filter(user=user, voucher=v).count() >= v.user_usage_limit:
                        raise ValueError(f"Bạn đã hết lượt sử dụng mã {code}.")
                    return v

                if discount_voucher_code:
                    applied_discount_voucher = validate_and_apply_voucher(discount_voucher_code, 'DISCOUNT')
                    if applied_discount_voucher.discount_type == 'PERCENT':
                        calc_discount = (total_goods_value * float(applied_discount_voucher.discount_value)) / 100
                    else:
                        calc_discount = float(applied_discount_voucher.discount_value)
                    discount_voucher_amount = min(calc_discount, float(applied_discount_voucher.max_discount_value))

                if shipping_voucher_code:
                    applied_shipping_voucher = validate_and_apply_voucher(shipping_voucher_code, 'SHIPPING')
                    shipping_voucher_amount = min(float(applied_shipping_voucher.discount_value), shipping_fee)

                # 5. Chốt tổng tiền
                total_amount = total_goods_value + shipping_fee
                final_amount = total_amount - discount_voucher_amount - shipping_voucher_amount - coin_used
                final_amount = max(final_amount, 0)

                # XỬ LÝ TRỪ XU KHÁCH HÀNG
                if coin_used > 0:
                    customer = user.customer
                    if customer.coins < coin_used:
                        raise ValueError("Không đủ xu để thanh toán.")
                    customer.coins -= coin_used
                    customer.save()

                # 6. Tạo Order
                order = Order.objects.create(
                    user=user,
                    status='PENDING',
                    payment_status='UNPAID',
                    shipping_address=shipping_address,
                    recipient_name=user.username,
                    recipient_phone=getattr(user, 'phone', ''),  # Fallback nếu phone trống
                    coin_used=coin_used,
                    coin_earned=final_amount * 0.01,
                    discount_voucher=applied_discount_voucher,
                    shipping_voucher=applied_shipping_voucher,
                    discount_voucher_amount=discount_voucher_amount,
                    shipping_voucher_amount=shipping_voucher_amount,
                    shipping_fee=shipping_fee,
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
                if applied_discount_voucher:
                    VoucherUsage.objects.create(user=user, voucher=applied_discount_voucher, order=order)
                    applied_discount_voucher.used_count += 1
                    applied_discount_voucher.save()

                if applied_shipping_voucher:
                    VoucherUsage.objects.create(user=user, voucher=applied_shipping_voucher, order=order)
                    applied_shipping_voucher.used_count += 1
                    applied_shipping_voucher.save()

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

        order.status = 'READY'
        order.save()
        return Response({"detail": "Đã xác nhận đơn hàng thành công."}, status=status.HTTP_200_OK)

    @swagger_auto_schema(tags=['order'], operation_summary="Nhân viên bàn giao đơn cho đơn vị vận chuyển")
    @action(detail=True, methods=['patch'], permission_classes=[OrderPermission])
    def ship(self, request, pk=None):
        user = request.user
        if user.role not in ['ADMIN', 'STAFF']:
            return Response({"detail": "Bạn không có quyền thực hiện thao tác này."}, status=status.HTTP_403_FORBIDDEN)

        order = self.get_object()
        # FIX CẬP NHẬT: Chỉ được phép sang SHIPPING nếu đã READY hoặc PENDING (bỏ qua bước READY nếu cần gấp)
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

        # BẢO MẬT: KHÓA LẠI - BẮT BUỘC PHẢI Ở TRẠNG THÁI SHIPPING MỚI ĐƯỢC LÊN COMPLETED
        if order.status != 'SHIPPING':
            return Response({"detail": "Chỉ có thể hoàn thành các đơn hàng đang ở trạng thái 'Đang giao' (SHIPPING)."},
                            status=status.HTTP_400_BAD_REQUEST)

        # BẢO MẬT: ĐẢM BẢO CHẮC CHẮN ĐÃ THANH TOÁN
        if order.payment_status != 'PAID':
            return Response({"detail": "Chỉ có thể hoàn thành các đơn hàng đã thanh toán (PAID)."},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic():
                order.status = 'COMPLETED'
                order.save()

                # CỘNG XU SAU KHI ĐÃ ĐẠT ĐỦ MỌI ĐIỀU KIỆN
                if order.coin_earned and order.coin_earned > 0:
                    customer = order.user.customer
                    customer.coins += order.coin_earned
                    customer.save()

        except Exception as e:
            return Response({"detail": "Lỗi khi hoàn tất đơn hàng và cộng xu."}, status=status.HTTP_400_BAD_REQUEST)

        return Response({"detail": "Đã cập nhật đơn hàng thành công hoàn thành và khách đã nhận được xu."},
                        status=status.HTTP_200_OK)

    @swagger_auto_schema(tags=['order'], operation_summary="Tạo link thanh toán VNPay")
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def pay_vnpay(self, request, pk=None):
        order = self.get_object()

        # 1. Kiểm tra quyền và trạng thái đơn hàng
        if order.user != request.user and request.user.role not in ['ADMIN', 'STAFF']:
            return Response({"detail": "Bạn không có quyền thanh toán đơn hàng này."}, status=status.HTTP_403_FORBIDDEN)

        if order.payment_status == 'PAID':
            return Response({"detail": "Đơn hàng này đã được thanh toán."}, status=status.HTTP_400_BAD_REQUEST)

        # 2. Lấy IP của client (Thay vì fix cứng 127.0.0.1)
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ipaddr = x_forwarded_for.split(',')[0]
        else:
            ipaddr = request.META.get('REMOTE_ADDR', '127.0.0.1')

        # 3. Sử dụng class vnpay từ code mẫu
        vnp = vnpay()
        vnp.requestData['vnp_Version'] = '2.1.0'
        vnp.requestData['vnp_Command'] = 'pay'
        vnp.requestData['vnp_TmnCode'] = settings.VNPAY_TMN_CODE
        vnp.requestData['vnp_Amount'] = int(order.final_amount) * 100
        vnp.requestData['vnp_CurrCode'] = 'VND'
        # Nối thêm thời gian vào TxnRef để tránh lỗi trùng mã giao dịch khi thanh toán lại
        vnp.requestData['vnp_TxnRef'] = f"{order.id}_{datetime.now().strftime('%H%M%S')}"
        vnp.requestData['vnp_OrderInfo'] = f"Thanh toan don hang {order.id}"
        vnp.requestData['vnp_OrderType'] = 'billpayment'
        vnp.requestData['vnp_Locale'] = 'vn'
        vnp.requestData['vnp_CreateDate'] = datetime.now().strftime('%Y%m%d%H%M%S')
        vnp.requestData['vnp_IpAddr'] = ipaddr
        vnp.requestData['vnp_ReturnUrl'] = settings.VNPAY_RETURN_URL

        # 4. Sinh URL Payment
        # Chú ý: File settings.py của bạn đang dùng tên biến là VNPAY_HASH_SECRET thay vì VNPAY_HASH_SECRET_KEY như code mẫu
        vnpay_payment_url = vnp.get_payment_url(settings.VNPAY_PAYMENT_URL, settings.VNPAY_HASH_SECRET)

        # 5. Trả về link cho Flutter thay vì gọi redirect()
        return Response({"payUrl": vnpay_payment_url}, status=status.HTTP_200_OK)

    # @swagger_auto_schema(tags=['order'], operation_summary="Webhook nhận kết quả thanh toán từ VNPay (IPN)")
    # @action(detail=False, methods=['get'], permission_classes=[AllowAny])
    # def vnpay_webhook(self, request):
    #     inputData = request.query_params.dict()
    #     if inputData:
    #         vnp = vnpay()
    #         vnp.responseData = inputData
    #
    #         # Lấy order_id (bỏ phần thời gian đã nối vào lúc gửi)
    #         order_id_raw = inputData.get('vnp_TxnRef', '')
    #         order_id = order_id_raw.split('_')[0] if order_id_raw else ''
    #
    #         amount = inputData.get('vnp_Amount')
    #         vnp_ResponseCode = inputData.get('vnp_ResponseCode')
    #
    #         # Kiểm tra chữ ký bảo mật
    #         if vnp.validate_response(settings.VNPAY_HASH_SECRET):
    #             try:
    #                 order = Order.objects.get(id=order_id)
    #
    #                 # 1. Kiểm tra số tiền thanh toán có khớp không
    #                 check_amount = int(order.final_amount) * 100
    #                 if check_amount != int(amount):
    #                     return Response({"RspCode": "04", "Message": "Invalid amount"})
    #
    #                 # 2. Kiểm tra trạng thái đơn hàng (Đảm bảo chưa được cập nhật trước đó)
    #                 if order.payment_status == 'PAID':
    #                     return Response({"RspCode": "02", "Message": "Order Already Update"})
    #
    #                 # 3. Cập nhật trạng thái
    #                 if vnp_ResponseCode == '00':
    #                     order.payment_status = 'PAID'
    #                     order.save()
    #                     # Xử lý thêm nếu cần (VD: Gửi email thông báo, tạo hóa đơn...)
    #
    #                 # Trả về kết quả cho VNPay biết là đã ghi nhận thành công
    #                 return Response({"RspCode": "00", "Message": "Confirm Success"})
    #
    #             except Order.DoesNotExist:
    #                 return Response({"RspCode": "01", "Message": "Order not found"})
    #         else:
    #             # Chữ ký không hợp lệ
    #             return Response({"RspCode": "97", "Message": "Invalid Signature"})
    #     else:
    #         return Response({"RspCode": "99", "Message": "Invalid request"})

    @swagger_auto_schema(tags=['order'], operation_summary="Kiểm tra kết quả thanh toán trả về (Return URL)")
    @action(detail=False, methods=['get'], permission_classes=[AllowAny])
    def vnpay_return(self, request):
        inputData = request.query_params.dict()
        if inputData:
            vnp = vnpay()
            vnp.responseData = inputData

            order_id_raw = inputData.get('vnp_TxnRef', '')
            order_id = order_id_raw.split('_')[0] if order_id_raw else ''
            vnp_ResponseCode = inputData.get('vnp_ResponseCode')

            # Xác thực chữ ký
            if vnp.validate_response(settings.VNPAY_HASH_SECRET):
                if vnp_ResponseCode == "00":

                    # --- THÊM LOGIC CẬP NHẬT DATABASE VÀO ĐÂY ---
                    try:
                        order = Order.objects.get(id=order_id)
                        if order.payment_status != 'PAID':
                            order.payment_status = 'PAID'
                            order.save()
                    except Order.DoesNotExist:
                        pass
                        # ---------------------------------------------

                    return Response({
                        "result": "Thành công",
                        "order_id": order_id,
                        "code": "00",
                        "message": "Giao dịch thanh toán thành công."
                    }, status=status.HTTP_200_OK)
                else:
                    return Response({
                        "result": "Thất bại",
                        "order_id": order_id,
                        "code": vnp_ResponseCode,
                        "message": "Giao dịch bị hủy hoặc thanh toán thất bại."
                    }, status=status.HTTP_400_BAD_REQUEST)
            else:
                return Response({
                    "result": "Lỗi",
                    "code": "97",
                    "message": "Sai chữ ký (Invalid Signature)"
                }, status=status.HTTP_400_BAD_REQUEST)

        return Response({"result": "Lỗi", "message": "Không có dữ liệu trả về"}, status=status.HTTP_400_BAD_REQUEST)

@method_decorator(name="list", decorator=swagger_auto_schema(tags=['OrderDetail']))
@method_decorator(name="retrieve", decorator=swagger_auto_schema(tags=['OrderDetail']))
class OrderDetailViewSet(viewsets.ViewSet, generics.ListAPIView, generics.RetrieveAPIView):
    queryset = OrderDetail.objects.all()
    serializer_class = OrderDetailSerializer
    permission_classes = [OrderPermission]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['order']

    def get_queryset(self):
        user = self.request.user
        if user.role in ['ADMIN', 'STAFF']:
            return OrderDetail.objects.all()
        return OrderDetail.objects.filter(order__user=user)


@method_decorator(name="list", decorator=swagger_auto_schema(tags=['payment']))
@method_decorator(name="retrieve", decorator=swagger_auto_schema(tags=['payment']))
class PaymentViewSet(viewsets.ViewSet, generics.ListAPIView, generics.RetrieveAPIView):
    queryset = Payment.objects.all()
    serializer_class = PaymentSerializer
    permission_classes = [IsStaffOrAdminStrict]