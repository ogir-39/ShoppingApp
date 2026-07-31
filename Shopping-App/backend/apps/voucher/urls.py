from django.urls import path, include
from rest_framework.routers import DefaultRouter

# from ..accounts.api.views import UserViewSet,DoctorViewSet

router = DefaultRouter()
# router.register('users', UserViewSet, basename='user')
#
# router.register('doctors', DoctorViewSet, basename='doctor')

urlpatterns = [
    path('', include(router.urls)),
]