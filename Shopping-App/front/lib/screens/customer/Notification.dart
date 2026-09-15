import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../configs/apis.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      Response res = await apis.get(endpoints['notification']);
      setState(() {
        _notifications = res.data is Map ? res.data['results'] : res.data;
        _isLoading = false;
      });
    } catch (e) {
      print("Lỗi tải thông báo: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int id, int index) async {
    if (_notifications[index]['is_read'] == true) return;

    // Cập nhật giao diện ngay lập tức cho mượt
    setState(() {
      _notifications[index]['is_read'] = true;
    });

    try {
      await apis.patch('/notification/$id/read/');
    } catch (e) {
      // Nếu lỗi thì revert lại
      setState(() {
        _notifications[index]['is_read'] = false;
      });
      print("Lỗi đánh dấu đã đọc: $e");
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var noti in _notifications) {
        noti['is_read'] = true;
      }
    });

    try {
      await apis.patch('/notification/read-all/');
    } catch (e) {
      print("Lỗi đánh dấu đọc tất cả: $e");
    }
  }

  // Gắn màu cho từng loại thông báo (Dựa vào field 'type' hoặc tên tương đương trong DB)
  Color _getUnreadColor(String? type) {
    switch (type) {
      case 'ORDER': return Colors.blue.shade50;
      case 'PROMOTION': return Colors.orange.shade50;
      case 'SYSTEM': return Colors.red.shade50;
      default: return Colors.blue.shade50; // Mặc định
    }
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'ORDER': return Icons.receipt_long;
      case 'PROMOTION': return Icons.local_offer;
      case 'SYSTEM': return Icons.warning;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: _notifications.any((n) => n['is_read'] == false) ? _markAllAsRead : null,
            child: const Text('Đọc tất cả', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
            ? const Center(child: Text('Không có thông báo nào.'))
            : ListView.builder(
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final noti = _notifications[index];
            final bool isRead = noti['is_read'] ?? false;
            final String type = noti['type'] ?? 'DEFAULT'; // Thay 'type' bằng key thực tế trong DB của bạn

            return InkWell(
              onTap: () => _markAsRead(noti['id'], index),
              child: Container(
                color: isRead ? Colors.transparent : _getUnreadColor(type),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: isRead ? Colors.grey.shade300 : Colors.blueAccent.withOpacity(0.2),
                      child: Icon(_getIcon(type), color: isRead ? Colors.grey : Colors.blueAccent),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            noti['title'] ?? 'Thông báo',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              color: isRead ? Colors.grey.shade700 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            noti['message'] ?? '',
                            style: TextStyle(color: isRead ? Colors.grey : Colors.black87),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            noti['created_at'].toString().substring(0, 16).replaceAll('T', ' '),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}