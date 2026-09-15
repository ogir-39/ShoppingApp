import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ==============================================================
// 1. MÀN HÌNH DANH SÁCH CHAT (CỦA STAFF)
// ==============================================================
class StaffChatListScreen extends StatelessWidget {
  const StaffChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hỗ trợ Khách hàng (Staff)')),
      body: StreamBuilder<QuerySnapshot>(
        // Sắp xếp các phòng chat theo thời gian hoạt động gần nhất
        stream: FirebaseFirestore.instance.collection('chats').orderBy('last_active', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Chưa có tin nhắn nào từ khách hàng.', style: TextStyle(color: Colors.grey)));
          }

          final customers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              String customerUsername = customers[index].id;

              // Lấy thêm data từ document cha (nếu có)
              // var data = customers[index].data() as Map<String, dynamic>?;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text(customerUsername.isNotEmpty ? customerUsername[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(customerUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Nhấn để xem tin nhắn...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => StaffChatDetailScreen(customerUsername: customerUsername)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==============================================================
// 2. MÀN HÌNH CHI TIẾT TRẢ LỜI TIN NHẮN (CỦA STAFF)
// ==============================================================
class StaffChatDetailScreen extends StatefulWidget {
  final String customerUsername;
  const StaffChatDetailScreen({Key? key, required this.customerUsername}) : super(key: key);

  @override
  _StaffChatDetailScreenState createState() => _StaffChatDetailScreenState();
}

class _StaffChatDetailScreenState extends State<StaffChatDetailScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _sendMessage() async {
    if (_messageCtrl.text.trim().isEmpty) return;

    String text = _messageCtrl.text.trim();
    _messageCtrl.clear();

    // 1. Cập nhật thời gian hoạt động của phòng chat
    await _firestore.collection('chats').doc(widget.customerUsername).set({
      'last_active': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Ghi tin nhắn
    await _firestore
        .collection('chats')
        .doc(widget.customerUsername)
        .collection('messages')
        .add({
      'text': text,
      'sender': 'STAFF', // Đánh dấu là nhân viên
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat với ${widget.customerUsername}', style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.customerUsername)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Trống.', style: TextStyle(color: Colors.grey)));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index].data() as Map<String, dynamic>;

                    bool isMe = msg['sender'] == 'STAFF';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.green.shade600 : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(15),
                            topRight: const Radius.circular(15),
                            bottomLeft: isMe ? const Radius.circular(15) : const Radius.circular(0),
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(15),
                          ),
                          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                msg['sender'] ?? 'Khách',
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            Text(
                              msg['text'] ?? '',
                              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // KHU VỰC NHẬP TIN NHẮN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: InputDecoration(
                        hintText: 'Trả lời khách hàng...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}