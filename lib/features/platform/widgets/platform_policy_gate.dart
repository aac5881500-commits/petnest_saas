// 檔案名稱：lib/features/platform/widgets/platform_policy_gate.dart
// 功能說明：已登入使用者若未確認最新平台條款，先顯示不可略過的確認頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/platform_policy_service.dart';
import 'package:petnest_saas/features/platform/pages/platform_user_policy_page.dart';

class PlatformPolicyGate extends StatefulWidget {
  const PlatformPolicyGate({super.key, required this.child});

  final Widget child;

  @override
  State<PlatformPolicyGate> createState() => _PlatformPolicyGateState();
}

class _PlatformPolicyGateState extends State<PlatformPolicyGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _required = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
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
    try {
      final bool accepted = await PlatformPolicyService.instance
          .hasAcceptedCurrentUserPolicy();
      if (!mounted) return;
      setState(() {
        _required = !accepted;
        _failed = false;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _required = true;
        _checking = false;
      });
    }
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
              children: <Widget>[
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
      return PlatformUserPolicyPage(
        onAgree: () async {
          await PlatformPolicyService.instance.acceptCurrentUserPolicy();
          if (!mounted) return;
          setState(() => _required = false);
        },
      );
    }
    return widget.child;
  }
}
