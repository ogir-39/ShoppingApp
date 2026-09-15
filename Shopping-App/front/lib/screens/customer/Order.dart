import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../configs/apis.dart';

import '../user/ProductDetail.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({Key? key}) : super(key: key);

  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  List<dynamic> _allOrders = [];
  List<dynamic> _displayedOrders = [];
  bool _isLoading = true;

  int _currentPage = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;

  String _selectedStatus = 'ALL';
  String _selectedPaymentStatus = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchOrders(page: 1);
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'PENDING': return 'Chờ xử lý';
      case 'READY': return 'Sẵn sàng';
      case 'SHIPPING': return 'Đang giao hàng';
      case 'COMPLETED': return 'Hoàn thành';
      case 'CANCELED': return 'Đã hủy';
      default: return status;
    }
  }

  String _translatePayment(String status) {
    switch (status) {
      case 'UNPAID': return 'Chưa thanh toán';
      case 'PAID': return 'Đã thanh toán';
      default: return status;
    }
  }

  void _applyFilters() {
    setState(() {
      _displayedOrders = _allOrders.where((order) {
        if (_selectedStatus != 'ALL' && order['status'] != _selectedStatus) return false;
        if (_selectedPaymentStatus != 'ALL' && order['payment_status'] != _selectedPaymentStatus) return false;
        if (_startDate != null || _endDate != null) {
          DateTime orderDate = DateTime.parse(order['created_at']);
          if (_startDate != null && orderDate.isBefore(_startDate!)) return false;
          if (_endDate != null && orderDate.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _fetchOrders({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _currentPage = page;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null) {
        apis.options.headers['Authorization'] = 'Bearer $token';
      }

      Response res = await apis.get(
        endpoints['order'],
        queryParameters: {'page': page},
      );

      setState(() {
        if (res.data is Map && res.data.containsKey('results')) {
          _allOrders = res.data['results'];
          _hasNext = res.data['next'] != null;
          _hasPrevious = res.data['previous'] != null;
        } else {
          _allOrders = res.data;
          _hasNext = false;
          _hasPrevious = false;
        }
        _isLoading = false;
        _applyFilters();
      });
    } catch (e) {
      print("Lỗi tải đơn hàng: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payOrder(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null) apis.options.headers['Authorization'] = 'Bearer $token';

      Response res = await apis.post('${endpoints['order']}$orderId/pay_vnpay/');
      String payUrl = res.data['payUrl'];

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VNPayWebScreen(url: payUrl),
        ),
      );

      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green));
        _fetchOrders(page: _currentPage);
      } else if (result == false) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanh toán bị hủy hoặc thất bại!'), backgroundColor: Colors.red));
      }
    } catch (e) {
      print("LỖI THANH TOÁN: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khởi tạo thanh toán')));
    }
  }

  Future<void> _selectDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blueAccent),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _applyFilters();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'ALL';
      _selectedPaymentStatus = 'ALL';
      _startDate = null;
      _endDate = null;
      _applyFilters();
    });
  }

  Future<void> _handleEditReview(int orderItemId, int productId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      Response res = await apis.get('/review/', queryParameters: {'product': productId});
      Navigator.pop(context);

      List<dynamic> reviews = res.data is Map && res.data.containsKey('results') ? res.data['results'] : res.data;

      var existingReview = reviews.firstWhere((r) => r['order_item'] == orderItemId, orElse: () => null);

      if (existingReview != null) {
        _openReviewDialog(orderItemId, productId, existingReview: existingReview);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy đánh giá cũ.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi tải thông tin đánh giá.'), backgroundColor: Colors.red));
    }
  }

  void _openReviewDialog(int orderItemId, int productId, {Map<String, dynamic>? existingReview}) {
    double _rating = existingReview != null ? double.tryParse(existingReview['rating'].toString()) ?? 5.0 : 5.0;
    TextEditingController _commentCtrl = TextEditingController(text: existingReview != null ? existingReview['comment'] : '');
    bool _isSubmitting = false;
    bool isUpdateMode = existingReview != null;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                  title: Text(isUpdateMode ? 'Chỉnh sửa đánh giá' : 'Đánh giá sản phẩm', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                icon: Icon(index < _rating ? Icons.star : Icons.star_border, color: Colors.orange, size: 30),
                                onPressed: () => setStateDialog(() => _rating = index + 1.0),
                              );
                            })
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _commentCtrl,
                          decoration: const InputDecoration(hintText: 'Nhập nhận xét của bạn...', border: OutlineInputBorder()),
                          maxLines: 3,
                        )
                      ]
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: isUpdateMode ? Colors.green : Colors.blueAccent),
                        onPressed: _isSubmitting ? null : () async {
                          setStateDialog(() => _isSubmitting = true);
                          try {
                            if (isUpdateMode) {
                              int reviewId = existingReview['id'];
                              await apis.patch('/review/$reviewId/', data: {
                                'rating': _rating.toInt(),
                                'comment': _commentCtrl.text
                              });
                            } else {
                              await apis.post('/review/', data: {
                                'order_item': orderItemId,
                                'rating': _rating.toInt(),
                                'comment': _commentCtrl.text
                              });
                            }

                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cảm ơn bạn đã đóng góp!'), backgroundColor: Colors.green));

                            _fetchOrders(page: _currentPage);
                          } catch (e) {
                            String err = 'Đã có lỗi xảy ra!';
                            if (e is DioException && e.response != null && e.response!.data != null) {
                              var resData = e.response!.data;
                              if (resData is Map) {
                                var firstVal = resData.values.first;
                                if (firstVal is List && firstVal.isNotEmpty) {
                                  err = firstVal[0].toString();
                                } else {
                                  err = firstVal.toString();
                                }
                              } else if (resData is List && resData.isNotEmpty) {
                                err = resData[0].toString();
                              }
                            }
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                          } finally {
                            setStateDialog(() => _isSubmitting = false);
                          }
                        },
                        child: _isSubmitting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isUpdateMode ? 'Cập nhật' : 'Gửi', style: const TextStyle(color: Colors.white))
                    )
                  ]
              );
            }
        )
    );
  }

  void _showOrderDetails(dynamic order, {bool isReviewMode = false}) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          List<dynamic> details = order['details'] ?? [];
          return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chi tiết đơn hàng #${order['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Expanded(
                        child: details.isEmpty
                            ? const Center(child: Text('Không có thông tin chi tiết sản phẩm'))
                            : ListView.separated(
                            itemCount: details.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (c, i) {
                              var item = details[i];

                              double price = double.tryParse(item['price'].toString()) ?? 0.0;
                              String formattedPrice = price.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

                              bool isReviewed = item['is_reviewed'] == true;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: () async {
                                  try {
                                    var res = await apis.get('/catalog/products/${item['product']}/');
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: res.data, role: 'CUSTOMER')));
                                  } catch(e) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi không thể tải sản phẩm này')));
                                  }
                                },
                                title: Text(item['product_name'] ?? 'Sản phẩm ID: ${item['product']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Số lượng: ${item['quantity']}\nGiá: $formattedPrice đ', style: const TextStyle(height: 1.5)),
                                isThreeLine: true,
                                trailing: isReviewMode
                                    ? (isReviewed
                                    ? OutlinedButton.icon(
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Chỉnh sửa'),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
                                  onPressed: () => _handleEditReview(item['id'], item['product']),
                                )
                                    : ElevatedButton.icon(
                                  icon: const Icon(Icons.rate_review, size: 16),
                                  label: const Text('Đánh giá'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                  onPressed: () => _openReviewDialog(item['id'], item['product']),
                                )
                                )
                                    : const Icon(Icons.chevron_right),
                              );
                            }
                        )
                    )
                  ]
              )
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng của tôi'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => {
                _currentPage = 1,
                _fetchOrders(page: _currentPage)
              }
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        iconSize: 18, // GIẢM SIZE ICON ĐỂ TRÁNH TRÀN KHUNG
                        style: const TextStyle(fontSize: 12, color: Colors.black), // KÍCH THƯỚC CHỮ NHỎ LẠI
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                            isDense: true, // THU GỌN KHOẢNG TRỐNG BÊN TRONG (PADDING)
                            labelText: 'Trạng thái',
                            labelStyle: TextStyle(fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            border: OutlineInputBorder()
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Tất cả', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'PENDING', child: Text('Chờ xử lý', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'READY', child: Text('Sẵn sàng', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'SHIPPING', child: Text('Đang giao hàng', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'COMPLETED', child: Text('Hoàn thành', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'CANCELED', child: Text('Đã hủy', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          _selectedStatus = val!;
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        iconSize: 18,
                        style: const TextStyle(fontSize: 12, color: Colors.black),
                        value: _selectedPaymentStatus,
                        decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Thanh toán',
                            labelStyle: TextStyle(fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            border: OutlineInputBorder()
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Tất cả', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'UNPAID', child: Text('Chưa TT', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'PAID', child: Text('Đã thanh toán', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          _selectedPaymentStatus = val!;
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(_startDate == null ? 'Chọn ngày' : '${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}'),
                      onPressed: _selectDateRange,
                    ),
                    if (_selectedStatus != 'ALL' || _selectedPaymentStatus != 'ALL' || _startDate != null)
                      TextButton(onPressed: _clearFilters, child: const Text('Xóa bộ lọc', style: TextStyle(color: Colors.red))),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              color: Colors.blue,
              onRefresh: () => _fetchOrders(page: _currentPage),
              child: _displayedOrders.isEmpty
                  ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 300,
                    child: Center(child: Text('Không có đơn hàng nào phù hợp.')),
                  )
                ],
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(10),
                itemCount: _displayedOrders.length,
                itemBuilder: (context, index) {
                  final order = _displayedOrders[index];
                  final isUnpaid = order['payment_status'] == 'UNPAID';
                  final isCompleted = order['status'] == 'COMPLETED';

                  double amount = double.tryParse(order['final_amount'].toString()) ?? 0.0;
                  String strAmount = amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

                  return InkWell(
                    onTap: () => _showOrderDetails(order, isReviewMode: false),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Đơn hàng #${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(order['created_at'].toString().substring(0, 10), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            const Divider(),
                            Text('Trạng thái: ${_translateStatus(order['status'])}'),
                            Text('Thanh toán: ${_translatePayment(order['payment_status'])}'),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('$strAmount đ', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                                Row(
                                  children: [
                                    if (isCompleted)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                        onPressed: () => _showOrderDetails(order, isReviewMode: true),
                                        child: const Text('Đánh giá'),
                                      ),
                                    if (isUnpaid && order['status'] != 'CANCELED')
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                          onPressed: () => _payOrder(order['id']),
                                          child: const Text('Thanh toán VNPay', style: TextStyle(color: Colors.white)),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (!_isLoading && (_hasNext || _hasPrevious))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4, offset: const Offset(0, -2))]
              ),
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
    );
  }
}

class VNPayWebScreen extends StatefulWidget {
  final String url;
  const VNPayWebScreen({Key? key, required this.url}) : super(key: key);

  @override
  _VNPayWebScreenState createState() => _VNPayWebScreenState();
}

class _VNPayWebScreenState extends State<VNPayWebScreen> {
  late final WebViewController controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('vnpay_return') && !_isProcessing) {
              setState(() => _isProcessing = true);
              Uri uri = Uri.parse(request.url);
              apis.get('/order/vnpay_return/', queryParameters: uri.queryParameters)
                  .then((response) {
                if (mounted) Navigator.pop(context, true);
              })
                  .catchError((error) {
                if (mounted) Navigator.pop(context, false);
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán VNPay', style: TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (_isProcessing)
            Container(
              color: Colors.white.withOpacity(0.9),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 15),
                    Text('Đang xác nhận thanh toán...', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}