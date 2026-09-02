from django.db.models import Sum, F
from django.utils.decorators import method_decorator
from django_filters.rest_framework import DjangoFilterBackend
from drf_yasg.utils import swagger_auto_schema
from oauth2_provider.contrib.rest_framework import permissions
from rest_framework import viewsets, generics
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone

from apps.cart.models import Cart, CartItem
from apps.voucher.api.serializers import VoucherSerializer
from apps.voucher.models import Voucher, VoucherUsage
from core.permissions import IsAdmin, IsStaffOrAdmin


@method_decorator(name="list", decorator=swagger_auto_schema(tags=['Voucher']))
@method_decorator(name="create", decorator=swagger_auto_schema(tags=['Voucher']))
@method_decorator(name="update", decorator=swagger_auto_schema(tags=['Voucher']))
@method_decorator(name="partial_update", decorator=swagger_auto_schema(tags=['Voucher']))
@method_decorator(name="retrieve", decorator=swagger_auto_schema(tags=['Voucher']))
@method_decorator(name="destroy", decorator=swagger_auto_schema(tags=['Voucher']))
class VoucherViewSet(viewsets.ModelViewSet):
    queryset = Voucher.objects.all()
    serializer_class = VoucherSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['voucher_type','discount_type']
    permission_classes = [IsStaffOrAdmin]

    @swagger_auto_schema(tags=['Voucher'], operation_summary="Lấy danh sách Voucher khách có thể dùng cho giỏ hàng hiện tại")
    @action(detail=False, methods=['get'], url_path='usable')
    def usable(self, request):
        user = request.user
        now = timezone.now()

        # 1. Tính tổng giá trị giỏ hàng hiện tại của khách
        try:
            cart = Cart.objects.get(user=user)
        except Cart.DoesNotExist:
            return Response({"detail": "Giỏ hàng trống."}, status=400)

        cart_total = CartItem.objects.filter(cart=cart).annotate(
            total=F('quantity') * F('product__sell_price')
        ).aggregate(sum_total=Sum('total'))['sum_total'] or 0

        # 2. Lọc các mã Voucher còn hiệu lực ở cấp độ Hệ thống
        system_valid_vouchers = Voucher.objects.filter(
            is_active=True,
            start_date__lte=now,
            end_date__gte=now,
            used_count__lt=F('total_usage_limit'),
            min_order_value__lte=cart_total
        )

        # 3. Lọc qua rào chắn cấp độ Cá nhân (User Usage Limit)
        usable_vouchers = []
        for voucher in system_valid_vouchers:
            # Đếm xem user này đã xài mã này bao nhiêu lần trong bảng VoucherUsage
            user_used_count = VoucherUsage.objects.filter(user=user, voucher=voucher).count()

            if user_used_count < voucher.user_usage_limit:
                usable_vouchers.append(voucher)

        # 4. Trả về Frontend để vẽ Combobox
        serializer = self.get_serializer(usable_vouchers, many=True)
        return Response({
            "current_cart_total": cart_total,
            "usable_vouchers": serializer.data
        })