// 檔案名稱：lib/features/shop/widgets/daycare_feature_off_scaffold.dart
// 功能說明：安親關閉時的舊入口／deep link 提示，不清空既有設定

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/daycare_enabled.dart';

class DaycareFeatureOffScaffold extends StatelessWidget {
  const DaycareFeatureOffScaffold({
    super.key,
    this.title = '安親服務',
    this.headline,
    this.message,
    this.showBackAction = false,
  });

  final String title;
  final String? headline;
  final String? message;

  /// 深連結進已關閉的設定頁時，提供返回或回店主後台。
  final bool showBackAction;

  @override
  Widget build(BuildContext context) {
    final String body = (message ?? '').trim().isEmpty
        ? DaycareEnabled.closedMessage
        : message!.trim();
    final bool canPop = Navigator.canPop(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if ((headline ?? '').trim().isNotEmpty) ...<Widget>[
                Text(
                  headline!.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              if (showBackAction) ...<Widget>[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (canPop) {
                      Navigator.pop(context);
                      return;
                    }
                    Navigator.of(context).popUntil((Route<dynamic> route) {
                      return route.isFirst;
                    });
                  },
                  child: Text(canPop ? '返回' : '回店主後台'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
