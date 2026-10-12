// 檔案名稱：lib/core/web/web_update_prompt.dart
// 功能說明：顯示小型更新提示，並在重新載入前提醒尚未儲存的內容。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/navigation/app_navigator.dart';
import 'package:petnest_saas/core/web/web_build_info.dart';
import 'package:petnest_saas/core/web/web_update_controller.dart';

class WebUpdateOverlay extends StatelessWidget {
  const WebUpdateOverlay({
    super.key,
    required this.child,
    this.controller,
    this.enabled,
  });

  final Widget child;
  final WebUpdateController? controller;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final bool active = enabled ?? kIsWeb;
    if (!active) return child;
    final WebUpdateController updates = controller ?? WebUpdateController.instance;
    return ListenableBuilder(
      listenable: updates,
      builder: (BuildContext context, Widget? _) {
        if (!updates.showPrompt) return child;
        final bool wide = MediaQuery.sizeOf(context).width >= 700;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            child,
            Positioned(
              top: wide ? 12 : 8,
              right: 12,
              left: wide ? null : 12,
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 380 : 480),
                  child: WebUpdateNotice(
                    onLater: updates.dismissPrompt,
                    onUpdate: () => confirmAndApplyWebUpdate(
                      context,
                      controller: updates,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class WebUpdateNotice extends StatelessWidget {
  const WebUpdateNotice({
    super.key,
    required this.onLater,
    required this.onUpdate,
  });

  final VoidCallback onLater;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8F0),
      elevation: 6,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE7D3C4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'PetNest 有新版本',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text('新版本已準備好，建議更新以取得最新功能與修正。'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(onPressed: onLater, child: const Text('稍後再說')),
                FilledButton(
                  onPressed: onUpdate,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD4894C),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('立即更新'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WebUpdatePanel extends StatelessWidget {
  const WebUpdatePanel({super.key, required this.controller});

  final WebUpdateController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final bool checking = controller.phase == WebUpdatePhase.checking;
        final bool available =
            controller.phase == WebUpdatePhase.updateAvailable;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            const Text('版本', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(webUpdatePhaseLabel(controller.phase)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: checking
                      ? null
                      : () => controller.check(manual: true),
                  child: const Text('檢查更新'),
                ),
                if (available)
                  FilledButton(
                    onPressed: () => confirmAndApplyWebUpdate(
                      context,
                      controller: controller,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD4894C),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('立即更新'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

Future<void> confirmAndApplyWebUpdate(
  BuildContext context, {
  WebUpdateController? controller,
}) async {
  final WebUpdateController updates =
      controller ?? WebUpdateController.instance;
  final NavigatorState? navigator = Navigator.maybeOf(context);
  final BuildContext? dialogContext = navigator != null
      ? context
      : AppNavigator.key.currentState?.overlay?.context;
  if (dialogContext == null) return;
  final bool? proceed = await showDialog<bool>(
    context: dialogContext,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('更新前請先確認'),
        content: const Text(
          '重新載入會離開目前畫面。如果這個頁面還有尚未儲存的內容，請先返回並儲存。PetNest 無法確認每一個畫面是否都已儲存。重新載入不會清除登入狀態、店家或訂單資料。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD4894C),
              foregroundColor: Colors.white,
            ),
            child: const Text('仍要更新'),
          ),
        ],
      );
    },
  );
  if (proceed != true) return;
  try {
    await updates.applyUpdate();
  } catch (_) {
    final BuildContext? messengerContext = AppNavigator.key.currentContext;
    if (messengerContext == null || !messengerContext.mounted) return;
    ScaffoldMessenger.of(messengerContext).showSnackBar(
      const SnackBar(content: Text('更新沒有完成，請稍後再試。')),
    );
  }
}
