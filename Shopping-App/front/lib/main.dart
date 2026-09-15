import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'configs/apis.dart';
import 'navigations/RootNavigator.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized(); // Bắt buộc có dòng này
  await Firebase.initializeApp(); // Khởi tạo Firebase

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  // Mặc định là GUEST nếu chưa đăng nhập
  final role = prefs.getString('role') ?? 'GUEST';

  if (token != null) {
    apis.options.headers['Authorization'] = 'Bearer $token';
  }

  // Khởi chạy ứng dụng và đưa thẳng vào bộ bọc điều hướng chính
  runApp(MyApp(role: role));
}

class MyApp extends StatelessWidget {
  final String role;
  const MyApp({Key? key, required this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shopping App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: RootNavigator(role: role),
    );
  }
}