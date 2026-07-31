from django.db import transaction
from django.utils.decorators import method_decorator
from drf_yasg.utils import swagger_auto_schema
from oauth2_provider.contrib.rest_framework import permissions
from rest_framework import viewsets, generics

from apps.account.api.serializers import UserSerializer
from apps.account.models import User, Staff, Customer, UserRole
from core.permissions import IsStaffOrAdmin


class UserViewSet(viewsets.ViewSet,generics.ListAPIView,generics.CreateAPIView,generics.RetrieveAPIView,generics.UpdateAPIView,generics.DestroyAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsStaffOrAdmin]
