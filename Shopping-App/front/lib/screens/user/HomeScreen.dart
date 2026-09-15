import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:front/screens/customer/Cart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../configs/apis.dart';
import '../../navigations/RootNavigator.dart';
import '../customer/ChatScreen.dart';
import 'ProductDetail.dart';

class HomeScreen extends StatefulWidget {
  final String role;
  final VoidCallback? onNavigateToLogin;

  const HomeScreen({Key? key, required this.role, this.onNavigateToLogin}) : super(key: key);
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _productsFuture;
  int _currentPage = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;

  String _searchQuery = '';
  int? _selectedCategoryId; // Lọc theo danh mục
  List<dynamic> _categories = []; // Lưu danh sách danh mục
  Timer? _debounce;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _productsFuture = _fetchProducts(_currentPage, _searchQuery, _selectedCategoryId);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // TẢI DANH SÁCH DANH MỤC TỪ BACKEND
  Future<void> _fetchCategories() async {
    try {
      Response res = await apis.get('/catalog/categories/'); // Đảm bảo URL này đúng với router backend
      if (res.data is Map && res.data.containsKey('results')) {
        setState(() => _categories = res.data['results']);
      } else {
        setState(() => _categories = res.data);
      }
    } catch (e) {
      print("Lỗi tải Category: $e");
    }
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

  Future<List<dynamic>> _fetchProducts(int page, String search, int? categoryId) async {
    Map<String, dynamic> params = {'page': page};
    if (search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category'] = categoryId;

    Response res = await apis.get(endpoints['products'], queryParameters: params);

    if (res.data is Map<String, dynamic> && res.data.containsKey('results')) {
      _hasNext = res.data['next'] != null;
      _hasPrevious = res.data['previous'] != null;
      return res.data['results'];
    }
    return res.data;
  }

  void _loadPage(int page) {
    setState(() {
      _currentPage = page;
      _productsFuture = _fetchProducts(_currentPage, _searchQuery, _selectedCategoryId);
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _currentPage = 1;
        _productsFuture = _fetchProducts(_currentPage, _searchQuery, _selectedCategoryId);
      });
    });
  }

  void _onCategoryChanged(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _currentPage = 1;
      _productsFuture = _fetchProducts(_currentPage, _searchQuery, _selectedCategoryId);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  Future<void> _handleAddToCart(BuildContext context, dynamic product) async {
    if (widget.role == 'GUEST') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Yêu cầu đăng nhập'),
          content: const Text('Bạn cần đăng nhập để thêm sản phẩm vào giỏ hàng.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onNavigateToLogin!();
              },
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      );
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) apis.options.headers['Authorization'] = 'Bearer $token';

        FormData formData = FormData.fromMap({'product': product['id'].toString()});
        await apis.post(endpoints['cart-item'], data: formData);

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã thêm sản phẩm vào giỏ hàng!'), backgroundColor: Colors.green, duration: Duration(seconds: 2))
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Có lỗi xảy ra, vui lòng thử lại!'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Khoảng cách nhỏ để bóp AppBar lại cho vừa các thành phần
        titleSpacing: 0,
        // NÚT DANH MỤC
        leading: PopupMenuButton<int?>(
          icon: const Icon(Icons.menu),
          tooltip: 'Danh mục',
          onSelected: _onCategoryChanged,
          itemBuilder: (context) {
            List<PopupMenuEntry<int?>> items = [
              const PopupMenuItem(value: null, child: Text('Tất cả sản phẩm', style: TextStyle(fontWeight: FontWeight.bold))),
            ];
            for (var cat in _categories) {
              items.add(PopupMenuItem(
                value: cat['id'],
                child: Text(cat['name'], style: TextStyle(color: _selectedCategoryId == cat['id'] ? Colors.blue : Colors.black)),
              ));
            }
            return items;
          },
        ),
        // THANH TÌM KIẾM
        title: Container(
          height: 38,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm...',
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              border: InputBorder.none,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _clearSearch)
                  : null,
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          // NÚT GIỎ HÀNG
          IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                if (widget.role == 'GUEST') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Yêu cầu đăng nhập'),
                      content: const Text('Bạn cần đăng nhập để xem giỏ hàng.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (widget.onNavigateToLogin != null) widget.onNavigateToLogin!();
                          },
                          child: const Text('Đăng nhập'),
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                }
              }
          ),
          // NÚT HOME (RESET LẠI TRANG CHỦ)
          IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                _clearSearch();
                _onCategoryChanged(null);
              }
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: _logout),
        ],
      ),
      floatingActionButton: widget.role == 'CUSTOMER'
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      )
          : null,
      body: FutureBuilder<List<dynamic>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Không tìm thấy sản phẩm nào.'));

          final products = snapshot.data!;

          return RefreshIndicator(
            color: Colors.blue,
            onRefresh: () async {
              _loadPage(_currentPage);
              await _productsFuture;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_selectedCategoryId != null)
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      color: Colors.blue.shade50,
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                          const SizedBox(width: 5),
                          Text('Đang lọc theo danh mục', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          InkWell(
                            onTap: () => _onCategoryChanged(null),
                            child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          )
                        ],
                      )
                  ),
                GridView.builder(
                  padding: const EdgeInsets.all(10),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    String? imageUrl;
                    if (product['prod_images'] != null && product['prod_images'].isNotEmpty) {
                      var thumbnailData = product['prod_images'].firstWhere(
                              (img) => img['is_thumbnail'] == true,
                          orElse: () => product['prod_images'][0]
                      );
                      String rawUrl = thumbnailData['image'];

                      if (rawUrl.startsWith('/')) {
                        imageUrl = SERVER_URL + rawUrl;
                      } else if (rawUrl.contains('127.0.0.1') || rawUrl.contains('localhost')) {
                        imageUrl = SERVER_URL + Uri.parse(rawUrl).path;
                      } else {
                        imageUrl = rawUrl;
                      }
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                                ProductDetailScreen(product: product, role: widget.role)));
                      },
                      child: Card(
                        elevation: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                color: Colors.grey[200],
                                width: double.infinity,
                                child: imageUrl != null
                                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 50, color: Colors.grey))
                                    : const Icon(Icons.image, size: 50, color: Colors.grey),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'] ?? 'Không tên',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Text('${product['sell_price']} đ', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () => _handleAddToCart(context,product),
                                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                                      child: const Text('Thêm giỏ', style: TextStyle(fontSize: 12)),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _hasPrevious ? () => _loadPage(_currentPage - 1) : null,
                        icon: const Icon(Icons.chevron_left, size: 18),
                        label: const Text('Trước'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('Trang $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      ElevatedButton(
                        onPressed: _hasNext ? () => _loadPage(_currentPage + 1) : null,
                        child: Row(children: const [Text('Sau'), SizedBox(width: 4), Icon(Icons.chevron_right, size: 18)]),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}