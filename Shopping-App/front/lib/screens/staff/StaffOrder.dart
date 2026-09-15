import 'package:flutter/material.dart';
import 'package:front/configs/apis.dart';
import 'StaffOrderDetail.dart';

class StaffOrderScreen extends StatefulWidget {
  const StaffOrderScreen({Key? key}) : super(key: key);

  @override
  _StaffOrderScreenState createState() => _StaffOrderScreenState();
}

class _StaffOrderScreenState extends State<StaffOrderScreen> {
  List<dynamic> orders = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String searchQuery = '';
  String? filterStatus;
  String? filterPaymentStatus;
  DateTimeRange? filterDateRange;

  bool isLoading = true;
  int _currentPage = 1;
  bool _hasNext = false;
  bool _hasPrevious = false; // Thêm cờ cho trang trước

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'READY': return Colors.blueAccent;
      case 'SHIPPING': return Colors.purple;
      case 'COMPLETED': return Colors.green;
      case 'CANCELED': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    int val = double.tryParse(amount.toString())?.toInt() ?? 0;
    String formatted = val.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
    return formatted;
  }

  @override
  void initState() {
    super.initState();
    _fetchOrders(page: 1);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders({int page = 1}) async {
    setState(() => isLoading = true);

    try {
      Map<String, dynamic> params = {'page': page};
      if (searchQuery.isNotEmpty) params['search'] = searchQuery;
      if (filterStatus != null) params['status'] = filterStatus;
      if (filterPaymentStatus != null) params['payment_status'] = filterPaymentStatus;
      if (filterDateRange != null) {
        params['start_date'] = filterDateRange!.start.toIso8601String().split('T')[0];
        params['end_date'] = filterDateRange!.end.toIso8601String().split('T')[0];
      }

      final res = await apis.get('/order/', queryParameters: params);

      if (mounted) {
        setState(() {
          _currentPage = page;
          if (res.data is Map && res.data.containsKey('results')) {
            _hasNext = res.data['next'] != null;
            _hasPrevious = res.data['previous'] != null; // Cập nhật cờ previous
            orders = res.data['results']; // Luôn ghi đè thay vì addAll
          } else {
            orders = res.data;
            _hasNext = false;
            _hasPrevious = false;
          }
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: filterDateRange,
    );
    if (picked != null) {
      setState(() => filterDateRange = picked);
      _fetchOrders(page: 1);
    }
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      searchQuery = '';
      filterStatus = null;
      filterPaymentStatus = null;
      filterDateRange = null;
    });
    _fetchOrders(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Đơn hàng'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _resetFilters)
        ],
      ),
      body: Column(
        children: [
          // BỘ LỌC
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Tìm người nhận, SĐT...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => searchQuery = '');
                              _fetchOrders(page: 1);
                            },
                          )
                              : null,
                        ),
                        onChanged: (val) => setState(() => searchQuery = val),
                        onSubmitted: (_) => _fetchOrders(page: 1),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.date_range, color: filterDateRange != null ? Colors.red : Colors.blue),
                      onPressed: _selectDateRange,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("Trạng thái đơn"),
                        value: filterStatus,
                        items: ['Tất cả', 'PENDING', 'READY', 'SHIPPING', 'COMPLETED', 'CANCELED']
                            .map((e) => DropdownMenuItem(value: e == 'Tất cả' ? null : e, child: Text(e)))
                            .toList(),
                        onChanged: (val) {
                          setState(() => filterStatus = val == 'Tất cả' ? null : val);
                          _fetchOrders(page: 1);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("Thanh toán"),
                        value: filterPaymentStatus,
                        items: ['Tất cả', 'UNPAID', 'PAID']
                            .map((e) => DropdownMenuItem(value: e == 'Tất cả' ? null : e, child: Text(e)))
                            .toList(),
                        onChanged: (val) {
                          setState(() => filterPaymentStatus = val == 'Tất cả' ? null : val);
                          _fetchOrders(page: 1);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // DANH SÁCH ĐƠN HÀNG
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: () => _fetchOrders(page: _currentPage),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      String statusStr = order['status'] ?? 'UNKNOWN';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => StaffOrderDetailScreen(order: order)));
                            _fetchOrders(page: _currentPage); // Reload
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Order ID: #${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 5),
                                      Text('Khách: ${order['recipient_name']}'),
                                      Text('Ngày tạo: ${order['created_at'].toString().split('T')[0]}'),
                                      Text('Thanh toán: ${order['payment_status']}'),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(statusStr).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(statusStr, style: TextStyle(color: _getStatusColor(statusStr), fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 15),
                                    Text('${_formatCurrency(order['final_amount'])} đ', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // ĐIỀU HƯỚNG PHÂN TRANG (Tương tự HomeScreen)
                  if (orders.isNotEmpty || _hasPrevious)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _hasPrevious ? () => _fetchOrders(page: _currentPage - 1) : null,
                            icon: const Icon(Icons.chevron_left, size: 18),
                            label: const Text('Trước'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text('Trang $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          ElevatedButton(
                            onPressed: _hasNext ? () => _fetchOrders(page: _currentPage + 1) : null,
                            child: Row(children: const [Text('Sau'), SizedBox(width: 4), Icon(Icons.chevron_right, size: 18)]),
                          ),
                        ],
                      ),
                    )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}