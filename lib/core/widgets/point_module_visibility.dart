// 檔案名稱：lib/core/widgets/point_module_visibility.dart
// 功能說明：監聽店家的點數設定，依照目前啟用、曾經啟用但已關閉
// 🪙 點數模組狀態共用元件
// 從未啟用三種狀態，顯示不同內容。
// 關閉點數制度不會刪除任何 Firestore 點數資料。

import 'package:flutter/material.dart';

import '../models/point_module_status.dart';
import '../models/point_setting_model.dart';
import '../services/point_module_access_service.dart';
import '../services/point_setting_service.dart';

class PointModuleVisibility extends StatelessWidget {
  const PointModuleVisibility({
    super.key,
    required this.shopId,
    required this.enabledChild,
    this.historyChild = const SizedBox.shrink(),
    this.neverUsedChild = const SizedBox.shrink(),
    this.loadingChild = const SizedBox.shrink(),
    this.errorChild = const SizedBox.shrink(),
  });

  /// 店家 ID
  final String shopId;

  /// 點數制度目前啟用時顯示的內容
  final Widget enabledChild;

  /// 點數制度曾經啟用，但目前已關閉時顯示的內容
  ///
  /// 適合顯示唯讀點數、點數紀錄及既有兌換紀錄。
  final Widget historyChild;

  /// 店家從未啟用點數制度時顯示的內容
  ///
  /// 預設完全隱藏。
  final Widget neverUsedChild;

  /// 讀取設定期間顯示的內容
  ///
  /// 預設完全隱藏，避免畫面閃動。
  final Widget loadingChild;

  /// 讀取設定失敗時顯示的內容
  ///
  /// 預設完全隱藏，避免錯誤時誤顯示點數功能。
  final Widget errorChild;

  @override
  Widget build(BuildContext context) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return neverUsedChild;
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
            final PointModuleAccess access = PointModuleAccessService.resolve(
              setting,
            );
            final PointModuleStatus status = access.status;

            switch (status) {
              case PointModuleStatus.enabled:
                return enabledChild;

              case PointModuleStatus.disabledWithHistory:
                return historyChild;

              case PointModuleStatus.neverUsed:
                return neverUsedChild;
            }
          },
    );
  }
}
