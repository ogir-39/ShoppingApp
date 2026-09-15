import 'package:flutter/material.dart';
import '../screens/user/HomeScreen.dart';

class HomeTabNavigator extends StatelessWidget {
  final String role;
  final VoidCallback? onNavigateToLogin;
  final GlobalKey<NavigatorState>? navigatorKey; // THÊM BIẾN NÀY

  const HomeTabNavigator({Key? key, required this.role, this.onNavigateToLogin, this.navigatorKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey, // GẮN KEY VÀO BỘ ĐIỀU HƯỚNG
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => HomeScreen(role: role, onNavigateToLogin: onNavigateToLogin),
        );
      },
    );
  }
}