// 檔案名稱：lib/core/models/point_notice_acceptance.dart
// 功能說明：點數平台公告是否該在這台裝置顯示。不寫 Firestore，也不綁會員或店家。

class PointPlatformNotice {
  const PointPlatformNotice._();

  /// 公告版本。內容有重大調整時改這個 key，這台裝置會再看一次。
  static const String seenKey =
      'platform_notice_seen_point_system_independence_v1';

  /// 點數制度未啟用，或這台裝置已讀過目前版本時，不跳出。
  static bool shouldShow({required bool pointsEnabled, required bool seen}) {
    return pointsEnabled && !seen;
  }
}
