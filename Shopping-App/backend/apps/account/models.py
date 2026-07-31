from django.contrib.auth.models import AbstractUser
from django.db import models

class UserRole(models.TextChoices):
    ADMIN = 'ADMIN'
    STAFF = 'STAFF'
    CUSTOMER = 'CUSTOMER'

class User(AbstractUser):
    role = models.CharField(max_length=20, choices=UserRole.choices, default=UserRole.CUSTOMER)
    address = models.CharField(max_length=200, null=False, blank=False)
    phone = models.CharField(max_length=20, null=False, blank=False)
    created_at = models.DateTimeField(auto_now_add=True)


class Customer(models.Model):
    user = models.OneToOneField('account.User', on_delete=models.CASCADE, primary_key=True)
    coins = models.DecimalField(max_digits=10, decimal_places=2, default=0)


class Staff(models.Model):
    user = models.OneToOneField('account.User', on_delete=models.CASCADE, primary_key=True)
    salary = models.DecimalField(max_digits=10, decimal_places=2, default=0)