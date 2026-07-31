from django.db import models

class Review(models.Model):
    user = models.ForeignKey('account.User', on_delete=models.CASCADE)
    order_item = models.OneToOneField('order.OrderDetail', on_delete=models.CASCADE)
    product = models.ForeignKey('catalog.Product', on_delete=models.CASCADE)
    comment = models.TextField(max_length=500)
    rating = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
