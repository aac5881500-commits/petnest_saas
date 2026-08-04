// lib/core/widgets/point_module_visibility.dart
// 🪙 點數模組總開關共用元件
// 功能：監聽店家的點數設定，只有 enabled = true 時才顯示點數相關內容。
// 關閉時只隱藏功能，不會刪除任何 Firestore 點數資料。

import 'package:flutter/material.dart';

import '../models/point_setting_model.dart';
import '../services/point_setting_service.dart';

class PointModuleVisibility extends StatelessWidget {
  const PointModuleVisibility({
    super.key,
    required this.shopId,
    required this.enabledChild,
    this.disabledChild = const SizedBox.shrink(),
    this.loadingChild = const SizedBox.shrink(),
    this.errorChild = const SizedBox.shrink(),
  });

  /// 店家 ID
  final String shopId;

  /// 點數制度開啟時顯示的內容
  final Widget enabledChild;

  /// 點數制度關閉時顯示的內容
  ///
  /// 預設為完全隱藏。
  final Widget disabledChild;

  /// 讀取設定期間顯示的內容
  ///
  /// 預設為完全隱藏，避免選單讀取時跳動。
  final Widget loadingChild;

  /// 讀取設定失敗時顯示的內容
  ///
  /// 預設為完全隱藏，避免錯誤時誤顯示點數功能。
  final Widget errorChild;

  @override
  Widget build(BuildContext context) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return disabledChild;
    }

    return StreamBuilder<PointSettingModel>(
      stream: PointSettingService.instance.streamPointSetting(normalizedShopId),
      builder:
          (BuildContext context, AsyncSnapshot<PointSettingModel> snapshot) {
            if (snapshot.hasError) {
              return errorChild;
            }

            if (!snapshot.hasData) {
              return loadingChild;
            }

            final PointSettingModel setting = snapshot.data!;

            if (!setting.enabled) {
              return disabledChild;
            }

            return enabledChild;
          },
    );
  }
}
