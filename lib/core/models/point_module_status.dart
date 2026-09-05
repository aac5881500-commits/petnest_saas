// 檔案名稱：lib/core/models/point_module_status.dart
// 功能說明：點數模組狀態

enum PointModuleStatus {
  /// 從未啟用
  neverUsed,

  /// 目前啟用
  enabled,

  /// 已停用，但保留歷史資料
  disabledWithHistory,
}
