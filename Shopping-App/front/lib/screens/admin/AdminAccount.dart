import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:front/configs/apis.dart';

// ==========================================
// 1. MÀN HÌNH QUẢN LÝ TÀI KHOẢN (STAFF/CUSTOMER)
// ==========================================
class ManageAccountScreen extends StatefulWidget {
  const ManageAccountScreen({Key? key}) : super(key: key);
  @override
  _ManageAccountScreenState createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  List<dynamic> users = [];
  String _searchQuery = '';
  String? filterRole;
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
    _fetchUsers(page: 1);
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
        _fetchUsers(page: _currentPage);
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
      filterRole = null;
      filterDateRange = null;
      _currentPage = 1;
    });
    _fetchUsers(page: _currentPage);
  }

  Future<void> _fetchUsers({int page = 1}) async {
    setState(() {
      isLoading = true;
      _currentPage = page;
    });
    try {
      Map<String, dynamic> params = {'page': page};
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (filterRole != null) params['role'] = filterRole;
      if (filterDateRange != null) {
        params['start_date'] = filterDateRange!.start.toIso8601String().split('T')[0];
        params['end_date'] = filterDateRange!.end.toIso8601String().split('T')[0];
      }

      final res = await apis.get(endpoints['account'], queryParameters: params);

      setState(() {
        if (res.data is Map && res.data.containsKey('results')) {
          users = res.data['results'] ?? [];
          _hasNext = res.data['next'] != null;
          _hasPrevious = res.data['previous'] != null;
        } else if (res.data is List) {
          users = res.data;
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

  void _showEditDialog(Map<String, dynamic> user) {
    final roleCtrl = TextEditingController(text: user['role']);
    final passwordCtrl = TextEditingController();
    bool isActive = user['is_active'] ?? true;
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Sửa ${user['username'] ?? user['email']}'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: roleCtrl.text,
                  items: ['ADMIN', 'STAFF', 'CUSTOMER'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setDialogState(() => roleCtrl.text = val!),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Mật khẩu mới (Bỏ trống nếu giữ nguyên)'),
                  obscureText: true,
                ),
                SwitchListTile(
                  title: const Text('Đang hoạt động (is_active)'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  Map<String, dynamic> data = {'role': roleCtrl.text, 'is_active': isActive};
                  if (passwordCtrl.text.isNotEmpty) data['password'] = passwordCtrl.text;

                  await apis.patch('/account/${user['id']}/', data: data);
                  Navigator.pop(context);
                  _fetchUsers(page: _currentPage);
                }
              },
              child: const Text('Lưu'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Tài khoản')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAccountScreen()));
          _fetchUsers(page: 1);
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
                      hintText: 'Tìm kiếm...',
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
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    hint: const Text('Role', style: TextStyle(fontSize: 14)),
                    value: filterRole,
                    items: ['Tất cả', 'ADMIN', 'STAFF', 'CUSTOMER'].map((e) => DropdownMenuItem(value: e == 'Tất cả' ? null : e, child: Text(e, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      setState(() {
                        filterRole = val;
                        _currentPage = 1;
                      });
                      _fetchUsers(page: _currentPage);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_searchQuery.isNotEmpty || filterRole != null || filterDateRange != null)
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
                : users.isEmpty
                ? const Center(child: Text('Không tìm thấy tài khoản.'))
                : RefreshIndicator(
              onRefresh: () => _fetchUsers(page: _currentPage),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final u = users[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text(u['role'][0])),
                    title: Text(u['username'] ?? u['email'] ?? 'No Name'),
                    subtitle: Text('Role: ${u['role']} | Trạng thái: ${u['is_active'] == true ? "Hoạt động" : "Khóa"}'),
                    trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditDialog(u)),
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
                    onPressed: _hasPrevious ? () => _fetchUsers(page: _currentPage - 1) : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Trước'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Trang $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: _hasNext ? () => _fetchUsers(page: _currentPage + 1) : null,
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
// 2. MÀN HÌNH TẠO TÀI KHOẢN MỚI
// ==========================================
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({Key? key}) : super(key: key);
  @override
  _CreateAccountScreenState createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>(); // CHÌA KHÓA QUẢN LÝ FORM

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _role = 'CUSTOMER';
  bool _isLoading = false;

  Future<void> _submit() async {
    // KÍCH HOẠT VALIDATE, nếu có lỗi (trả về False) thì dừng lại ngay
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await apis.post(endpoints['account'] ?? '/account/', data: {
        'username': _usernameCtrl.text,
        'password': _passwordCtrl.text,
        'email': _emailCtrl.text,
        'phone': _phoneCtrl.text,
        'address': _addressCtrl.text,
        'role': _role,
        'first_name': '',
        'last_name': '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo tài khoản thành công!'), backgroundColor: Colors.green));
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
      appBar: AppBar(title: const Text('Tạo Tài khoản mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form( // BỌC TẤT CẢ TRONG FORM
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Tên đăng nhập (Username)*'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập Username' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Mật khẩu*'),
                obscureText: true,
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập Mật khẩu' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email*'),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập Email';
                  if (!val.contains('@')) return 'Email không đúng định dạng';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Số điện thoại*'),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập Số điện thoại';
                  // KIỂM TRA CHỈ CHO PHÉP NHẬP SỐ
                  if (!RegExp(r'^[0-9]+$').hasMatch(val.trim())) return 'Số điện thoại chỉ được chứa ký tự số';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Địa chỉ*'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập Địa chỉ' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Phân quyền (Role)'),
                items: ['ADMIN', 'STAFF', 'CUSTOMER'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _role = val!),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  child: const Text('TẠO TÀI KHOẢN')
              ),
            ],
          ),
        ),
      ),
    );
  }
}