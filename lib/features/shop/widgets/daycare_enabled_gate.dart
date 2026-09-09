// 檔案名稱：lib/features/shop/widgets/daycare_enabled_gate.dart
// 功能說明：安親關閉時擋住設定／新增入口，既有訂單詳細不走這層

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_enabled.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/daycare_feature_off_scaffold.dart';

class DaycareEnabledGate extends StatelessWidget {
  const DaycareEnabledGate({
    super.key,
    required this.shopId,
    required this.child,
    this.title = '安親服務',
    this.allowWhenOff = false,
  });

  final String shopId;
  final Widget child;
  final String title;
  final bool allowWhenOff;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> shopSnap,
          ) {
            return StreamBuilder<DaycareSettingsModel>(
              stream: DaycareSettingsService.instance.stream(shopId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DaycareSettingsModel> settingSnap,
                  ) {
                    if (!shopSnap.hasData) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final bool on = DaycareEnabled.isOn(
                      shop: shopSnap.data,
                      settings: settingSnap.data,
                    );
                    if (!on && !allowWhenOff) {
                      return DaycareFeatureOffScaffold(title: title);
                    }
                    return child;
                  },
            );
          },
    );
  }
}
