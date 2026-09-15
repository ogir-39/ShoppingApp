import 'dart:async';
import 'package:flutter/material.dart';
import 'package:front/configs/apis.dart';

// ==========================================
// 1. MÀN HÌNH QUẢN LÝ DANH MỤC
// ==========================================
class ManageCategoryScreen extends StatefulWidget {
  const ManageCategoryScreen({Key? key}) : super(key: key);
  @override
  _ManageCategoryScreenState createState() => _ManageCategoryScreenState();
}

class _ManageCategoryScreenState extends State<ManageCategoryScreen> {
  List<dynamic> categories = [];
  String _searchQuery = '';
  bool isLoading = true;

  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories(page: 1);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _currentPage = 1;
        _fetchCategories(page: _currentPage);
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
      _currentPage = 1;
    });
    _fetchCategories(page: _currentPage);
  }

  Future<void> _fetchCategories({int page = 1}) async {
    setState(() {
      isLoading = true;
      _currentPage = page;
    });
    try {
      Map<String, dynamic> params = {'page': page};
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;

      final res = await apis.get(endpoints['categories'], queryParameters: params);

      setState(() {
        List<dynamic> data = [];
        if (res.data is Map && res.data.containsKey('results')) {
          data = res.data['results'] ?? [];
          _hasNext = res.data['next'] != null;
          _hasPrevious = res.data['previous'] != null;
        } else if (res.data is List) {
          data = res.data;
          _hasNext = false;
          _hasPrevious = false;
        }

        categories = data;
      });
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showEditDialog(Map<String, dynamic> category) {
    final nameCtrl = TextEditingController(text: category['name']);
    final descCtrl = TextEditingController(text: category['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa Danh mục'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên danh mục')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              await apis.patch('/catalog/categories/${category['id']}/', data: {
                'name': nameCtrl.text, 'description': descCtrl.text
              });
              Navigator.pop(context);
              _fetchCategories(page: _currentPage);
            },
            child: const Text('Lưu'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Danh mục')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCategoryScreen()));
          _fetchCategories(page: 1);
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
                      hintText: 'Tìm danh mục...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _clearSearch)
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_searchQuery.isNotEmpty)
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
                : categories.isEmpty
                ? const Center(child: Text('Không tìm thấy danh mục.'))
                : RefreshIndicator(
              onRefresh: () => _fetchCategories(page: _currentPage),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final c = categories[index];
                  return ListTile(
                    title: Text(c['name']),
                    subtitle: Text(c['description'] ?? ''),
                    trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditDialog(c)),
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
                    onPressed: _hasPrevious ? () => _fetchCategories(page: _currentPage - 1) : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Trước'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Trang $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: _hasNext ? () => _fetchCategories(page: _currentPage + 1) : null,
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
// 2. MÀN HÌNH TẠO DANH MỤC (GIỮ NGUYÊN)
// ==========================================
class CreateCategoryScreen extends StatefulWidget {
  const CreateCategoryScreen({Key? key}) : super(key: key);
  @override
  _CreateCategoryScreenState createState() => _CreateCategoryScreenState();
}

class _CreateCategoryScreenState extends State<CreateCategoryScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await apis.post(endpoints['categories'], data: {
        'name': _nameCtrl.text,
        'description': _descCtrl.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo danh mục thành công!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi tạo danh mục'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm Danh mục mới')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Tên danh mục')),
            const SizedBox(height: 10),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _submit, child: const Text('LƯU DANH MỤC')),
          ],
        ),
      ),
    );
  }
}