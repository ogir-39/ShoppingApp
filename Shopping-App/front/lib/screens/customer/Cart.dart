import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../configs/apis.dart';
import 'Order.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic>? _cart;
  List<dynamic> _items = [];
  bool _isLoading = true;

  double _totalGoodsValue = 0;
  double _shippingFee = 30000;

  List<dynamic> _usableVouchers = [];
  dynamic _selectedDiscountVoucher;
  dynamic _selectedShippingVoucher;

  double _userCoins = 0;
  bool _useCoin = false;

  @override
  void initState() {
    super.initState();
    _fetchCartData();
  }

  Future<void> _fetchCartData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null) apis.options.headers['Authorization'] = 'Bearer $token';

      Response resCart = await apis.get(endpoints['cart']);
      var data = resCart.data;

      if (data is Map && data.containsKey('results')) {
        data = data['results'];
      }

      if (data is List && data.isNotEmpty) {
        _cart = data[0];
        _items = _cart?['items'] ?? [];
      } else {
        _items = [];
      }

      _totalGoodsValue = 0;
      for (var item in _items) {
        _totalGoodsValue += (double.tryParse(item['total_price'].toString()) ?? 0);
      }

      if (_items.isNotEmpty) {
        Response resVoucher = await apis.get('/voucher/usable/');
        _usableVouchers = resVoucher.data['usable_vouchers'] ?? [];
      }

      // LẤY SỐ XU CỦA NGƯỜI DÙNG TỪ API
      Response resProfile = await apis.get('/account/current-user/');
      _userCoins = double.tryParse(resProfile.data['coins']?.toString() ?? '0') ?? 0.0;

      setState(() => _isLoading = false);
    } catch (e) {
      print("Lỗi tải giỏ hàng: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateQuantity(int itemId, int currentQty, int delta) async {
    int newQty = currentQty + delta;

    if (newQty <= 0) {
      bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc chắn muốn bỏ sản phẩm này khỏi giỏ hàng?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmDelete != true) return;
      await apis.delete('/cart/items/$itemId/');

    } else {
      await apis.patch('/cart/items/$itemId/', data: {'quantity': newQty});
    }

    _fetchCartData();
  }

  String _formatCurrency(double amount) {
    String prefix = amount < 0 ? '-' : '';
    String formatted = amount.abs().round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$prefix$formatted\u0111';
  }

  void _showVoucherDialog() {
    dynamic tempShipping = _selectedShippingVoucher;
    dynamic tempDiscount = _selectedDiscountVoucher;

    List<dynamic> shippingVouchers = _usableVouchers.where((v) => v['voucher_type'] == 'SHIPPING').toList();
    List<dynamic> discountVouchers = _usableVouchers.where((v) => v['voucher_type'] != 'SHIPPING').toList();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.grey.shade50,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {

              Widget buildVoucherItem(dynamic v, bool isShipping) {
                bool isSelected = (isShipping && tempShipping != null && tempShipping['id'] == v['id']) ||
                    (!isShipping && tempDiscount != null && tempDiscount['id'] == v['id']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))]
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    activeColor: Colors.deepOrange,
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    onChanged: (bool? checked) {
                      setModalState(() {
                        if (checked == true) {
                          if (isShipping) tempShipping = v;
                          else tempDiscount = v;
                        } else {
                          if (isShipping) tempShipping = null;
                          else tempDiscount = null;
                        }
                      });
                    },
                    title: Text(v['code'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${isShipping ? 'Miễn phí vận chuyển' : 'Giảm giá'} - Giảm ${_formatCurrency(double.tryParse(v['discount_value'].toString()) ?? 0)}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                    secondary: Icon(
                        isShipping ? Icons.local_shipping : Icons.local_offer,
                        color: isShipping ? Colors.teal : Colors.orange,
                        size: 32
                    ),
                  ),
                );
              }

              return Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chọn Shopee Voucher', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Có thể chọn tối đa 1 mã Giảm giá và 1 mã Vận chuyển.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const Divider(height: 25),
                    Expanded(
                      child: _usableVouchers.isEmpty
                          ? const Center(child: Text('Không có mã nào phù hợp cho giỏ hàng này'))
                          : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (shippingVouchers.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10, top: 5),
                                child: Text('GIẢM PHÍ VẬN CHUYỂN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                              ),
                              ...shippingVouchers.map((v) => buildVoucherItem(v, true)).toList(),
                            ],
                            if (discountVouchers.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10, top: 15),
                                child: Text('GIẢM GIÁ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                              ),
                              ...discountVouchers.map((v) => buildVoucherItem(v, false)).toList(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedShippingVoucher = tempShipping;
                            _selectedDiscountVoucher = tempDiscount;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Xác nhận', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              );
            }
        )
    );
  }

  double _getShippingDiscountAmount() {
    if (_selectedShippingVoucher == null) return 0;
    double discount = double.tryParse(_selectedShippingVoucher['discount_value'].toString()) ?? 0;
    return discount > _shippingFee ? _shippingFee : discount;
  }

  double _getGoodsDiscountAmount() {
    if (_selectedDiscountVoucher == null) return 0;
    double discount = 0;
    if (_selectedDiscountVoucher['discount_type'] == 'PERCENT') {
      discount = _totalGoodsValue * (double.tryParse(_selectedDiscountVoucher['discount_value'].toString()) ?? 0) / 100;
    } else {
      discount = double.tryParse(_selectedDiscountVoucher['discount_value'].toString()) ?? 0;
    }
    double maxD = double.tryParse(_selectedDiscountVoucher['max_discount_value'].toString()) ?? 0;
    if (maxD > 0 && discount > maxD) discount = maxD;
    return discount;
  }

  void _showCheckoutOptions() {
    if (_items.isEmpty) return;

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận đặt hàng'),
          content: const Text('Bạn muốn thanh toán đơn hàng này bằng hình thức nào?'),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _checkout(payNow: false);
                },
                child: const Text('Thanh toán sau (COD)', style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                onPressed: () {
                  Navigator.pop(ctx);
                  _checkout(payNow: true);
                },
                child: const Text('Thanh toán VNPay', style: TextStyle(color: Colors.white))
            ),
          ],
        )
    );
  }

  Future<void> _checkout({required bool payNow}) async {
    setState(() => _isLoading = true);
    try {
      Response res = await apis.post(endpoints['checkout'], data: {
        'shipping_address': 'Địa chỉ test lấy từ Profile',
        'discount_voucher_code': _selectedDiscountVoucher != null ? _selectedDiscountVoucher['code'] : '',
        'shipping_voucher_code': _selectedShippingVoucher != null ? _selectedShippingVoucher['code'] : '',
        'coin_used': _useCoin ? _userCoins : 0,
      });

      if (payNow) {
        // Sang OrderScreen để nó tiếp quản việc thanh toán VNPay
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đặt hàng thành công!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }

      setState(() {
        _items = [];
        _selectedDiscountVoucher = null;
        _selectedShippingVoucher = null;
      });

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OrderScreen()));

    } catch (e) {
      String errorMessage = 'Có lỗi xảy ra khi đặt hàng!';

      if (e is DioException && e.response != null) {
        final responseData = e.response!.data;
        if (responseData is Map && responseData.containsKey('detail')) {
          errorMessage = responseData['detail'];
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(color: Colors.white, fontSize: 14)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
          )
      );

      setState(() {
        _selectedDiscountVoucher = null;
        _selectedShippingVoucher = null;
        _isLoading = false;
      });
    }
  }

  Widget _buildSummaryRow(String label, double amount, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 15,
              color: isRed ? Colors.deepOrange : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    double shippingDiscount = _getShippingDiscountAmount();
    double goodsDiscount = _getGoodsDiscountAmount();
    double totalVoucherDiscount = shippingDiscount + goodsDiscount;
    double coinDiscount = _useCoin ? _userCoins : 0;

    double finalAmount = _totalGoodsValue + _shippingFee - totalVoucherDiscount - coinDiscount;
    if (finalAmount < 0) finalAmount = 0;

    List<String> selectedCodes = [];
    if (_selectedShippingVoucher != null) selectedCodes.add(_selectedShippingVoucher['code']);
    if (_selectedDiscountVoucher != null) selectedCodes.add(_selectedDiscountVoucher['code']);
    String voucherLabel = selectedCodes.isEmpty ? 'Chọn hoặc nhập mã' : selectedCodes.join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Giỏ hàng')),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('Giỏ hàng của bạn đang trống', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, index) {
                var item = _items[index];
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag, size: 40, color: Colors.blueAccent),
                    // HIỂN THỊ TÊN SẢN PHẨM Ở ĐÂY
                    title: Text(item['product_name'] ?? 'Sản phẩm ID: ${item['product']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis,),
                    subtitle: Text('Đơn giá: ${_formatCurrency(double.tryParse(item['sell_price'].toString()) ?? 0)}', style: const TextStyle(color: Colors.redAccent)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _updateQuantity(item['id'], item['quantity'], -1)),
                        Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _updateQuantity(item['id'], item['quantity'], 1)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _showVoucherDialog,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(children: [Icon(Icons.local_offer, color: Colors.orange, size: 20), SizedBox(width: 8), Text('Shopee Voucher', style: TextStyle(fontSize: 15))]),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                  child: Text(
                                    voucherLabel,
                                    style: const TextStyle(color: Colors.blueAccent, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  )
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey)
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                if (_userCoins > 0)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Row(children: [Icon(Icons.monetization_on, color: Colors.amber, size: 20), SizedBox(width: 8), Text('Dùng Shopee Xu', style: TextStyle(fontSize: 15))]),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(left: 28.0),
                      child: Text('Dùng $_userCoins xu', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ),
                    value: _useCoin,
                    onChanged: (val) => setState(() => _useCoin = val),
                    activeColor: Colors.green,
                  ),

                const Divider(height: 24, thickness: 1, color: Colors.black12),

                _buildSummaryRow('Tổng tiền hàng', _totalGoodsValue),
                _buildSummaryRow('Tổng tiền phí vận chuyển', _shippingFee),

                if (totalVoucherDiscount > 0)
                  _buildSummaryRow('Tổng cộng Voucher giảm giá', -totalVoucherDiscount, isRed: true),

                if (_useCoin && coinDiscount > 0)
                  _buildSummaryRow('Đã dùng xu', -coinDiscount, isRed: true),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng thanh toán', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text(
                      _formatCurrency(finalAmount),
                      style: const TextStyle(fontSize: 26, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: _items.isEmpty ? null : _showCheckoutOptions,
                    child: const Text('Đặt hàng', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}