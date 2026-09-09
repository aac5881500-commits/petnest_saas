// 檔案名稱：lib/features/shop/widgets/daycare_feature_off_scaffold.dart
// 功能說明：安親關閉時的舊入口／deep link 提示，不清空既有設定

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/daycare_enabled.dart';

class DaycareFeatureOffScaffold extends StatelessWidget {
  const DaycareFeatureOffScaffold({super.key, this.title = '安親服務'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            DaycareEnabled.closedMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.5),
          ),
        ),
      ),
    );
  }
}
