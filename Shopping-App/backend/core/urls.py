from django.urls import path, include, re_path
from django.views.generic import RedirectView
from drf_yasg import openapi
from drf_yasg.views import get_schema_view
from rest_framework import permissions

from core.admin import admin_site

schema_view = get_schema_view(
    openapi.Info(
        title="ShoppingApp API",
        default_version='v1',
        description="APIs for ShoppingApp",
        contact=openapi.Contact(email="2351050208vy@ou.edu.vn"),
        license=openapi.License(name="Trần Phương Vy"),
    ),
    public=True,
    permission_classes=(permissions.AllowAny,),
)

urlpatterns = [
    path('', RedirectView.as_view(url='/account/')),
    path('account/', include('apps.account.urls')),
    path('cart/', include('apps.cart.urls')),
    path('catalog/', include('apps.catalog.urls')),
    path('order/', include('apps.order.urls')),
    path('review/', include('apps.review.urls')),
    path('voucher/', include('apps.voucher.urls')),
    path('admin/', admin_site.urls),
    path('o/', include('oauth2_provider.urls',
                       namespace='oauth2_provider')),
    re_path(r'^swagger(?P<format>\.json|\.yaml)$',
            schema_view.without_ui(cache_timeout=0),
            name='schema-json'),
    re_path(r'^swagger/$',
            schema_view.with_ui('swagger', cache_timeout=0),
            name='schema-swagger-ui'),
    re_path(r'^redoc/$',
            schema_view.with_ui('redoc', cache_timeout=0),
            name='schema-redoc'),
]
