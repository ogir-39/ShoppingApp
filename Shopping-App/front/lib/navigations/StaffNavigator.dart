import 'package:flutter/material.dart';
import 'package:front/navigations/HomeTabNavigator.dart';
import '../screens/staff/StaffOrder.dart';
import '../screens/staff/StaffProduct.dart'; // File mới tạo ở phần dưới
import '../screens/staff/StaffChat.dart'; // File mới tạo ở phần dưới
import '../screens/customer/Profile.dart';

class StaffNavigator extends StatefulWidget {
  const StaffNavigator({Key? key}) : super(key: key);

  @override
  _StaffNavigatorState createState() => _StaffNavigatorState();
}

class _StaffNavigatorState extends State<StaffNavigator> {
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
    final List<Widget> screens = [
      const ProfileScreen(),
      const StaffOrderScreen(),
      const StaffProductScreen(), // Màn hình quản lý sản phẩm
      const StaffChatListScreen(), // Màn hình Chat
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Hồ sơ'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Đơn hàng'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Sản phẩm'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }
}