from django.urls import path, include
from rest_framework.routers import DefaultRouter

from apps.report.api.views import ReportViewSet

router = DefaultRouter()
router.register('', ReportViewSet, basename='report')

urlpatterns = [
    path('', include(router.urls)),
]