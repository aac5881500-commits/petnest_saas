//🟢 註冊頁 RegisterPage
// 功能：
// - 建立 Firebase 帳號
// - 建立 Firestore users 資料
// - 成功後返回登入頁

import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  /// 輸入控制
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// UI 狀態
  bool _loading = false;
  String? _error;

  /// 🟢 註冊
  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _nameController.text.trim(),
      );

      /// 註冊成功 → 回上一頁（登入）
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = '註冊失敗：$e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// 名稱
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '名稱',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                /// Email
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                /// 密碼
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密碼',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                /// 錯誤訊息
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),

                const SizedBox(height: 12),

                /// 註冊按鈕
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: Text(_loading ? '註冊中...' : '註冊'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}