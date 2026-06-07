// 🔐 登入頁 LoginPage

// 檔案名稱 lib/features/auth/pages/login_page.dart
// 功能：
// - 登入
// - 記住 Email
// - 下次自動填入
// - 登入後檢查平台會員條款版本

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/auth_service.dart';
import 'package:petnest_saas/core/services/platform_policy_service.dart';
import 'package:petnest_saas/features/platform/pages/platform_user_policy_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'register_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_qr_scan_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.redirectShopId});

  final String? redirectShopId;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

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

  Future<void> _goNextAfterLogin() async {
    final accepted = await PlatformPolicyService.instance
        .hasAcceptedCurrentUserPolicy();

    if (!mounted) return;

    if (!accepted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlatformUserPolicyPage(
            onAgree: () async {
              await PlatformPolicyService.instance.acceptCurrentUserPolicy();

              if (!mounted) return;

              Navigator.pop(context);

              await _goNextAfterLogin();
            },
          ),
        ),
      );
      return;
    }

    if (widget.redirectShopId != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ShopPublicPage(shopId: widget.redirectShopId!),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

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

      final prefs = await SharedPreferences.getInstance();

      if (_rememberEmail) {
        await prefs.setString('saved_email', _emailController.text.trim());
      } else {
        await prefs.remove('saved_email');
      }

      if (!mounted) return;

      await _goNextAfterLogin();
    } catch (e) {
      setState(() {
        _error = '登入失敗：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _googleLogin() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final result = await AuthService.instance.signInWithGoogle();

      if (result == null) return;

      if (!mounted) return;

      await _goNextAfterLogin();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google登入失敗: $e')));
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
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密碼',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 8),

                CheckboxListTile(
                  title: const Text('記住帳號'),
                  value: _rememberEmail,
                  onChanged: (value) {
                    setState(() {
                      _rememberEmail = value ?? false;
                    });
                  },
                ),

                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: Text(_loading ? '登入中...' : '登入'),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('使用 Google 登入'),
                    onPressed: _loading ? null : _googleLogin,
                  ),
                ),

                const SizedBox(height: 12),

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
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('掃描店家 QRCode'),
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ShopQrScanPage(),
                              ),
                            );
                          },
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
