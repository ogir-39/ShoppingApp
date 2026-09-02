from rest_framework import permissions

class IsStaffOrAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False

        if request.method in permissions.SAFE_METHODS:
            return True
        return bool(request.user and request.user.is_authenticated and getattr(request.user, 'role', '') != 'CUSTOMER')

class IsStaffOrAdminStrict(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        return bool(request.user and request.user.is_authenticated and getattr(request.user, 'role', '') != 'CUSTOMER')

class IsAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        return bool(request.user and request.user.is_authenticated and getattr(request.user, 'role', '') == 'ADMIN')

class ReviewPermission(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user

        if not user.is_authenticated:
            return False

        # Customer được tạo review
        if request.method == 'POST':
            return user.role == 'CUSTOMER'

        # Các method khác cần xử lý tiếp ở has_object_permission
        return True

    def has_object_permission(self, request, view, obj):
        user = request.user

        # ADMIN: xem + xóa
        if user.role == 'ADMIN':
            return request.method in ['GET', 'HEAD', 'OPTIONS', 'DELETE']

        # STAFF: chỉ xem
        if user.role == 'STAFF':
            return request.method in ['GET', 'HEAD', 'OPTIONS']

        # CUSTOMER: xem + sửa + xóa review của chính mình
        if user.role == 'CUSTOMER':
            return (
                obj.user == user
                and request.method in [
                    'GET',
                    'HEAD',
                    'OPTIONS',
                    'PUT',
                    'PATCH',
                    'DELETE'
                ]
            )

        return False

class OrderPermission(permissions.BasePermission):
    def has_permission(self, request, view):
        # Bắt buộc phải đăng nhập
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        user = request.user

        # ADMIN: Được quyền Xem (GET) và Sửa (PUT, PATCH) mọi đơn hàng
        if user.role == 'ADMIN':
            return request.method in ['GET', 'HEAD', 'OPTIONS', 'PUT', 'PATCH']

        # STAFF: Chỉ được quyền Xem (GET) mọi đơn hàng
        if user.role == 'STAFF':
            return request.method in ['GET', 'HEAD', 'OPTIONS']

        # CUSTOMER: Chỉ được Xem (GET) đơn hàng do chính mình đặt
        if user.role == 'CUSTOMER':
            return (
                    obj.user == user
                    and request.method in ['GET', 'HEAD', 'OPTIONS']
            )

        return False