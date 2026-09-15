import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../customer/Cart.dart';
import '/navigations/RootNavigator.dart';
import '/configs/apis.dart';

class ProductDetailScreen extends StatefulWidget {
  final dynamic product;
  final String role;

  const ProductDetailScreen({Key? key, required this.product, required this.role}) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  List<dynamic> _allReviews = [];
  List<dynamic> _displayedReviews = [];

  bool _isLoadingReviews = true;
  double _averageRating = 0.0;
  int _selectedRatingFilter = 0;

  bool _isDescriptionExpanded = true;

  // THÊM: Biến trạng thái lưu vị trí ảnh đang hiển thị
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      Response res = await apis.get(
          '/review/',
          queryParameters: {'product': widget.product['id']}
      );

      List<dynamic> fetchedReviews = [];
      if (res.data is Map<String, dynamic> && res.data.containsKey('results')) {
        fetchedReviews = res.data['results'];
      } else if (res.data is List) {
        fetchedReviews = res.data;
      }

      double totalStars = 0;
      for (var r in fetchedReviews) {
        totalStars += (r['rating'] ?? 0);
      }

      setState(() {
        _allReviews = fetchedReviews;
        if (_allReviews.isNotEmpty) {
          _averageRating = totalStars / _allReviews.length;
        }
        _isLoadingReviews = false;
        _applyRatingFilter();
      });
    } catch (e) {
      print("======== LỖI TẢI REVIEW ========");
      print(e.toString());
      setState(() => _isLoadingReviews = false);
    }
  }

  void _applyRatingFilter() {
    setState(() {
      if (_selectedRatingFilter == 0) {
        _displayedReviews = List.from(_allReviews);
      } else {
        _displayedReviews = _allReviews.where((r) => (r['rating'] ?? 0) == _selectedRatingFilter).toList();
      }
    });
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
                // Xử lý điều hướng sang đăng nhập tùy thuộc vào file đang đứng
                // Nếu ở Home.dart: widget.onNavigateToLogin!();
                // Nếu ở ProductDetail.dart: Navigator.of(context, rootNavigator: true).pushReplacement(...)
              },
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      );
    } else {
      // --- LOGIC GỌI API THÊM GIỎ HÀNG THỰC TẾ ---
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          apis.options.headers['Authorization'] = 'Bearer $token';
        }

        // Gọi POST đến API /cartitem/ và truyền ID của sản phẩm
        FormData formData = FormData.fromMap({
          'product': product['id'].toString(), // Ép kiểu chuỗi để FormData hiểu
        });

        await apis.post(endpoints['cart-item'], data: formData);

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã thêm sản phẩm vào giỏ hàng!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            )
        );
      } catch (e) {
        print("Lỗi thêm giỏ hàng: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Có lỗi xảy ra, vui lòng thử lại!'),
              backgroundColor: Colors.red,
            )
        );
      }
    }
  }

  Widget _buildStarRating(double rating, {double size = 18}) {
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) return Icon(Icons.star, color: Colors.amber, size: size);
        if (index == fullStars && hasHalfStar) return Icon(Icons.star_half, color: Colors.amber, size: size);
        return Icon(Icons.star_border, color: Colors.amber, size: size);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // THÊM: Xử lý danh sách TẤT CẢ url hình ảnh hợp lệ
    List<String> validImageUrls = [];
    if (widget.product['prod_images'] != null && widget.product['prod_images'].isNotEmpty) {
      for (var imgObj in widget.product['prod_images']) {
        String rawUrl = imgObj['image'];
        if (rawUrl.startsWith('/')) {
          validImageUrls.add(SERVER_URL + rawUrl);
        } else if (rawUrl.contains('127.0.0.1') || rawUrl.contains('localhost')) {
          validImageUrls.add(SERVER_URL + Uri.parse(rawUrl).path);
        } else {
          validImageUrls.add(rawUrl);
        }
      }
    }

    String formatCurrency(dynamic price) {
      if (price == null) return '0';
      double parsedPrice = double.tryParse(price.toString()) ?? 0.0;
      String strPrice = parsedPrice.round().toString();
      return strPrice.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
    }

    String description = widget.product['description'] ?? 'Chưa có thông tin mô tả chi tiết cho sản phẩm này.';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Chi tiết sản phẩm', style: TextStyle(fontSize: 16)),
        actions: [
          // SỬA LẠI NÚT GIỎ HÀNG Ở ĐÂY
          IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
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
                            // Đẩy người dùng về màn hình GUEST (chứa tab Đăng nhập)
                            Navigator.of(context, rootNavigator: true).pushReplacement(
                                MaterialPageRoute(builder: (_) => const RootNavigator(role: 'GUEST'))
                            );
                          },
                          child: const Text('Đăng nhập'),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Đã đăng nhập -> Mở màn hình Giỏ hàng
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                }
              }
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: () async {
          setState(() {
            _isLoadingReviews = true;
          });
          await _fetchReviews();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Khung hiển thị bộ sưu tập ảnh sản phẩm
              Container(
                width: double.infinity,
                height: 350,
                color: Colors.white,
                child: validImageUrls.isNotEmpty
                    ? Stack(
                  children: [
                    PageView.builder(
                      itemCount: validImageUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                            validImageUrls[index],
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 100, color: Colors.grey)
                        );
                      },
                    ),
                    // Nút hiển thị số trang (VD: 1/3) đè lên góc phải
                    if (validImageUrls.length > 1)
                      Positioned(
                        bottom: 15,
                        right: 15,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1}/${validImageUrls.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                )
                    : const Center(child: Icon(Icons.image, size: 100, color: Colors.grey)),
              ),

              // 2. Thông tin cơ bản
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product['name'] ?? 'Không tên',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${formatCurrency(widget.product['sell_price'])} đ',
                      style: const TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 3. Thông tin mô tả (DẠNG COLLAPSED)
              Container(
                color: Colors.white,
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isDescriptionExpanded = !_isDescriptionExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Mô tả sản phẩm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Icon(
                              _isDescriptionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_isDescriptionExpanded) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Divider(height: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          description,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ]
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 4. Đánh giá & Bình luận (Có Bộ Lọc)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Đánh giá (${_allReviews.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (_allReviews.isNotEmpty)
                          Row(
                            children: [
                              _buildStarRating(_averageRating),
                              const SizedBox(width: 5),
                              Text('${_averageRating.toStringAsFixed(1)}/5', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          )
                      ],
                    ),
                    const Divider(),

                    if (_allReviews.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [0, 5, 4, 3, 2, 1].map((rating) {
                            bool isSelected = _selectedRatingFilter == rating;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(rating == 0 ? 'Tất cả' : '$rating Sao'),
                                selected: isSelected,
                                selectedColor: Colors.orange.shade100,
                                labelStyle: TextStyle(
                                    color: isSelected ? Colors.orange.shade900 : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                ),
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedRatingFilter = rating;
                                    _applyRatingFilter();
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 15),

                    if (_isLoadingReviews)
                      const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                    else if (_allReviews.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Text('Sản phẩm chưa có đánh giá nào.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                      )
                    else if (_displayedReviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: Text('Không có đánh giá nào phù hợp với bộ lọc.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        )
                      else
                        ..._displayedReviews.map((review) {
                          String dateStr = review['created_at'] ?? '';
                          if (dateStr.length > 10) dateStr = dateStr.substring(0, 10);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(child: Icon(Icons.person, size: 20), radius: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${review['username'] ?? 'Ẩn danh'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      _buildStarRating((review['rating'] ?? 0).toDouble(), size: 14),
                                      const SizedBox(height: 4),
                                      Text(review['comment'] ?? '', style: const TextStyle(color: Colors.black87)),
                                      const SizedBox(height: 4),
                                      Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -2))]
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
            label: const Text('THÊM VÀO GIỎ HÀNG', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () => _handleAddToCart(context, widget.product)
          ),
        ),
      ),
    );
  }
}