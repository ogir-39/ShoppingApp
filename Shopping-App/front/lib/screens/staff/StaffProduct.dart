import 'package:flutter/material.dart';
import 'package:front/configs/apis.dart';

class StaffProductScreen extends StatefulWidget {
  const StaffProductScreen({Key? key}) : super(key: key);

  @override
  _StaffProductScreenState createState() => _StaffProductScreenState();
}

class _StaffProductScreenState extends State<StaffProductScreen> {
  List<dynamic> products = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String searchQuery = '';
  String? filterCategory;
  bool? filterIsActive;
  bool filterLowStock = false;

  bool isLoading = true;
  int _currentPage = 1;
  bool _hasNext = false;
  bool _hasPrevious = false; // Thêm cờ cho trang trước

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
    _fetchProducts(page: 1);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts({int page = 1}) async {
    setState(() => isLoading = true);

    try {
      Map<String, dynamic> params = {'page': page};
      if (searchQuery.isNotEmpty) params['search'] = searchQuery;
      if (filterCategory != null) params['category'] = filterCategory;
      if (filterIsActive != null) params['is_active'] = filterIsActive;
      if (filterLowStock) params['stock_lt'] = 5;

      final res = await apis.get(endpoints['products'], queryParameters: params);

      if (mounted) {
        setState(() {
          _currentPage = page;
          if (res.data is Map && res.data.containsKey('results')) {
            _hasNext = res.data['next'] != null;
            _hasPrevious = res.data['previous'] != null; // Cập nhật cờ previous
            products = res.data['results']; // Luôn ghi đè thay vì addAll
          } else {
            products = res.data;
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

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      searchQuery = '';
      filterCategory = null;
      filterIsActive = null;
      filterLowStock = false;
    });
    _fetchProducts(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho Sản phẩm (Staff)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetFilters,
          )
        ],
      ),
      body: Column(
        children: [
          // THANH TÌM KIẾM & LỌC
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm tên sản phẩm...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => searchQuery = '');
                        _fetchProducts(page: 1);
                      },
                    )
                        : null,
                  ),
                  onChanged: (val) => setState(() => searchQuery = val),
                  onSubmitted: (_) => _fetchProducts(page: 1),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<bool?>(
                        isExpanded: true,
                        hint: const Text('Trạng thái bán'),
                        value: filterIsActive,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tất cả')),
                          DropdownMenuItem(value: true, child: Text('Đang bán')),
                          DropdownMenuItem(value: false, child: Text('Tạm ngưng')),
                        ],
                        onChanged: (val) {
                          setState(() => filterIsActive = val);
                          _fetchProducts(page: 1);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: filterLowStock,
                          onChanged: (val) {
                            setState(() => filterLowStock = val!);
                            _fetchProducts(page: 1);
                          },
                        ),
                        const Text('Tồn < 5', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // DANH SÁCH SẢN PHẨM
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: () => _fetchProducts(page: _currentPage),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      final int stock = p['stock_quantity'] ?? 0;

                      return Card(
                        child: ListTile(
                          title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Giá gốc: ${_formatCurrency(p['cost_price'])} đ'),
                              Text('Giá bán: ${_formatCurrency(p['sell_price'])} đ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                              Text('Trạng thái: ${p['is_active'] ? "Đang bán" : "Ngừng bán"}'),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Tồn kho', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                  stock.toString(),
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: stock < 5 ? Colors.red : Colors.green
                                  )
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // ĐIỀU HƯỚNG PHÂN TRANG (Tương tự HomeScreen)
                  if (products.isNotEmpty || _hasPrevious)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _hasPrevious ? () => _fetchProducts(page: _currentPage - 1) : null,
                            icon: const Icon(Icons.chevron_left, size: 18),
                            label: const Text('Trước'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text('Trang $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          ElevatedButton(
                            onPressed: _hasNext ? () => _fetchProducts(page: _currentPage + 1) : null,
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