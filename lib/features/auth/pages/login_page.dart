// 檔案名稱：lib/features/auth/pages/login_page.dart
// 功能說明：登入頁 LoginPage
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
import 'package:petnest_saas/features/platform/widgets/platform_policy_gate.dart';
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
  bool _obscurePassword = true;

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
          builder: (_) => PlatformPolicyGate(
            child: ShopPublicPage(shopId: widget.redirectShopId!),
          ),
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double minHeight = constraints.maxHeight - 40;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minHeight < 0 ? 0 : minHeight,
                ),
                child: Align(
                  alignment: const Alignment(0, -0.18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _brandHeader(colors, text),
                        const SizedBox(height: 22),
                        _loginCard(colors, text),
                        const SizedBox(height: 18),
                        _qrEntry(colors, text),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _brandHeader(ColorScheme colors, TextTheme text) {
    return Column(
      children: <Widget>[
        Text(
          'PetNest',
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: colors.primary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '毛孩旅宿，從這裡開始',
          textAlign: TextAlign.center,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '登入後即可管理預約與毛孩資料',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _loginCard(ColorScheme colors, TextTheme text) {
    return Card(
      elevation: 1,
      shadowColor: colors.shadow.withValues(alpha: 0.12),
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '歡迎回來',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '登入你的 PetNest 帳號',
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: _fieldDecoration(
                colors: colors,
                label: 'Email',
                hint: 'example@email.com',
                icon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: _loading ? null : (_) => _login(),
              decoration: _fieldDecoration(
                colors: colors,
                label: '密碼',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  tooltip: _obscurePassword ? '顯示密碼' : '隱藏密碼',
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Checkbox(
                    value: _rememberEmail,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (bool? value) {
                      setState(() {
                        _rememberEmail = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _rememberEmail = !_rememberEmail;
                      });
                    },
                    child: Text('記住帳號', style: text.bodyMedium),
                  ),
                ],
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              _errorNotice(colors, text),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _loading ? null : _login,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Text(
                        '登入',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(child: Divider(color: colors.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '其他登入方式',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colors.outlineVariant)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _googleButton(colors),
                const SizedBox(width: 14),
                _appleButton(colors),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  '還沒有帳號？',
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                  child: const Text('建立帳號'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required ColorScheme colors,
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      constraints: const BoxConstraints(minHeight: 54),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.primary, width: 1.4),
      ),
    );
  }

  Widget _errorNotice(ColorScheme colors, TextTheme text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 18, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error ?? '',
              style: text.bodyMedium?.copyWith(
                color: colors.error,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _googleButton(ColorScheme colors) {
    return Tooltip(
      message: '使用 Google 登入',
      child: InkWell(
        onTap: _loading ? null : _googleLogin,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: const Text(
            'G',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4285F4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appleButton(ColorScheme colors) {
    return Tooltip(
      message: 'Apple 登入即將開放',
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Icon(
          Icons.apple,
          size: 25,
          color: colors.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _qrEntry(ColorScheme colors, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '已經有店家的 QR Code？',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: _loading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ShopQrScanPage(),
                      ),
                    );
                  },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.qr_code_scanner, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '掃描 QR Code 前往店家',
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(color: colors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
