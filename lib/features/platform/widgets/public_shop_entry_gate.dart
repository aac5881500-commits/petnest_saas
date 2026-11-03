import 'package:flutter/material.dart';
import 'package:petnest_saas/core/widgets/app_state_panel.dart';

/// Loads the public storefront while its customer binding is prepared.
/// Store actions stay blocked until the server confirms the selected shop.
class PublicShopEntryGate extends StatefulWidget {
  const PublicShopEntryGate({
    super.key,
    required this.prepare,
    required this.shopBuilder,
  });
  final Future<void> Function() prepare;
  final WidgetBuilder shopBuilder;
  @override
  State<PublicShopEntryGate> createState() => _PublicShopEntryGateState();
}

class _PublicShopEntryGateState extends State<PublicShopEntryGate> {
  bool _loading = true;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await widget.prepare();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Scaffold(
        appBar: AppBar(title: const Text('進入店家')),
        body: AppStatePanel(
          title: '暫時無法進入店家',
          message: '店家切換未完成，請檢查網路後重試。',
          onRetry: _prepare,
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(
          absorbing: _loading,
          child: ExcludeFocus(
            excluding: _loading,
            child: ExcludeSemantics(
              excluding: _loading,
              child: Builder(builder: widget.shopBuilder),
            ),
          ),
        ),
        if (_loading) ...[
          const ModalBarrier(dismissible: false, color: Color(0x33000000)),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('正在進入店家…'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text('返回找店'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
