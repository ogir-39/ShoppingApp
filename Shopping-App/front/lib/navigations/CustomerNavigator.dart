import 'package:flutter/material.dart';
import 'package:front/navigations/HomeTabNavigator.dart';
import '../screens/customer/Order.dart';
import '../screens/customer/Notification.dart';
import '../screens/customer/Profile.dart';

class CustomerNavigator extends StatefulWidget {
  const CustomerNavigator({Key? key}) : super(key: key);

  @override
  _CustomerNavigatorState createState() => _CustomerNavigatorState();
}

class _CustomerNavigatorState extends State<CustomerNavigator> {
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
          HomeTabNavigator(navigatorKey: _homeNavigatorKey, role: 'CUSTOMER'),
          const OrderScreen(),
          const NotificationScreen(),
          const ProfileScreen(),
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
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Đơn hàng'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Thông báo'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}