from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.account.models import User
from apps.order.models import Order, Payment
from apps.notification.models import Notification, NotificationType

# 1. Kịch bản SYSTEM: Tự động chào mừng khi có User mới đăng ký
@receiver(post_save, sender=User)
def send_welcome_notification(sender, instance, created, **kwargs):
    if created: # Chỉ bắn thông báo khi tài khoản MỚI được tạo
        Notification.objects.create(
            user=instance,
            type=NotificationType.SYSTEM,
            title="Chào mừng đến với Shopping App",
            content="Cảm ơn bạn đã đăng ký tài khoản. Chúc bạn mua sắm vui vẻ!"
        )

# 2. Kịch bản PAYMENT: Tự động báo khi thanh toán thành công
@receiver(post_save, sender=Payment)
def send_payment_notification(sender, instance, created, **kwargs):
    if instance.status == 'PAID':
        Notification.objects.get_or_create(
            user=instance.order.user,
            type=NotificationType.PAYMENT,
            order=instance.order,
            defaults={
                'title': "Thanh toán thành công",
                'content': f"Giao dịch {instance.amount}đ cho đơn hàng #{instance.order.id} đã hoàn tất."
            }
        )

# 3. Kịch bản ORDER & REVIEW: Lắng nghe trạng thái đơn hàng
@receiver(post_save, sender=Order)
def send_order_and_review_notification(sender, instance, created, **kwargs):
    if created:
        # Khi đơn hàng vừa được tạo (Checkout)
        Notification.objects.create(
            user=instance.user,
            type=NotificationType.ORDER,
            title=f"Đặt hàng thành công #{instance.id}",
            content="Đơn hàng của bạn đang chờ xác nhận.",
            order=instance
        )
    else:
        # Khi Admin/Staff cập nhật trạng thái đơn hàng
        if instance.status == 'SHIPPING':
            Notification.objects.get_or_create(
                user=instance.user, type=NotificationType.ORDER, order=instance,
                title=f"Đơn hàng #{instance.id} đang giao",
                defaults={'content': "Đơn hàng đã được bàn giao cho đơn vị vận chuyển."}
            )
        elif instance.status == 'COMPLETED':
            # Bắn thông báo hoàn thành đơn
            Notification.objects.get_or_create(
                user=instance.user, type=NotificationType.ORDER, order=instance,
                title=f"Đơn hàng #{instance.id} giao thành công",
                defaults={'content': "Cảm ơn bạn đã mua sắm!"}
            )
            # Kích hoạt luôn thông báo nhắc nhở REVIEW
            Notification.objects.get_or_create(
                user=instance.user, type=NotificationType.REVIEW, order=instance,
                title="Đánh giá sản phẩm",
                defaults={'content': f"Bạn thấy các sản phẩm trong đơn #{instance.id} thế nào? Hãy để lại đánh giá nhé!"}
            )