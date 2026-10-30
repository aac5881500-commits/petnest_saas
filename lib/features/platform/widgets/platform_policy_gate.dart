import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/member_identity.dart';
import 'package:petnest_saas/core/services/platform_policy_service.dart';
import 'package:petnest_saas/features/platform/pages/platform_user_policy_page.dart';

class PlatformPolicyGate extends StatefulWidget {
  const PlatformPolicyGate({
    super.key,
    required this.child,
    this.authChanges,
    this.initialUser,
    this.checkAcceptance,
    this.acceptPolicy,
    this.consentBuilder,
  });
  final Widget child;
  final Stream<User?>? authChanges;
  final User? initialUser;
  final Future<bool> Function(User user)? checkAcceptance;
  final Future<void> Function()? acceptPolicy;
  final Widget Function(Future<void> Function() onAgree)? consentBuilder;
  @override
  State<PlatformPolicyGate> createState() => _PlatformPolicyGateState();
}

class _PlatformPolicyGateState extends State<PlatformPolicyGate>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  String? _identity;
  int _generation = 0;
  bool _checking = true;
  bool _required = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleUser(
      widget.authChanges == null
          ? FirebaseAuth.instance.currentUser
          : widget.initialUser,
    );
    _authSubscription =
        (widget.authChanges ?? FirebaseAuth.instance.authStateChanges()).listen(
          _handleUser,
        );
  }

  void _handleUser(User? user) {
    final identity = '${user?.uid}:${user?.isAnonymous}';
    _user = user;
    if (_identity == identity) return;
    _identity = identity;
    _check();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_required && !_checking) {
      _check();
    }
  }

  Future<void> _check() async {
    final generation = ++_generation;
    final user = _user;
    if (!isRegisteredMember(user)) {
      setState(() {
        _checking = false;
        _required = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _checking = true;
      _failed = false;
    });
    try {
      final accepted =
          await (widget.checkAcceptance?.call(user!) ??
              PlatformPolicyService.instance.hasAcceptedCurrentUserPolicy());
      if (!mounted || generation != _generation) return;
      setState(() {
        _required = !accepted;
        _failed = false;
        _checking = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _required = true;
        _checking = false;
      });
    }
  }

  Future<void> _agree() async {
    if (!isRegisteredMember(_user)) return;
    await (widget.acceptPolicy?.call() ??
        PlatformPolicyService.instance.acceptCurrentUserPolicy());
    if (mounted) await _check();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_failed) {
      return Scaffold(
        appBar: AppBar(title: const Text('平台會員條款')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('無法確認平台條款狀態，請再試一次。'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _check, child: const Text('重試')),
              ],
            ),
          ),
        ),
      );
    }
    if (_required) {
      return widget.consentBuilder?.call(_agree) ??
          PlatformUserPolicyPage(onAgree: _agree);
    }
    return widget.child;
  }
}
