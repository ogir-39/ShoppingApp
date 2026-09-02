from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

class Review(models.Model):
    user = models.ForeignKey('account.User', on_delete=models.SET_NULL,null=True,blank=True)
    order_item = models.OneToOneField('order.OrderDetail', on_delete=models.SET_NULL,null=True,blank=True)
    product = models.ForeignKey('catalog.Product', on_delete=models.PROTECT)
    comment = models.TextField(max_length=500)
    rating = models.PositiveIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
