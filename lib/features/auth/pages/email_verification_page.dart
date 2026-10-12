// 檔案名稱：lib/features/auth/pages/email_verification_page.dart
// 功能說明：Email／密碼尚未驗證時的等待畫面。以 Firebase Auth emailVerified 為準。

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/auth_access_policy.dart';
import 'package:petnest_saas/core/services/auth_service.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, this.justSent = false});

  final bool justSent;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _checking = false;
  bool _sending = false;
  DateTime? _lastSent;
  String? _error;
  String? _info;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.justSent) {
      _lastSent = DateTime.now();
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final Duration? wait = AuthAccessPolicy.resendWait(
        lastSent: _lastSent,
        now: DateTime.now(),
      );
      if (wait == null) {
        timer.cancel();
      }
      setState(() {});
    });
  }

  String get _email => FirebaseAuth.instance.currentUser?.email?.trim() ?? '';

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _error = null;
      _info = null;
    });
    try {
      final User? user = await AuthService.instance.reloadCurrentUser();
      if (!mounted) {
        return;
      }
      if (user == null) {
        setState(() {
          _error = '登入狀態已失效，請返回重新登入。';
        });
        return;
      }
      if (AuthService.instance.mustVerifyEmail(user)) {
        setState(() {
          _error = AuthAccessPolicy.emailNotVerifiedYet;
        });
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, '/entry', (
        Route<dynamic> route,
      ) {
        return false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = AuthService.authErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    final Duration? wait = AuthAccessPolicy.resendWait(
      lastSent: _lastSent,
      now: DateTime.now(),
    );
    if (wait != null || _sending) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.sendEmailVerification();
      if (!mounted) {
        return;
      }
      setState(() {
        _lastSent = DateTime.now();
        _info = '驗證信已重新寄出，請查看收件匣或垃圾郵件。';
      });
      _startTicker();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = AuthService.authErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _backToLogin() async {
    await AuthService.instance.logout();
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/login', (
      Route<dynamic> route,
    ) {
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Duration? wait = AuthAccessPolicy.resendWait(
      lastSent: _lastSent,
      now: DateTime.now(),
    );
    final bool cooling = wait != null;
    final int waitSeconds = wait == null
        ? 0
        : (wait.inSeconds < 1 ? 1 : wait.inSeconds);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: <Widget>[
                  Text(
                    'PetNest',
                    style: text.headlineMedium?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    elevation: 1,
                    shadowColor: colors.shadow.withValues(alpha: 0.12),
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            '驗證電子郵件',
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '我們已寄送驗證信至你的電子郵件。請開啟信件並完成驗證，即可開始使用 PetNest。',
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _email.isEmpty ? '目前帳號沒有電子郵件' : _email,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 12),
                            _notice(colors, text, _error!, isError: true),
                          ],
                          if (_info != null) ...<Widget>[
                            const SizedBox(height: 12),
                            _notice(colors, text, _info!, isError: false),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _checking ? null : _checkVerified,
                              child: Text(_checking ? '確認中...' : '我已完成驗證'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _sending || cooling ? null : _resend,
                              child: Text(
                                _sending
                                    ? '寄送中...'
                                    : cooling
                                    ? '請稍候 $waitSeconds 秒後再寄送'
                                    : '重新寄送驗證信',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _checking || _sending
                                ? null
                                : _backToLogin,
                            child: const Text('返回登入'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notice(
    ColorScheme colors,
    TextTheme text,
    String message, {
    required bool isError,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        message,
        style: text.bodyMedium?.copyWith(
          color: isError ? colors.error : colors.onSurface,
          height: 1.35,
        ),
      ),
    );
  }
}
