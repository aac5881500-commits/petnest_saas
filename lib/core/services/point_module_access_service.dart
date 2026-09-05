// 檔案名稱：lib/core/services/point_module_access_service.dart
// 功能說明：集中管理點數模組的顯示與操作權限。
// 🪙 點數模組存取判斷

import '../models/point_module_status.dart';
import '../models/point_setting_model.dart';

class PointModuleAccess {
  const PointModuleAccess({
    required this.status,
    required this.canShowEntry,
    required this.canExchange,
    required this.canManage,
    required this.readOnly,
  });

  final PointModuleStatus status;

  /// 是否顯示入口
  final bool canShowEntry;

  /// 是否允許兌換
  final bool canExchange;

  /// 是否允許店主管理
  final bool canManage;

  /// 是否唯讀
  final bool readOnly;
}

class PointModuleAccessService {
  const PointModuleAccessService._();

  static PointModuleAccess resolve(PointSettingModel setting) {
    if (setting.enabled) {
      return const PointModuleAccess(
        status: PointModuleStatus.enabled,
        canShowEntry: true,
        canExchange: true,
        canManage: true,
        readOnly: false,
      );
    }

    if (setting.everEnabled) {
      return const PointModuleAccess(
        status: PointModuleStatus.disabledWithHistory,
        canShowEntry: true,
        canExchange: false,
        canManage: false,
        readOnly: true,
      );
    }

    return const PointModuleAccess(
      status: PointModuleStatus.neverUsed,
      canShowEntry: false,
      canExchange: false,
      canManage: false,
      readOnly: false,
    );
  }
}
