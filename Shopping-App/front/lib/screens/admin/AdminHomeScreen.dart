import 'package:flutter/material.dart';
import 'package:front/configs/apis.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Đảm bảo bạn import đúng đường dẫn đến các file chứa màn hình Manage (đã tạo ở bước trước)
import '../../navigations/RootNavigator.dart';
import 'AdminAccount.dart'; // Chứa ManageAccountScreen[cite: 76]
import 'AdminCategory.dart'; // Chứa ManageCategoryScreen[cite: 77]
import 'AdminProduct.dart'; // Chứa ManageProductScreen[cite: 78]
import 'AdminVoucher.dart'; // Chứa ManageVoucherScreen[cite: 79]

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  _AdminHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  DateTime? startDate;
  DateTime? endDate;
  bool _isLoading = true;

  Map<String, dynamic>? overviewData;
  Map<String, dynamic>? orderData;
  List<dynamic> topProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('role');
    apis.options.headers.remove('Authorization');

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootNavigator(role: 'GUEST'))
      );
    }
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);

    try {
      String queryParams = startDate != null && endDate != null
          ? '?start_date=${startDate!.toIso8601String().split('T')[0]}&end_date=${endDate!.toIso8601String().split('T')[0]}'
          : '';

      final responses = await Future.wait([
        apis.get('/report/overview/$queryParams'),
        apis.get('/report/orders/$queryParams'),
        apis.get('/report/top-products/$queryParams'),
      ]);

      if (mounted) {
        setState(() {
          overviewData = responses[0].data['data'];
          orderData = responses[1].data['data'];
          topProducts = responses[2].data['data'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi tải dữ liệu báo cáo!'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _fetchReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Lọc theo ngày',
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchReportData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (startDate != null && endDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Dữ liệu từ: ${startDate!.toLocal().toString().split(' ')[0]} đến ${endDate!.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),

              const Text('TỔNG QUAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _buildStatCard('Doanh thu', '${overviewData?['total_revenue'] ?? 0} đ', Icons.attach_money, Colors.green),
                  _buildStatCard('Lợi nhuận', '${overviewData?['total_profit'] ?? 0} đ', Icons.trending_up, Colors.blue),
                  _buildStatCard('Tổng đơn', '${overviewData?['total_orders'] ?? 0}', Icons.receipt, Colors.orange),
                  _buildStatCard('Tỉ lệ mua lại', '${overviewData?['retention_rate'] ?? 0}%', Icons.repeat, Colors.purple),
                ],
              ),

              const SizedBox(height: 20),

              const Text('TRẠNG THÁI ĐƠN HÀNG', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildOrderRow('Chờ xử lý (PENDING)', orderData?['pending_orders'] ?? 0, Colors.orange),
                      const Divider(),
                      _buildOrderRow('Đang giao (SHIPPING)', orderData?['shipping_orders'] ?? 0, Colors.blue),
                      const Divider(),
                      _buildOrderRow('Hoàn thành (COMPLETED)', orderData?['completed_orders'] ?? 0, Colors.green),
                      const Divider(),
                      _buildOrderRow('Đã hủy (CANCELED)', orderData?['canceled_orders'] ?? 0, Colors.red),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text('TOP SẢN PHẨM BÁN CHẠY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              topProducts.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Chưa có dữ liệu sản phẩm."),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topProducts.length,
                itemBuilder: (context, index) {
                  final product = topProducts[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(product['name'] ?? 'Không tên'),
                      trailing: Text(
                          'Đã bán: ${product['total_sold'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(count.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}