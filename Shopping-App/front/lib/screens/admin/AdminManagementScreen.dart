import 'package:flutter/material.dart';

import 'AdminAccount.dart'; // Chứa ManageAccountScreen[cite: 76]
import 'AdminCategory.dart'; // Chứa ManageCategoryScreen[cite: 77]
import 'AdminProduct.dart'; // Chứa ManageProductScreen[cite: 78]
import 'AdminVoucher.dart'; // Chứa ManageVoucherScreen[cite: 79]

class AdminManagementScreen extends StatelessWidget {
  const AdminManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý hệ thống'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildManagementCard(
            context,
            title: 'Quản lý Tài khoản (Staff/Khách)',
            icon: Icons.manage_accounts,
            color: Colors.purple,
            targetScreen: const ManageAccountScreen(), // Điều hướng sang Danh sách User[cite: 75, 76]
          ),
          _buildManagementCard(
            context,
            title: 'Quản lý Voucher',
            icon: Icons.local_offer,
            color: Colors.pink,
            targetScreen: const ManageVoucherScreen(), // Điều hướng sang Danh sách Voucher[cite: 75, 79]
          ),
          _buildManagementCard(
            context,
            title: 'Quản lý Danh mục',
            icon: Icons.category,
            color: Colors.blue,
            targetScreen: const ManageCategoryScreen(), // Điều hướng sang Danh sách Category[cite: 75, 77]
          ),
          _buildManagementCard(
            context,
            title: 'Quản lý Sản phẩm',
            icon: Icons.inventory,
            color: Colors.green,
            targetScreen: const ManageProductScreen(), // Điều hướng sang Danh sách Product[cite: 75, 78]
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard(BuildContext context, {required String title, required IconData icon, required Color color, required Widget targetScreen}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen));
        },
      ),
    );
  }
}