// 創店前閱讀平台條款；只調整呈現，不變更條款或同意紀錄。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/platform_policy_manage_service.dart';

class PlatformShopOwnerPolicyPage extends StatefulWidget {
  const PlatformShopOwnerPolicyPage({
    super.key,
    required this.onAgree,
    this.loadPolicy,
  });
  static const String policyKey = 'shop_owner_policy';
  final VoidCallback onAgree;
  final Future<Map<String, dynamic>?> Function()? loadPolicy;
  @override
  State<PlatformShopOwnerPolicyPage> createState() =>
      _PlatformShopOwnerPolicyPageState();
}

class _PlatformShopOwnerPolicyPageState
    extends State<PlatformShopOwnerPolicyPage> {
  bool hasReadToBottom = false, agreed = false, loading = true;
  String title = '創店主條款', content = '';
  int version = 1;
  Object? _loadError;
  final controller = ScrollController();

  @override
  void initState() {
    super.initState();
    controller.addListener(_checkReading);
    _loadPolicy();
  }

  void _checkReading() {
    if (!mounted ||
        loading ||
        _loadError != null ||
        !controller.hasClients ||
        hasReadToBottom) {
      return;
    }
    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 20) {
      setState(() => hasReadToBottom = true);
    }
  }

  void _checkAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkReading());
  }

  Future<void> _loadPolicy() async {
    setState(() {
      loading = true;
      _loadError = null;
    });
    try {
      final data =
          await (widget.loadPolicy?.call() ??
              PlatformPolicyManageService.instance.getPolicy(
                PlatformShopOwnerPolicyPage.policyKey,
              ));
      if (!mounted) return;
      setState(() {
        title = data?['title']?.toString() ?? '創店主條款';
        content = data?['content']?.toString() ?? '目前尚未設定創店主條款。';
        version = data?['version'] is int ? data!['version'] : 1;
        loading = false;
      });
      _checkAfterLayout();
    } catch (error) {
      if (mounted) {
        setState(() {
          loading = false;
          _loadError = error;
        });
      }
    }
  }

  @override
  void dispose() {
    controller.removeListener(_checkReading);
    controller.dispose();
    super.dispose();
  }

  // Interpret only structural heading/list/separator markers; the stored legal
  // wording and its version are never rewritten or saved by this renderer.
  List<Widget> _paragraphs() {
    final paragraphs = content
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n'));
    return [
      for (final paragraph in paragraphs)
        if (paragraph.trim().isNotEmpty)
          if (RegExp(r'^\s*([-*_])\1{2,}\s*$').hasMatch(paragraph))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 24),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final (index, line)
                        in paragraph.split('\n').indexed) ...[
                      if (index > 0) const TextSpan(text: '\n'),
                      TextSpan(
                        text: line
                            .replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '')
                            .replaceFirst(RegExp(r'^\s*[*-]\s+'), '• '),
                        style: RegExp(r'^\s*#{1,6}\s+').hasMatch(line)
                            ? const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Color(0xFF243B53),
                              )
                            : null,
                      ),
                    ],
                  ],
                ),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.85,
                  color: Color(0xFF425466),
                ),
              ),
            ),
    ];
  }

  Widget _confirmation(bool desktop) {
    final check = CheckboxListTile(
      value: agreed,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: const Text(
        '我已閱讀並同意平台創店主條款',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: !hasReadToBottom
          ? const Text('請先閱讀至條款最下方', style: TextStyle(fontSize: 12))
          : null,
      onChanged: hasReadToBottom
          ? (value) => setState(() => agreed = value ?? false)
          : null,
    );
    final button = FilledButton(
      onPressed: agreed && hasReadToBottom ? widget.onAgree : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(180, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('同意並繼續'),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(
        desktop ? 28 : 16,
        10,
        desktop ? 28 : 16,
        16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE6EBF0))),
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(child: check),
                const SizedBox(width: 24),
                button,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [check, const SizedBox(height: 4), button],
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F6FA),
    appBar: AppBar(
      title: Text(title),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      top: false,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('條款暫時無法載入，請稍後重試。'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loadPolicy,
                    child: const Text('重新載入'),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 760;
                return Center(
                  child: Padding(
                    padding: desktop
                        ? const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 24,
                          )
                        : EdgeInsets.zero,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(desktop ? 20 : 0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE4E9F0)),
                            borderRadius: BorderRadius.circular(
                              desktop ? 20 : 0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  desktop ? 32 : 20,
                                  desktop ? 24 : 16,
                                  desktop ? 32 : 20,
                                  16,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '閱讀並確認條款',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF243B53),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '版本 v$version · 請閱讀至最下方後勾選同意。',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFE6EBF0),
                              ),
                              Expanded(
                                child: Scrollbar(
                                  controller: controller,
                                  thumbVisibility: desktop,
                                  child:
                                      NotificationListener<
                                        ScrollMetricsNotification
                                      >(
                                        onNotification: (_) {
                                          _checkAfterLayout();
                                          return false;
                                        },
                                        child: SingleChildScrollView(
                                          key: const Key('owner-policy-reader'),
                                          controller: controller,
                                          padding: EdgeInsets.fromLTRB(
                                            desktop ? 48 : 20,
                                            24,
                                            desktop ? 48 : 20,
                                            24,
                                          ),
                                          child: SelectionArea(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: _paragraphs(),
                                            ),
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                              _confirmation(desktop),
                            ],
                          ),
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
