import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../configs/apis.dart';
import '../../navigations/RootNavigator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null) apis.options.headers['Authorization'] = 'Bearer $token';

      Response res = await apis.get('/account/current-user/');
      setState(() {
        _user = res.data;
        _isLoading = false;
      });
    } catch (e) {
      print("Lỗi lấy Profile: $e");
      setState(() => _isLoading = false);
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

  Future<String?> _uploadToCloudinary(File file) async {
    try {
      String cloudName = 'dczihneby';
      String uploadPreset = 'ShoppingAvatar';

      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: 'avatar.jpg'),
        'upload_preset': uploadPreset,
      });

      Response response = await Dio().post(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        data: formData,
      );

      return response.data['secure_url'];
    } catch (e) {
      print("Lỗi upload Cloudinary: $e");
      return null;
    }
  }

  ImageProvider? _getAvatarProvider(String? avatarString, File? localFile) {
    if (localFile != null) return FileImage(localFile);
    if (avatarString == null || avatarString.isEmpty) return null;
    return NetworkImage(avatarString);
  }

  void _showEditInfoModal() {
    final _firstNameCtrl = TextEditingController(text: _user?['first_name'] ?? '');
    final _lastNameCtrl = TextEditingController(text: _user?['last_name'] ?? '');
    final _emailCtrl = TextEditingController(text: _user?['email'] ?? '');
    final _phoneCtrl = TextEditingController(text: _user?['phone'] ?? '');
    final _addressCtrl = TextEditingController(text: _user?['address'] ?? '');
    File? _avatarFile;
    bool _isSavingInfo = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16, right: 16, top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chỉnh sửa Thông tin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () async {
                      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) setModalState(() => _avatarFile = File(pickedFile.path));
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: _getAvatarProvider(_user?['avatar'], _avatarFile),
                          child: (_avatarFile == null && (_user?['avatar'] == null || _user!['avatar'].toString().isEmpty))
                              ? const Icon(Icons.person, size: 45, color: Colors.white)
                              : null,
                        ),
                        Container(
                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Họ', border: OutlineInputBorder()))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: _firstNameCtrl, decoration: const InputDecoration(labelText: 'Tên', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Địa chỉ', border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: _isSavingInfo ? null : () async {
                        setModalState(() => _isSavingInfo = true);
                        try {
                          String? avatarUrl;
                          if (_avatarFile != null) {
                            avatarUrl = await _uploadToCloudinary(_avatarFile!);
                            if (avatarUrl == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi tải ảnh lên Cloudinary!'), backgroundColor: Colors.red));
                              setModalState(() => _isSavingInfo = false);
                              return;
                            }
                          }
                          Map<String, dynamic> updateData = {
                            'first_name': _firstNameCtrl.text,
                            'last_name': _lastNameCtrl.text,
                            'email': _emailCtrl.text,
                            'phone': _phoneCtrl.text,
                            'address': _addressCtrl.text,
                          };
                          if (avatarUrl != null) updateData['avatar'] = avatarUrl;
                          await apis.patch('/account/current-user/', data: updateData);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!'), backgroundColor: Colors.green));
                          Navigator.pop(ctx);
                          _fetchProfile();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi cập nhật. Vui lòng kiểm tra lại thông tin.'), backgroundColor: Colors.red));
                        } finally {
                          setModalState(() => _isSavingInfo = false);
                        }
                      },
                      child: _isSavingInfo ? const CircularProgressIndicator(color: Colors.white) : const Text('Lưu thông tin', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChangePasswordModal() {
    final _oldPasswordCtrl = TextEditingController();
    final _newPasswordCtrl = TextEditingController();
    final _confirmNewPasswordCtrl = TextEditingController();
    bool _isSavingPass = false;
    String? _errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16, right: 16, top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Đổi Mật Khẩu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_errorText!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  TextField(controller: _oldPasswordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _newPasswordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu mới', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _confirmNewPasswordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới', border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: _isSavingPass ? null : () async {
                        setModalState(() => _errorText = null);
                        if (_oldPasswordCtrl.text.isEmpty) {
                          setModalState(() => _errorText = 'Vui lòng nhập mật khẩu hiện tại!');
                          return;
                        }
                        if (_newPasswordCtrl.text.isEmpty) {
                          setModalState(() => _errorText = 'Vui lòng nhập mật khẩu mới!');
                          return;
                        }
                        if (_newPasswordCtrl.text != _confirmNewPasswordCtrl.text) {
                          setModalState(() => _errorText = 'Mật khẩu mới không khớp!');
                          return;
                        }

                        setModalState(() => _isSavingPass = true);
                        try {
                          await apis.patch('/account/current-user/', data: {
                            'old_password': _oldPasswordCtrl.text,
                            'password': _newPasswordCtrl.text
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công!'), backgroundColor: Colors.green));
                          Navigator.pop(ctx);
                        } catch (e) {
                          String errMsg = 'Mật khẩu hiện tại không đúng!';
                          if (e is DioException && e.response != null && e.response!.data is Map) {
                            var oldPassError = e.response!.data['old_password'];
                            if (oldPassError != null) {
                              if (oldPassError is List && oldPassError.isNotEmpty) {
                                errMsg = oldPassError[0].toString();
                              } else {
                                errMsg = oldPassError.toString();
                              }
                            }
                          }
                          setModalState(() => _errorText = errMsg);
                        } finally {
                          setModalState(() => _isSavingPass = false);
                        }
                      },
                      child: _isSavingPass ? const CircularProgressIndicator(color: Colors.white) : const Text('Lưu mật khẩu', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_user == null) return const Scaffold(body: Center(child: Text('Lỗi tải dữ liệu cá nhân')));

    double coins = double.tryParse(_user?['coins']?.toString() ?? '0') ?? 0.0;
    String fullName = '${_user?['last_name'] ?? ''} ${_user?['first_name'] ?? ''}'.trim();
    if (fullName.isEmpty) fullName = 'Chưa cập nhật tên';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: _logout),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      // BỌC REFRESH INDICATOR ĐỂ KÉO XUỐNG TẢI LẠI TRANG
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: _fetchProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Đảm bảo luôn kéo được dù nội dung ngắn
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 30),
                width: double.infinity,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _getAvatarProvider(_user?['avatar'], null),
                      child: (_user?['avatar'] == null || _user!['avatar'].toString().isEmpty)
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        fullName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('@${_user?['username']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),

                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade200)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text('Shopee Xu: $coins', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.blueAccent),
                      title: const Text('Email'),
                      subtitle: Text(_user?['email']?.isEmpty == true ? 'Chưa cập nhật' : _user?['email']),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.phone, color: Colors.green),
                      title: const Text('Số điện thoại'),
                      subtitle: Text(_user?['phone']?.isEmpty == true ? 'Chưa cập nhật' : _user?['phone']),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.redAccent),
                      title: const Text('Địa chỉ'),
                      subtitle: Text(_user?['address']?.isEmpty == true ? 'Chưa cập nhật' : _user?['address']),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blueAccent)),
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        label: const Text('Chỉnh sửa thông tin', style: TextStyle(color: Colors.blueAccent, fontSize: 16)),
                        onPressed: _showEditInfoModal,
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                        icon: const Icon(Icons.lock, color: Colors.orange),
                        label: const Text('Cập nhật mật khẩu', style: TextStyle(color: Colors.orange, fontSize: 16)),
                        onPressed: _showChangePasswordModal,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}