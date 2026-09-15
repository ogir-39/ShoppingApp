import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../../configs/apis.dart';
import '../../navigations/RootNavigator.dart';
import 'Register.dart';

// --- BỘ KHUNG GIAO DIỆN (CHỨA TABBAR) ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
          builder: (BuildContext tabContext) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('ShoppingApp'),
                bottom: const TabBar(tabs: [Tab(text: 'Đăng nhập'), Tab(text: 'Đăng ký')]),
              ),
              body: TabBarView(
                children: [
                  const LoginForm(), // Tab 1: Màn hình Đăng nhập (nằm ngay bên dưới)
                  RegisterScreen(tabContext: tabContext), // Tab 2: Màn hình Đăng ký (nằm ở file riêng)
                ],
              ),
            );
          }
      ),
    );
  }
}

// --- WIDGET XỬ LÝ RIÊNG CHO TAB ĐĂNG NHẬP ---
class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String? _usernameError;
  String? _passwordError;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _usernameError = _usernameCtrl.text.isEmpty ? 'Vui lòng nhập Username' : null;
      _passwordError = _passwordCtrl.text.isEmpty ? 'Vui lòng nhập Password' : null;
    });

    if (_usernameError != null || _passwordError != null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      Response res = await apis.post(
        endpoints['login'],
        data: {
          'grant_type': 'password',
          'username': _usernameCtrl.text,
          'password': _passwordCtrl.text,
          'client_id': 'bjPhc8bnXaSuFMmec52RkTAZm4WKaHKtgTxzV1gN',
          'client_secret': 'pMrExNw20ALi4SK7fz4SlmP6Ukd4hQHrqOa9rL5iac8lNImqssxEwIlIyQwd3Y6gEpJUWfguE7bzkiIE8p0STrNVVNCUqB7GPKs9XYwDrjud6ot9y3Dwk9pMUUanjWiM',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final token = res.data['access_token'];
      apis.options.headers['Authorization'] = 'Bearer $token';

      // ==============================================================
      // BƯỚC LẤY ROLE TỪ BACKEND
      // ==============================================================

      String userRole = 'CUSTOMER'; // Giá trị mặc định phòng hờ

      // TRƯỜNG HỢP 1: Nếu API Login của bạn ĐÃ TRẢ VỀ KÈM ROLE trong res.data
      if (res.data['role'] != null) {
        userRole = res.data['role'];
      }
      // TRƯỜNG HỢP 2: Nếu API Login (OAuth2) chỉ trả về mỗi access_token
      // Bạn bắt buộc phải gọi thêm 1 API nữa để lấy thông tin User hiện tại
      else {
        // Thay endpoints['current-user'] bằng endpoint thực tế lấy thông tin user của bạn (VD: /users/me/)
        Response userRes = await apis.get(endpoints['current-user']);
        userRole = userRes.data['role'];
      }

      // ==============================================================

      // Lưu token và role THỰC TẾ vào bộ nhớ máy
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      await prefs.setString('role', userRole);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(builder: (_) => RootNavigator(role:userRole))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sai tài khoản hoặc mật khẩu!'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _usernameCtrl,
            decoration: InputDecoration(
              labelText: 'Username',
              prefixIcon: const Icon(Icons.person),
              errorText: _usernameError,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
            ),
          ),
          const SizedBox(height: 20),
          _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _login, child: const Text('Đăng nhập')),
        ],
      ),
    );
  }
}