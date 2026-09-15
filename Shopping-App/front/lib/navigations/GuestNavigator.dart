import 'package:flutter/material.dart';
import 'package:front/navigations/HomeTabNavigator.dart';
import '../screens/user/Login.dart';

class GuestNavigator extends StatefulWidget {
  const GuestNavigator({Key? key}) : super(key: key);

  @override
  _GuestNavigatorState createState() => _GuestNavigatorState();
}

class _GuestNavigatorState extends State<GuestNavigator> {
  int _currentIndex = 0;
  final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();

  void _onItemTapped(int index) {
    if (_currentIndex == index && index == 0) {
      _homeNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeTabNavigator(
            navigatorKey: _homeNavigatorKey,
            role: 'GUEST',
            onNavigateToLogin: () => setState(() => _currentIndex = 1),
          ),
          const LoginScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.login), label: 'Đăng nhập'),
        ],
      ),
    );
  }
}