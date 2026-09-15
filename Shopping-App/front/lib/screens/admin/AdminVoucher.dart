import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:front/configs/apis.dart';

// ==========================================
// 1. MÀN HÌNH QUẢN LÝ VOUCHER
// ==========================================
class ManageVoucherScreen extends StatefulWidget {
  const ManageVoucherScreen({Key? key}) : super(key: key);
  @override
  _ManageVoucherScreenState createState() => _ManageVoucherScreenState();
}

class _ManageVoucherScreenState extends State<ManageVoucherScreen> {
  List<dynamic> vouchers = [];
  String _searchQuery = '';
  String? filterType;
  DateTimeRange? filterDateRange;
  bool isLoading = true;

  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;

  @override
  void initState() {
    super.initState();
    _fetchVouchers(page: 1);
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
        _fetchVouchers(page: _currentPage);
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
      filterType = null;
      filterDateRange = null;
      _currentPage = 1;
    });
    _fetchVouchers(page: _currentPage);
  }

  Future<void> _fetchVouchers({int page = 1}) async {
    setState(() {
      isLoading = true;
      _currentPage = page;
    });
    try {
      Map<String, dynamic> params = {'page': page};
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (filterType != null) params['voucher_type'] = filterType;
      if (filterDateRange != null) {
        params['start_date'] = filterDateRange!.start.toIso8601String().split('T')[0];
        params['end_date'] = filterDateRange!.end.toIso8601String().split('T')[0];
      }

      final res = await apis.get(endpoints['voucher'], queryParameters: params);

      setState(() {
        if (res.data is Map && res.data.containsKey('results')) {
          vouchers = res.data['results'] ?? [];
          _hasNext = res.data['next'] != null;
          _hasPrevious = res.data['previous'] != null;
        } else if (res.data is List) {
          vouchers = res.data;
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

  void _showEditSheet(Map<String, dynamic> voucher) {
    final codeCtrl = TextEditingController(text: voucher['code']);
    final discountValCtrl = TextEditingController(text: voucher['discount_value'].toString());
    final maxDiscountCtrl = TextEditingController(text: voucher['max_discount_value'].toString());
    final minOrderCtrl = TextEditingController(text: voucher['min_order_value'].toString());
    final totalUsageCtrl = TextEditingController(text: voucher['total_usage_limit'].toString());
    final userUsageCtrl = TextEditingController(text: voucher['user_usage_limit'].toString());

    String voucherType = voucher['voucher_type'] ?? 'DISCOUNT';
    String discountType = voucher['discount_type'] ?? 'PERCENT';
    bool isActive = voucher['is_active'] ?? true;
    final _formKey = GlobalKey<FormState>();

    // CÁC HÀM VALIDATE
    String? validateRequired(String? val) => val == null || val.trim().isEmpty ? 'Bắt buộc nhập' : null;
    String? validateGreaterThanZero(String? val) {
      if (val == null || val.trim().isEmpty) return 'Bắt buộc nhập';
      if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Phải > 0';
      return null;
    }

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
                  Text('Sửa Voucher ${voucher['code']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  TextFormField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Mã Code'), validator: validateRequired),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: voucherType,
                          decoration: const InputDecoration(labelText: 'Loại Voucher'),
                          items: ['DISCOUNT', 'SHIPPING'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) => setSheetState(() => voucherType = val!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: discountType,
                          decoration: const InputDecoration(labelText: 'Kiểu Giảm'),
                          items: ['PERCENT', 'AMOUNT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) => setSheetState(() => discountType = val!),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: discountValCtrl, decoration: const InputDecoration(labelText: 'Mức giảm'), keyboardType: TextInputType.number,
                          validator: (val) {
                            var check = validateGreaterThanZero(val);
                            if (check != null) return check;
                            if (discountType == 'PERCENT' && double.parse(val!) > 100) return 'Không vượt quá 100%';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: maxDiscountCtrl, decoration: const InputDecoration(labelText: 'Giảm tối đa (VNĐ)'), keyboardType: TextInputType.number, validator: validateGreaterThanZero)),
                    ],
                  ),
                  TextFormField(controller: minOrderCtrl, decoration: const InputDecoration(labelText: 'Đơn tối thiểu (VNĐ)'), keyboardType: TextInputType.number, validator: validateGreaterThanZero),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: totalUsageCtrl, decoration: const InputDecoration(labelText: 'Tổng lượt dùng'), keyboardType: TextInputType.number, validator: validateGreaterThanZero)),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: userUsageCtrl, decoration: const InputDecoration(labelText: 'Lượt/User'), keyboardType: TextInputType.number, validator: validateGreaterThanZero)),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Kích hoạt'),
                    value: isActive,
                    onChanged: (val) => setSheetState(() => isActive = val),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          await apis.patch('/voucher/${voucher['id']}/', data: {
                            'code': codeCtrl.text,
                            'voucher_type': voucherType,
                            'discount_type': discountType,
                            'discount_value': discountValCtrl.text,
                            'max_discount_value': maxDiscountCtrl.text,
                            'min_order_value': minOrderCtrl.text,
                            'total_usage_limit': totalUsageCtrl.text,
                            'user_usage_limit': userUsageCtrl.text,
                            'is_active': isActive,
                          });
                          Navigator.pop(context);
                          _fetchVouchers(page: _currentPage);
                        } catch(e) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi cập nhật. Vui lòng kiểm tra lại thông tin.'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    child: const Text('Lưu'),
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

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: filterDateRange,
    );
    if (picked != null) {
      setState(() => filterDateRange = picked);
      _currentPage = 1;
      _fetchVouchers(page: _currentPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Voucher')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateVoucherScreen()));
          _fetchVouchers(page: 1);
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
                      hintText: 'Tìm mã voucher...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _clearSearch)
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.date_range, color: Colors.blue), onPressed: _selectDateRange),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    hint: const Text('Loại', style: TextStyle(fontSize: 13)),
                    value: filterType,
                    items: ['Tất cả', 'DISCOUNT', 'SHIPPING'].map((e) => DropdownMenuItem(value: e == 'Tất cả' ? null : e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      setState(() {
                        filterType = val;
                        _currentPage = 1;
                      });
                      _fetchVouchers(page: _currentPage);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_searchQuery.isNotEmpty || filterType != null || filterDateRange != null)
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
                : vouchers.isEmpty
                ? const Center(child: Text('Không tìm thấy voucher.'))
                : RefreshIndicator(
              onRefresh: () => _fetchVouchers(page: _currentPage),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: vouchers.length,
                itemBuilder: (context, index) {
                  final v = vouchers[index];
                  return ListTile(
                    title: Text(v['code'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${v['voucher_type']} | Giảm: ${v['discount_value']} | Dùng: ${v['used_count']}/${v['total_usage_limit']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(v['is_active'] ? Icons.check_circle : Icons.cancel, color: v['is_active'] ? Colors.green : Colors.red),
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditSheet(v)),
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
                    onPressed: _hasPrevious ? () => _fetchVouchers(page: _currentPage - 1) : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Trước'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Trang $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: _hasNext ? () => _fetchVouchers(page: _currentPage + 1) : null,
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
// 2. MÀN HÌNH TẠO VOUCHER MỚI
// ==========================================
class CreateVoucherScreen extends StatefulWidget {
  const CreateVoucherScreen({Key? key}) : super(key: key);
  @override
  _CreateVoucherScreenState createState() => _CreateVoucherScreenState();
}

class _CreateVoucherScreenState extends State<CreateVoucherScreen> {
  final _formKey = GlobalKey<FormState>();

  final _codeCtrl = TextEditingController();
  final _discountValueCtrl = TextEditingController();
  final _maxDiscountCtrl = TextEditingController(); // ĐÃ THÊM Ô NÀY ĐỂ FIX LỖI 400
  final _minOrderCtrl = TextEditingController();
  final _totalUsageCtrl = TextEditingController(text: '100');
  final _userUsageCtrl = TextEditingController(text: '1');

  String _voucherType = 'DISCOUNT';
  String _discountType = 'PERCENT';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isActive = true;
  bool _isLoading = false;

  Future<void> _selectDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await apis.post(endpoints['voucher'] ?? '/voucher/', data: {
        'code': _codeCtrl.text,
        'voucher_type': _voucherType,
        'discount_type': _discountType,
        'discount_value': _discountValueCtrl.text,
        'max_discount_value': _maxDiscountCtrl.text, // BẮT BUỘC TRUYỀN LÊN BACKEND
        'min_order_value': _minOrderCtrl.text,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'total_usage_limit': _totalUsageCtrl.text,
        'user_usage_limit': _userUsageCtrl.text,
        'is_active': _isActive,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo Voucher thành công!'), backgroundColor: Colors.green));
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

  String? _validateRequired(String? val) => val == null || val.trim().isEmpty ? 'Bắt buộc' : null;
  String? _validateGreaterThanZero(String? val) {
    if (val == null || val.trim().isEmpty) return 'Bắt buộc';
    if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Phải > 0';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo Voucher mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Mã Voucher (VD: SUMMER26)*'), validator: _validateRequired),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _voucherType,
                      decoration: const InputDecoration(labelText: 'Loại Voucher'),
                      items: ['DISCOUNT', 'SHIPPING'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _voucherType = val!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _discountType,
                      decoration: const InputDecoration(labelText: 'Hình thức giảm'),
                      items: ['PERCENT', 'AMOUNT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _discountType = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: TextFormField(
                        controller: _discountValueCtrl,
                        decoration: const InputDecoration(labelText: 'Giá trị giảm*'),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          var check = _validateGreaterThanZero(val);
                          if (check != null) return check;
                          if (_discountType == 'PERCENT' && double.parse(val!) > 100) return 'Tối đa 100%';
                          return null;
                        },
                      )
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _maxDiscountCtrl, decoration: const InputDecoration(labelText: 'Giảm tối đa (VNĐ)*'), keyboardType: TextInputType.number, validator: _validateGreaterThanZero)),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(controller: _minOrderCtrl, decoration: const InputDecoration(labelText: 'Đơn tối thiểu (VNĐ)*'), keyboardType: TextInputType.number, validator: _validateGreaterThanZero),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: TextFormField(controller: _totalUsageCtrl, decoration: const InputDecoration(labelText: 'Giới hạn hệ thống*'), keyboardType: TextInputType.number, validator: _validateGreaterThanZero)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _userUsageCtrl, decoration: const InputDecoration(labelText: 'Lượt/User*'), keyboardType: TextInputType.number, validator: _validateGreaterThanZero)),
                ],
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Thời gian áp dụng'),
                subtitle: Text('${_startDate.toLocal().toString().split(' ')[0]} - ${_endDate.toLocal().toString().split(' ')[0]}'),
                trailing: ElevatedButton(onPressed: _selectDates, child: const Text('Chọn ngày')),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kích hoạt (is_active)'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  child: const Text('LƯU VOUCHER')
              ),
            ],
          ),
        ),
      ),
    );
  }
}