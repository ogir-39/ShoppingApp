from django.db import models

class Category(models.Model):
    name = models.CharField(max_length=50, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class Product(models.Model):
    category = models.ForeignKey('catalog.Category', on_delete=models.CASCADE)
    name = models.CharField(max_length=150,null=False, blank=False)
    description = models.TextField(max_length=500)
    cost_price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    sell_price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    stock_quantity = models.PositiveIntegerField(default=0)
    weight = models.FloatField(default=0)
    thumbnail = models.CharField(max_length=500)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class ProductImage(models.Model):
    product = models.ForeignKey('catalog.Product', on_delete=models.CASCADE,related_name='prod_images')
    img = models.CharField(max_length=500)
    created_at = models.DateTimeField(auto_now_add=True)
