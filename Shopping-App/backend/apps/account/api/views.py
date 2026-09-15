from django_filters.rest_framework import DjangoFilterBackend
from oauth2_provider.contrib.rest_framework import permissions
from rest_framework import viewsets, generics, status, filters
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.account.api.serializers import UserSerializer, SimpleUserSerializer, CurrentUserSerializer
from apps.account.models import User
from core.paginators import AccountPaginator


class UserViewSet(viewsets.ViewSet,generics.ListAPIView,generics.CreateAPIView,generics.RetrieveAPIView,generics.UpdateAPIView,generics.DestroyAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    pagination_class = AccountPaginator
    filter_backends = [filters.SearchFilter, DjangoFilterBackend]
    search_fields = ['username', 'email','phone']
    filterset_fields = ['role']

    @action(methods=['get', 'patch'], url_path='current-user', detail=False, permission_classes=[permissions.IsAuthenticated])
    def current_user(self, request):
        u = request.user
        if request.method == 'PATCH':
            s = CurrentUserSerializer(u, data=request.data,partial=True)
            s.is_valid(raise_exception=True)
            u = s.save()

        return Response(UserSerializer(u).data, status=status.HTTP_200_OK)