import 'package:flutter/material.dart';
import 'package:front/navigations/AdminNavigator.dart';
import 'GuestNavigator.dart';
import 'CustomerNavigator.dart';
import 'StaffNavigator.dart';

class RootNavigator extends StatelessWidget {
  final String role;
  const RootNavigator({Key? key, required this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tương đương với logic: user.role === 'STAFF' ? <StaffStack/> : ...
    switch (role.toUpperCase()) {
      case 'STAFF':
        return const StaffNavigator();
      case 'ADMIN':
        return const AdminNavigator();
      case 'CUSTOMER':
        return const CustomerNavigator();
      case 'GUEST':
      default:
        return const GuestNavigator();
    }
  }
}