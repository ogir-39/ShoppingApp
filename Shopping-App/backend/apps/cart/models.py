from django.db import models

class Cart(models.Model):
    user = models.OneToOneField('account.User', on_delete=models.CASCADE)
    updated_at = models.DateTimeField(auto_now=True)

class CartItem(models.Model):
    cart = models.ForeignKey('cart.Cart', on_delete=models.CASCADE,related_name='items')
    product = models.ForeignKey('catalog.Product', on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint( #Khách sẽ thấy 2 dòng áo thay vì 1 dòng số lượng 2 nếu ko có contrainst này
                fields=['cart', 'product'],
                name='unique_cart_product'
            )
        ]