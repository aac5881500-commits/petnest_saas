// 檔案名稱：lib/features/auth/pages/register_page.dart
// 功能說明：註冊頁 RegisterPage
// 功能：
// - 建立 Firebase 帳號
// - 建立 Firestore users 資料
// - 寄出驗證信後進入信箱驗證頁

import 'package:flutter/material.dart';
import '../../../core/services/auth_access_policy.dart';
import '../../../core/services/auth_service.dart';
import 'email_verification_page.dart';

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
    final String? emailError = AuthAccessPolicy.emailIssue(
      _emailController.text,
    );
    if (emailError != null) {
      setState(() {
        _error = emailError;
      });
      return;
    }
    final String? passwordError = AuthAccessPolicy.passwordIssue(
      _passwordController.text,
    );
    if (passwordError != null) {
      setState(() {
        _error = passwordError;
      });
      return;
    }
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

      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const EmailVerificationPage(justSent: true),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      final String? message = AuthService.authErrorMessage(error);
      if (!mounted || message == null) {
        return;
      }
      setState(() {
        _error = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
                  Text(_error!, style: const TextStyle(color: Colors.red)),

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
