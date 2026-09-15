import 'package:flutter/material.dart';
import 'package:front/configs/apis.dart';

class StaffOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const StaffOrderDetailScreen({Key? key, required this.order}) : super(key: key);

  @override
  _StaffOrderDetailScreenState createState() => _StaffOrderDetailScreenState();
}

class _StaffOrderDetailScreenState extends State<StaffOrderDetailScreen> {
  late String currentStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.order['status'] ?? 'PENDING';
  }

  // Gọi API tương ứng dựa theo action
  Future<void> _updateOrderStatus(String action) async {
    setState(() => _isLoading = true);
    try {
      // Các endpoint này được định nghĩa ở Backend (VD: /orders/{id}/confirm/)
      await apis.patch('/order/${widget.order['id']}/$action/');

      setState(() {
        if (action == 'confirm') currentStatus = 'READY';
        if (action == 'ship') currentStatus = 'SHIPPING';
        if (action == 'complete') currentStatus = 'COMPLETED';
      });
      Navigator.pop(context); // Đóng BottomSheet
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật trạng thái thành công!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi cập nhật. Hãy kiểm tra lại điều kiện thanh toán/trạng thái.'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showUpdateBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Cập nhật trạng thái đơn hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // PENDING -> READY
              ElevatedButton(
                onPressed: currentStatus == 'PENDING' ? () => _updateOrderStatus('confirm') : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, disabledBackgroundColor: Colors.grey[300]),
                child: const Text('Xác nhận đơn'),
              ),

              // READY -> SHIPPING
              ElevatedButton(
                onPressed: currentStatus == 'READY' ? () => _updateOrderStatus('ship') : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, disabledBackgroundColor: Colors.grey[300]),
                child: const Text('Đang vận chuyển'),
              ),

              // SHIPPING -> COMPLETED
              ElevatedButton(
                onPressed: currentStatus == 'SHIPPING' ? () => _updateOrderStatus('complete') : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, disabledBackgroundColor: Colors.grey[300]),
                child: const Text('Hoàn thành'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> products = widget.order['details'] ?? [];

    return Scaffold(
      appBar: AppBar(title: Text('Chi tiết Order #${widget.order['id']}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trạng thái hiện tại: $currentStatus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _getStatusColor(currentStatus))),
            const Divider(),
            Text('Người nhận: ${widget.order['recipient_name']}'),
            Text('SĐT: ${widget.order['recipient_phone']}'),
            Text('Địa chỉ: ${widget.order['shipping_address']}'),
            Text('Thanh toán: ${widget.order['payment_status']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            const Text('DANH SÁCH SẢN PHẨM:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final item = products[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag, color: Colors.blueAccent),
                    title: Text('Sản phẩm ID: ${item['product']}'),
                    subtitle: Text('Số lượng: ${item['quantity']}  -  Đơn giá: ${item['price']} đ'),
                  ),
                );
              },
            ),

            const Divider(thickness: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng thanh toán:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${widget.order['final_amount']} đ', style: const TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: (currentStatus != 'COMPLETED' && currentStatus != 'CANCELED')
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _showUpdateBottomSheet,
          child: const Text('CẬP NHẬT ĐƠN HÀNG', style: TextStyle(fontSize: 16)),
        ),
      )
          : null, // Ẩn nút nếu đơn đã xong hoặc hủy
    );
  }

  Color _getStatusColor(String status) {
    switch(status) {
      case 'PENDING': return Colors.orange;
      case 'READY': return Colors.blueAccent;
      case 'SHIPPING': return Colors.purple;
      case 'COMPLETED': return Colors.green;
      case 'CANCELED': return Colors.red;
      default: return Colors.black;
    }
  }
}