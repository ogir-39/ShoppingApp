from datetime import datetime, timedelta
from decimal import Decimal
from django.db.models import Q

from django.db.models import (
    Sum,
    Count,
    F,
    OuterRef,
    Subquery,
    DecimalField,
    ExpressionWrapper,
)

from django.utils import timezone

from apps.catalog.models import Product, ProductImage
from apps.order.models import Order, OrderDetail


class ReportService:

    # =========================================================
    # DATE RANGE
    # =========================================================

    @staticmethod
    def get_datetime_range(start_date, end_date):

        start_datetime = timezone.make_aware(
            datetime.combine(
                start_date,
                datetime.min.time()
            )
        )

        end_datetime = timezone.make_aware(
            datetime.combine(
                end_date + timedelta(days=1),
                datetime.min.time()
            )
        )

        return start_datetime, end_datetime

    # =========================================================
    # BASE QUERY
    # =========================================================

    @staticmethod
    def completed_orders(start_datetime, end_datetime):

        return Order.objects.filter(
            status='COMPLETED',
            created_at__gte=start_datetime,
            created_at__lt=end_datetime
        )

    # =========================================================
    # OVERVIEW
    # =========================================================

    @staticmethod
    def get_overview(start_datetime, end_datetime):

        completed_orders = ReportService.completed_orders(
            start_datetime,
            end_datetime
        )

        # -----------------------------
        # Tổng đơn
        # -----------------------------

        total_orders = completed_orders.count()

        # -----------------------------
        # Doanh thu
        # -----------------------------

        total_revenue = (
            completed_orders
            .aggregate(
                total=Sum('final_amount')
            )['total']
            or Decimal('0')
        )

        # -----------------------------
        # Giá vốn
        # -----------------------------

        total_cost = (
            OrderDetail.objects
            .filter(
                order__status='COMPLETED',
                order__created_at__gte=start_datetime,
                order__created_at__lt=end_datetime,
            )
            .annotate(
                item_cost=ExpressionWrapper(
                    F('quantity') *
                    F('product__cost_price'),
                    output_field=DecimalField(
                        max_digits=20,
                        decimal_places=2
                    )
                )
            )
            .aggregate(
                total=Sum('item_cost')
            )['total']
            or Decimal('0')
        )

        total_profit = total_revenue - total_cost

        # -----------------------------
        # Khách hàng
        # -----------------------------

        user_order_counts = (
            completed_orders
            .values('user')
            .annotate(
                order_count=Count('id')
            )
        )

        total_buyers = user_order_counts.count()

        returning_buyers = (
            user_order_counts
            .filter(order_count__gt=1)
            .count()
        )

        retention_rate = (
            round(
                returning_buyers /
                total_buyers *
                100,
                2
            )
            if total_buyers
            else 0
        )

        return {
            'total_orders': total_orders,
            'total_revenue': total_revenue,
            'total_cost': total_cost,
            'total_profit': total_profit,
            'total_buyers': total_buyers,
            'returning_buyers': returning_buyers,
            'retention_rate': retention_rate,
        }

    # =========================================================
    # REVENUE
    # =========================================================

    @staticmethod
    def get_revenue(start_datetime, end_datetime):

        orders = ReportService.completed_orders(
            start_datetime,
            end_datetime
        )

        result = orders.aggregate(
            total_revenue=Sum('final_amount'),
            total_shipping_fee=Sum('shipping_fee'),
            total_discount=Sum(
                'discount_voucher_amount'
            ),
            total_shipping_discount=Sum(
                'shipping_voucher_amount'
            ),
            total_coin_used=Sum('coin_used'),
        )

        return {
            'total_revenue':
                result['total_revenue']
                or Decimal('0'),

            'total_shipping_fee':
                result['total_shipping_fee']
                or Decimal('0'),

            'total_discount':
                result['total_discount']
                or Decimal('0'),

            'total_shipping_discount':
                result['total_shipping_discount']
                or Decimal('0'),

            'total_coin_used':
                result['total_coin_used']
                or Decimal('0'),
        }

    # =========================================================
    # ORDERS
    # =========================================================

    @staticmethod
    def get_orders(start_datetime, end_datetime):

        orders = Order.objects.filter(
            created_at__gte=start_datetime,
            created_at__lt=end_datetime
        )

        result = orders.aggregate(
            total_orders=Count('id'),

            pending_orders=Count(
                'id',
                filter=Q(status='PENDING')
            ),

            shipping_orders=Count(
                'id',
                filter=Q(status='SHIPPING')
            ),

            completed_orders=Count(
                'id',
                filter=Q(status='COMPLETED')
            ),

            canceled_orders=Count(
                'id',
                filter=Q(status='CANCELED')
            ),
        )

        return result

    # =========================================================
    # PROFIT
    # =========================================================

    @staticmethod
    def get_profit(start_datetime, end_datetime):

        details = (
            OrderDetail.objects
            .filter(
                order__status='COMPLETED',
                order__created_at__gte=start_datetime,
                order__created_at__lt=end_datetime,
            )
            .annotate(
                revenue=ExpressionWrapper(
                    F('quantity') * F('price'),
                    output_field=DecimalField(
                        max_digits=20,
                        decimal_places=2
                    )
                ),

                cost=ExpressionWrapper(
                    F('quantity') *
                    F('product__cost_price'),
                    output_field=DecimalField(
                        max_digits=20,
                        decimal_places=2
                    )
                )
            )
        )

        result = details.aggregate(
            revenue=Sum('revenue'),
            cost=Sum('cost')
        )

        revenue = (
            result['revenue']
            or Decimal('0')
        )

        cost = (
            result['cost']
            or Decimal('0')
        )

        return {
            'revenue': revenue,
            'cost': cost,
            'profit': revenue - cost,
        }

    # =========================================================
    # TOP PRODUCTS
    # =========================================================

    @staticmethod
    def get_top_products(
        start_datetime,
        end_datetime,
        limit=5
    ):

        thumbnail_subquery = (
            ProductImage.objects
            .filter(
                product=OuterRef('pk'),
                is_thumbnail=True
            )
            .values('image')[:1]
        )

        products = (
            Product.objects
            .filter(
                orderdetail__order__status='COMPLETED',
                orderdetail__order__created_at__gte=start_datetime,
                orderdetail__order__created_at__lt=end_datetime,
            )
            .annotate(
                total_sold=Sum(
                    'orderdetail__quantity'
                ),

                thumbnail_url=Subquery(
                    thumbnail_subquery
                )
            )
            .order_by('-total_sold')
            .values(
                'id',
                'name',
                'total_sold',
                'thumbnail_url'
            )[:limit]
        )

        return list(products)

    # =========================================================
    # CUSTOMERS
    # =========================================================

    @staticmethod
    def get_customers(
        start_datetime,
        end_datetime
    ):

        completed_orders = (
            ReportService.completed_orders(
                start_datetime,
                end_datetime
            )
        )

        user_orders = (
            completed_orders
            .values('user')
            .annotate(
                order_count=Count('id')
            )
        )

        total_buyers = user_orders.count()

        returning_buyers = (
            user_orders
            .filter(
                order_count__gt=1
            )
            .count()
        )

        new_buyers = (
            total_buyers -
            returning_buyers
        )

        return {
            'total_buyers': total_buyers,
            'new_buyers': new_buyers,
            'returning_buyers': returning_buyers,
        }