from django.db import models

class NotificationType(models.TextChoices):
    ORDER = 'ORDER',
    PAYMENT = 'PAYMENT',
    VOUCHER = 'VOUCHER',
    REVIEW = 'REVIEW',
    SYSTEM = 'SYSTEM'


class Notification(models.Model):
    user = models.ForeignKey('account.User', on_delete=models.SET_NULL,null=True,blank=True)
    type = models.CharField(max_length=20, choices=NotificationType.choices)
    title = models.CharField(max_length=255)
    content = models.TextField()
    order = models.ForeignKey('order.Order', on_delete=models.SET_NULL,null=True,blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
