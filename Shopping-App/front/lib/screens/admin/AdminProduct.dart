import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:front/configs/apis.dart';

// ==========================================
// 1. MÀN HÌNH QUẢN LÝ SẢN PHẨM
// ==========================================
class ManageProductScreen extends StatefulWidget {
  const ManageProductScreen({Key? key}) : super(key: key);
  @override
  _ManageProductScreenState createState() => _ManageProductScreenState();
}

class _ManageProductScreenState extends State<ManageProductScreen> {
  List<dynamic> products = [];
  List<dynamic> _categories = []; // Danh sách Categories
  String _searchQuery = '';
  String? filterCategory;
  bool? filterIsActive;
  String? filterStock;
  bool isLoading = true;

  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts(page: 1);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await apis.get('/catalog/categories/');
      if (mounted) {
        setState(() {
          _categories = res.data is Map ? res.data['results'] ?? [] : res.data;
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải danh mục: $e");
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _currentPage = 1;
        _fetchProducts(page: _currentPage);
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      filterCategory = null;
      filterIsActive = null;
      filterStock = null;
      _currentPage = 1;
    });
    _fetchProducts(page: _currentPage);
  }

  Future<void> _fetchProducts({int page = 1}) async {
    setState(() {
      isLoading = true;
      _currentPage = page;
    });
    try {
      Map<String, dynamic> params = {'page': page};
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (filterCategory != null) params['category'] = filterCategory;
      if (filterIsActive != null) params['is_active'] = filterIsActive;
      if (filterStock != null) params['stock_quantity__gt'] = filterStock == 'In Stock' ? 0 : null;

      final res = await apis.get(endpoints['products'], queryParameters: params);

      setState(() {
        if (res.data is Map && res.data.containsKey('results')) {
          products = res.data['results'] ?? [];
          _hasNext = res.data['next'] != null;
          _hasPrevious = res.data['previous'] != null;
        } else if (res.data is List) {
          products = res.data;
          _hasNext = false;
          _hasPrevious = false;
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showEditSheet(Map<String, dynamic> product) {
    final nameCtrl = TextEditingController(text: product['name']);
    final costPriceCtrl = TextEditingController(text: product['cost_price'].toString());
    final sellPriceCtrl = TextEditingController(text: product['sell_price'].toString());
    final stockCtrl = TextEditingController(text: product['stock_quantity'].toString());
    final weightCtrl = TextEditingController(text: product['weight']?.toString() ?? '0');
    final descCtrl = TextEditingController(text: product['description'] ?? '');
    bool isActive = product['is_active'] ?? true;

    // Lấy đúng ID Category hiện tại của SP
    int? currentCategoryId = product['category'];
    final _formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Sửa ${product['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên sản phẩm*'), validator: (v) => v!.isEmpty ? 'Bắt buộc' : null),
                  TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
                  const SizedBox(height: 10),

                  // DROPDOWN LỰA CHỌN DANH MỤC
                  DropdownButtonFormField<int>(
                    value: currentCategoryId,
                    decoration: const InputDecoration(labelText: 'Danh mục*'),
                    items: _categories.map<DropdownMenuItem<int>>((cat) {
                      return DropdownMenuItem<int>(
                        value: cat['id'],
                        child: Text(cat['name']),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => currentCategoryId = val),
                    validator: (v) => v == null ? 'Vui lòng chọn danh mục' : null,
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: TextFormField(controller: costPriceCtrl, decoration: const InputDecoration(labelText: 'Giá vốn*'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Bắt buộc' : null)),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: sellPriceCtrl, decoration: const InputDecoration(labelText: 'Giá bán*'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Bắt buộc' : null)),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: TextFormField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Tồn kho*'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Bắt buộc' : null)),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: weightCtrl, decoration: const InputDecoration(labelText: 'Trọng lượng (g)'), keyboardType: TextInputType.number)),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Đang bán (is_active)'),
                    value: isActive,
                    onChanged: (val) => setSheetState(() => isActive = val),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          await apis.patch('/catalog/products/${product['id']}/', data: {
                            'name': nameCtrl.text,
                            'description': descCtrl.text,
                            'category': currentCategoryId,
                            'cost_price': costPriceCtrl.text,
                            'sell_price': sellPriceCtrl.text,
                            'stock_quantity': stockCtrl.text,
                            'weight': weightCtrl.text,
                            'is_active': isActive,
                          });
                          Navigator.pop(context);
                          _fetchProducts(page: _currentPage);
                        } catch(e) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi cập nhật. Vui lòng kiểm tra lại thông tin.'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    child: const Text('CẬP NHẬT'),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Sản phẩm')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateProductScreen(categories: _categories)));
          _fetchProducts(page: 1);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm sản phẩm...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _clearSearch)
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<bool?>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    hint: const Text('Trạng thái', style: TextStyle(fontSize: 13)),
                    value: filterIsActive,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tất cả', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: true, child: Text('Active', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: false, child: Text('Inactive', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        filterIsActive = val;
                        _currentPage = 1;
                      });
                      _fetchProducts(page: _currentPage);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_searchQuery.isNotEmpty || filterIsActive != null || filterCategory != null || filterStock != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.filter_alt_off, color: Colors.red, size: 16),
                label: const Text('Xóa bộ lọc', style: TextStyle(color: Colors.red)),
                onPressed: _clearAllFilters,
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                ? const Center(child: Text('Không tìm thấy sản phẩm.'))
                : RefreshIndicator(
              onRefresh: () => _fetchProducts(page: _currentPage),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  return ListTile(
                    title: Text(p['name'],
                      style: const TextStyle(
                        // fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),),
                    subtitle: Text('Giá: ${p['sell_price']} | Tồn: ${p['stock_quantity']} | Trọng lượng: ${p['weight']}g'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(p['is_active'] ? Icons.check_circle : Icons.cancel, color: p['is_active'] ? Colors.green : Colors.red),
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditSheet(p)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (!isLoading && (_hasNext || _hasPrevious))
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
    );
  }
}

// ==========================================
// 2. MÀN HÌNH TẠO SẢN PHẨM MỚI
// ==========================================
class CreateProductScreen extends StatefulWidget {
  final List<dynamic> categories;
  const CreateProductScreen({Key? key, required this.categories}) : super(key: key);
  @override
  _CreateProductScreenState createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  int? _selectedCategoryId;
  bool _isActive = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await apis.post('/products/', data: {
        'name': _nameCtrl.text,
        'description': _descCtrl.text,
        'cost_price': _costPriceCtrl.text,
        'sell_price': _sellPriceCtrl.text,
        'stock_quantity': _stockCtrl.text,
        'weight': _weightCtrl.text.isEmpty ? '0' : _weightCtrl.text,
        'is_active': _isActive,
        'category': _selectedCategoryId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo sản phẩm thành công!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      String errorMessage = 'Lỗi không xác định!';
      if (e is DioException && e.response != null && e.response!.data != null) {
        var errData = e.response!.data;
        if (errData is Map) {
          var firstErrorKey = errData.keys.first;
          var firstErrorVal = errData[firstErrorKey];
          errorMessage = 'Lỗi $firstErrorKey: ${firstErrorVal is List ? firstErrorVal[0] : firstErrorVal}';
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm Sản phẩm mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Tên sản phẩm*'), validator: (v) => v!.isEmpty ? 'Bắt buộc nhập' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Mô tả sản phẩm')),
              const SizedBox(height: 10),

              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Danh mục*'),
                items: widget.categories.map<DropdownMenuItem<int>>((cat) {
                  return DropdownMenuItem<int>(
                    value: cat['id'],
                    child: Text(cat['name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
                validator: (v) => v == null ? 'Vui lòng chọn danh mục' : null,
              ),

              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: TextFormField(controller: _costPriceCtrl, decoration: const InputDecoration(labelText: 'Giá vốn*'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Bắt buộc nhập' : null)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _sellPriceCtrl, decoration: const InputDecoration(labelText: 'Giá bán*'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Bắt buộc nhập' : null)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: TextFormField(controller: _stockCtrl, decoration: const InputDecoration(labelText: 'Số lượng tồn kho*'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Bắt buộc nhập' : null)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _weightCtrl, decoration: const InputDecoration(labelText: 'Trọng lượng (g)'), keyboardType: TextInputType.number)),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kích hoạt (is_active)'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  child: const Text('LƯU SẢN PHẨM')
              ),
            ],
          ),
        ),
      ),
    );
  }
}