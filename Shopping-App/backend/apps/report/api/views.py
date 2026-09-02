from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from drf_yasg.utils import swagger_auto_schema

from core.permissions import IsStaffOrAdmin

from .serializers import ReportDateRangeSerializer
from .services import ReportService


class ReportViewSet(viewsets.ViewSet):

    permission_classes = [IsStaffOrAdmin]

    # =========================================================
    # Helper
    # =========================================================

    def get_date_range(self, request):

        serializer = ReportDateRangeSerializer(
            data=request.query_params
        )

        serializer.is_valid(
            raise_exception=True
        )

        return (
            serializer.validated_data['start_date'],
            serializer.validated_data['end_date']
        )

    # =========================================================
    # OVERVIEW
    # =========================================================

    @swagger_auto_schema(
        tags=['report'],
        query_serializer=ReportDateRangeSerializer,
        operation_summary='Thống kê tổng quan'
    )
    @action(
        methods=['get'],
        detail=False,
        url_path='overview'
    )
    def overview(self, request):

        start_date, end_date = self.get_date_range(
            request
        )

        start_datetime, end_datetime = (
            ReportService.get_datetime_range(
                start_date,
                end_date
            )
        )

        data = ReportService.get_overview(
            start_datetime,
            end_datetime
        )

        return Response({
            'start_date': start_date,
            'end_date': end_date,
            'data': data
        })

    # =========================================================
    # REVENUE
    # =========================================================

    @swagger_auto_schema(
        tags=['report'],
        query_serializer=ReportDateRangeSerializer,
        operation_summary='Thống kê doanh thu'
    )
    @action(
        methods=['get'],
        detail=False,
        url_path='revenue'
    )
    def revenue(self, request):

        start_date, end_date = self.get_date_range(
            request
        )

        start_datetime, end_datetime = (
            ReportService.get_datetime_range(
                start_date,
                end_date
            )
        )

        data = ReportService.get_revenue(
            start_datetime,
            end_datetime
        )

        return Response({
            'start_date': start_date,
            'end_date': end_date,
            'data': data
        })

    # =========================================================
    # ORDERS
    # =========================================================

    @swagger_auto_schema(
        tags=['report'],
        query_serializer=ReportDateRangeSerializer,
        operation_summary='Thống kê đơn hàng'
    )
    @action(
        methods=['get'],
        detail=False,
        url_path='orders'
    )
    def orders(self, request):

        start_date, end_date = self.get_date_range(
            request
        )

        start_datetime, end_datetime = (
            ReportService.get_datetime_range(
                start_date,
                end_date
            )
        )

        data = ReportService.get_orders(
            start_datetime,
            end_datetime
        )

        return Response({
            'start_date': start_date,
            'end_date': end_date,
            'data': data
        })

    # =========================================================
    # PROFIT
    # =========================================================

    @swagger_auto_schema(
        tags=['report'],
        query_serializer=ReportDateRangeSerializer,
        operation_summary='Thống kê lợi nhuận'
    )
    @action(
        methods=['get'],
        detail=False,
        url_path='profit'
    )
    def profit(self, request):

        start_date, end_date = self.get_date_range(
            request
        )

        start_datetime, end_datetime = (
            ReportService.get_datetime_range(
                start_date,
                end_date
            )
        )

        data = ReportService.get_profit(
            start_datetime,
            end_datetime
        )

        return Response({
            'start_date': start_date,
            'end_date': end_date,
            'data': data
        })

    # =========================================================
    # TOP PRODUCTS
    # =========================================================

    @swagger_auto_schema(
        tags=['report'],
        query_serializer=ReportDateRangeSerializer,
        operation_summary='Top sản phẩm bán chạy'
    )
    @action(
        methods=['get'],
        detail=False,
        url_path='top-products'
    )
    def top_products(self, request):

        start_date, end_date = self.get_date_range(
            request
        )

        start_datetime, end_datetime = (
            ReportService.get_datetime_range(
                start_date,
                end_date
            )
        )

        data = ReportService.get_top_products(
            start_datetime,
            end_datetime
        )

        return Response({
            'start_date': start_date,
            'end_date': end_date,
            'data': data
        })

    # =========================================================
    # CUSTOMERS
    # =========================================================

    @swagger_auto_schema(
        tags=['report'],
        query_serializer=ReportDateRangeSerializer,
        operation_summary='Thống kê khách hàng'
    )
    @action(
        methods=['get'],
        detail=False,
        url_path='customers'
    )
    def customers(self, request):

        start_date, end_date = self.get_date_range(
            request
        )

        start_datetime, end_datetime = (
            ReportService.get_datetime_range(
                start_date,
                end_date
            )
        )

        data = ReportService.get_customers(
            start_datetime,
            end_datetime
        )

        return Response({
            'start_date': start_date,
            'end_date': end_date,
            'data': data
        })