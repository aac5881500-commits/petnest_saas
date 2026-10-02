// 檔案名稱：lib/core/services/notification_setting_service.dart
// 功能說明：讀取與更新會員的全域通知開關
// 🔔 通知設定 Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSettingService {
  NotificationSettingService._();

  static final NotificationSettingService instance =
      NotificationSettingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Map<String, bool> defaultSettings = <String, bool>{
    'enabled': true,
    'bookingStatus': true,
    'bookingMessage': true,
    'reviewReminder': true,
    'checkInReminder': true,
    'shopMarketing': true,
    'shopNotice': true,
    'platformMarketing': true,
  };

  /// 之後若要做每間店開關，可放在同一份 global 文件的 shopOverrides。本輪只使用全域鍵。
  static const String shopOverridesField = 'shopOverrides';

  static const Set<String> customerToggleKeys = <String>{
    'shopMarketing',
    'shopNotice',
    'platformMarketing',
  };

  DocumentReference<Map<String, dynamic>>? get _settingDocument {
    final User? user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notification_settings')
        .doc('global');
  }

  /// 即時監聽目前登入會員的通知設定
  Stream<Map<String, bool>> settingStream() {
    final DocumentReference<Map<String, dynamic>>? document = _settingDocument;

    if (document == null) {
      return Stream<Map<String, bool>>.value(
        Map<String, bool>.from(defaultSettings),
      );
    }

    return document.snapshots().map((snapshot) {
      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

      return <String, bool>{
        for (final String key in defaultSettings.keys)
          key: data[key] as bool? ?? true,
      };
    });
  }

  /// 更新單一通知開關
  Future<void> updateSetting({required String key, required bool value}) async {
    final DocumentReference<Map<String, dynamic>>? document = _settingDocument;

    if (document == null) {
      throw StateError('使用者尚未登入');
    }

    if (!customerToggleKeys.contains(key)) {
      throw ArgumentError('不支援的通知設定：$key');
    }

    await document.set(<String, dynamic>{
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 第一次開啟設定頁時建立預設資料
  Future<void> ensureDefaultSettings() async {
    final DocumentReference<Map<String, dynamic>>? document = _settingDocument;

    if (document == null) {
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await document
        .get();

    if (snapshot.exists) {
      return;
    }

    await document.set(<String, dynamic>{
      ...defaultSettings,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
