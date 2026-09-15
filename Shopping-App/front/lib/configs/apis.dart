import 'package:dio/dio.dart';

const String SERVER_URL = 'https://matrix-plop-pavement.ngrok-free.dev'; // Dùng link Ngrok nếu test trên máy thật

final Map<String, dynamic> endpoints = {
  'login': '/o/token/',
  'register': '/account/',
  'products': '/catalog/products/',
  'categories': '/catalog/categories/',
  'checkout': '/order/checkout/',
  'review': '/review/',
  'order':'/order/',
  'notification':'/notification/',
  'cart':'/cart/',
  'cart-item':'/cart/items/',
  'account':'/account/',
  'current-user':'/account/current-user/',
  'voucher':'/voucher/',
};

// Khởi tạo instance kết nối API mặc định
final Dio apis = Dio(
  BaseOptions(
    baseUrl: SERVER_URL,
    connectTimeout: const Duration(seconds: 2),
    receiveTimeout: const Duration(seconds: 2),
    headers: {'Content-Type': 'application/json'},
  ),
);