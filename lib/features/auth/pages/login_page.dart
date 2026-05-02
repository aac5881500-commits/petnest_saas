// 🔐 登入頁 LoginPage

// 檔案名稱 lib/features/auth/pages/login_page.dart
// 功能：
// - 登入
// - 記住 Email
// - 下次自動填入

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 新增
import 'package:petnest_saas/core/services/auth_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  /// 🔥 記住帳號
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  /// 🔥 讀取已儲存 Email
  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');

    if (savedEmail != null) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberEmail = true;
      });
    }
  }

  /// 🔵 登入
  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

/// 🔥 登入成功 → 回首頁（或店家頁）
Navigator.pushNamedAndRemoveUntil(
  context,
  '/home',
  (route) => false,
);

      /// 🔥 記住帳號
      final prefs = await SharedPreferences.getInstance();

      if (_rememberEmail) {
        await prefs.setString('saved_email', _emailController.text.trim());
      } else {
        await prefs.remove('saved_email');
      }
    } catch (e) {
      setState(() {
        _error = '登入失敗：$e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /// 🏪 建立店家（測試用）
  Future<void> _createShop() async {
    try {
      final shopId = await ShopService.instance.createShop(
        name: '我的第一間店',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('店家建立成功：$shopId')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('建立失敗：$e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登入')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 8),

                /// 🔥 記住帳號
                CheckboxListTile(
                  title: const Text('記住帳號'),
                  value: _rememberEmail,
                  onChanged: (value) {
                    setState(() {
                      _rememberEmail = value ?? false;
                    });
                  },
                ),

                /// 錯誤訊息
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),

                const SizedBox(height: 12),

                /// 登入按鈕
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: Text(_loading ? '登入中...' : '登入'),
                  ),
                ),

                const SizedBox(height: 12),

/// 🔥 Google 登入
SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    icon: const Icon(Icons.g_mobiledata, size: 28),
    label: const Text('使用 Google 登入'),
    onPressed: _loading
        ? null
        : () async {
            try {
              setState(() {
                _loading = true;
              });

              final result =
                  await AuthService.instance.signInWithGoogle();

              if (result == null) return;

              if (!mounted) return;

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Google登入失敗: $e')),
              );
            } finally {
              if (mounted) {
                setState(() {
                  _loading = false;
                });
              }
            }
          },
  ),
),

const SizedBox(height: 12),


                /// 建立店家
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _createShop,
                    child: const Text('建立店家'),
                  ),
                ),

                const SizedBox(height: 12),

                /// 註冊
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                  child: const Text('還沒有帳號？前往註冊'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}