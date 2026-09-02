from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.db import models

class Category(models.Model):
    name = models.CharField(max_length=50, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class Category(models.Model):
    name = models.CharField(max_length=50, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class Product(models.Model):
    category = models.ForeignKey('catalog.Category', on_delete=models.PROTECT)
    name = models.CharField(max_length=150,null=False, blank=False)
    description = models.TextField(max_length=500)
    cost_price = models.DecimalField(max_digits=10, decimal_places=2, default=0,validators=[MinValueValidator(0)])
    sell_price = models.DecimalField(max_digits=10, decimal_places=2, default=0,validators=[MinValueValidator(0)])
    stock_quantity = models.PositiveIntegerField(default=0)
    weight = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class ProductImage(models.Model):
    product = models.ForeignKey('catalog.Product', on_delete=models.CASCADE)
    image = models.CharField(max_length=500)
    is_thumbnail = models.BooleanField(default=False)
    sort_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["sort_order"]

    def clean(self):
        if self.is_thumbnail:
            exists = ProductImage.objects.filter(
                product=self.product,
                is_thumbnail=True
            ).exclude(pk=self.pk).exists()
            if exists:
                raise ValidationError({'is_thumbnail': 'Only one thumbnail is allowed.'})
