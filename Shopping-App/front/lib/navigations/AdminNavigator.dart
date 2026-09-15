import 'package:flutter/material.dart';
import '../screens/admin/AdminHomeScreen.dart';
import '../screens/admin/AdminManagementScreen.dart';
import '../screens/customer/Profile.dart';

class AdminNavigator extends StatefulWidget {
  const AdminNavigator({Key? key}) : super(key: key);

  @override
  _AdminNavigatorState createState() => _AdminNavigatorState();
}

class _AdminNavigatorState extends State<AdminNavigator> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          AdminHomeScreen(),
          AdminManagementScreen(), // Tab 2: Quản lý
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize), label: 'Quản lý'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}