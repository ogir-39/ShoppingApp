from rest_framework import pagination


class ItemPaginator(pagination.PageNumberPagination):
    page_size = 20


class CommentPaginator(pagination.PageNumberPagination):
    page_size = 8

class OrderPaginator(pagination.PageNumberPagination):
    page_size = 10

class AccountPaginator(pagination.PageNumberPagination):
    page_size = 10