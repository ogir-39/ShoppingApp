import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../configs/apis.dart';

class RegisterScreen extends StatefulWidget {
  final BuildContext tabContext; // Nhận context từ màn hình Login để chuyển tab sau khi đăng ký thành công
  const RegisterScreen({Key? key, required this.tabContext}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _addressFocus = FocusNode();

  String? _usernameError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _phoneError;
  String? _addressError;

  bool _isLoading = false;
  bool _obscurePassword = true;
  DateTime? _dob;
  File? _avatar;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _avatar = File(pickedFile.path));
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _dob = date);
  }

  void _clearErrors() {
    setState(() {
      _usernameError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _phoneError = null;
      _addressError = null;
    });
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

  Future<void> _register() async {
    _clearErrors();
    bool hasError = false;

    if (_usernameCtrl.text.isEmpty) {
      _usernameError = 'Tên đăng nhập không được để trống';
      _usernameFocus.requestFocus();
      hasError = true;
    } else if (_phoneCtrl.text.isEmpty) {
      _phoneError = 'Số điện thoại không được để trống';
      _phoneFocus.requestFocus();
      hasError = true;
    } else if (_addressCtrl.text.isEmpty) {
      _addressError = 'Địa chỉ không được để trống';
      _addressFocus.requestFocus();
      hasError = true;
    } else if (_passwordCtrl.text.isEmpty) {
      _passwordError = 'Mật khẩu không được để trống';
      _passwordFocus.requestFocus();
      hasError = true;
    } else if (_confirmPasswordCtrl.text.isEmpty) {
      _confirmPasswordError = 'Vui lòng xác nhận mật khẩu';
      _confirmPasswordFocus.requestFocus();
      hasError = true;
    } else if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _confirmPasswordError = 'Mật khẩu nhập lại không khớp';
      _confirmPasswordFocus.requestFocus();
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    String? avatarUrl;

    try {
      if (_avatar != null) {
        avatarUrl = await _uploadToCloudinary(_avatar!);
        if (avatarUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi tải ảnh lên Cloudinary. Vui lòng thử lại!'), backgroundColor: Colors.red));
          setState(() => _isLoading = false);
          return;
        }
      }

      Map<String, dynamic> registerData = {
        'username': _usernameCtrl.text,
        'phone': _phoneCtrl.text,
        'password': _passwordCtrl.text,
        'address': _addressCtrl.text,
      };
      if (avatarUrl != null) registerData['avatar'] = avatarUrl;

      await apis.post(endpoints['register'], data: registerData);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi đăng ký! Username có thể đã tồn tại.'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng ký thành công! Hãy đăng nhập.'), backgroundColor: Colors.green));

    setState(() {
      _usernameCtrl.clear();
      _passwordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _phoneCtrl.clear();
      _addressCtrl.clear();
      _avatar = null;
      _dob = null;
      _isLoading = false;
      _clearErrors();
    });

    // Chuyển tab qua giao diện đăng nhập (Dùng context được truyền từ LoginScreen)
    DefaultTabController.of(widget.tabContext)?.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[300],
              backgroundImage: _avatar != null ? FileImage(_avatar!) : null,
              child: _avatar == null ? const Icon(Icons.camera_alt, size: 30, color: Colors.grey) : null,
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _usernameCtrl,
            focusNode: _usernameFocus,
            decoration: InputDecoration(labelText: 'Username (*)', errorText: _usernameError),
          ),

          TextField(
            controller: _phoneCtrl,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Số điện thoại (*)', errorText: _phoneError),
          ),

          TextField(
            controller: _addressCtrl,
            focusNode: _addressFocus,
            decoration: InputDecoration(labelText: 'Địa chỉ (*)', errorText: _addressError),
          ),

          const SizedBox(height: 10),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Ngày sinh'),
              child: Text(_dob == null ? 'Chọn ngày sinh' : '${_dob!.day}/${_dob!.month}/${_dob!.year}'),
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
                labelText: 'Mật khẩu (*)',
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
            ),
          ),

          TextField(
            controller: _confirmPasswordCtrl,
            focusNode: _confirmPasswordFocus,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Nhập lại mật khẩu (*)',
              errorText: _confirmPasswordError,
            ),
          ),

          const SizedBox(height: 20),
          _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(onPressed: _register, child: const Text('Đăng ký')),
        ],
      ),
    );
  }
}