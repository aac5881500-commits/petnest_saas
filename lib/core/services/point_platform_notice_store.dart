// 檔案名稱：lib/core/services/point_platform_notice_store.dart
// 功能說明：用本機偏好記錄點數平台公告已閱讀。不讀寫 Firestore。

import 'package:shared_preferences/shared_preferences.dart';

import '../models/point_notice_acceptance.dart';

class PointPlatformNoticeStore {
  const PointPlatformNoticeStore._();

  static Future<bool> hasSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PointPlatformNotice.seenKey) == true;
  }

  static Future<void> markSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PointPlatformNotice.seenKey, true);
  }
}
