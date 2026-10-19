// 檔案名稱：lib/features/shop/shop_admin_welcome.dart
// 功能說明：判斷新店家首次後台歡迎。不改店家文件，狀態寫在店主自己的 users 文件。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';

enum ShopAdminWelcomeChoice { started, later }

class ShopAdminWelcome {
  ShopAdminWelcome._();

  /// 這個時間之前建立的店家視為既有店家，不顯示首次歡迎。
  static final DateTime introducedAt = DateTime.utc(2026, 10, 18, 14);

  static DateTime? createdAtOf(Map<String, dynamic> shop) {
    final value = shop['createdAt'];
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    return null;
  }

  static bool isNewShop(Map<String, dynamic> shop) {
    final createdAt = createdAtOf(shop);
    if (createdAt == null) return false;
    return !createdAt.isBefore(introducedAt);
  }

  static bool alreadyHandled(Map<String, dynamic>? userData, String shopId) {
    final raw = userData?['shopAdminWelcome'];
    if (raw is! Map) return false;
    final entry = raw[shopId];
    if (entry is! Map) return false;
    final status = entry['status']?.toString();
    return status == 'started' || status == 'later';
  }

  static bool shouldShow({
    required Map<String, dynamic> shop,
    required String shopId,
    required String? uid,
    required String? role,
    required bool userLoaded,
    required Map<String, dynamic>? userData,
  }) {
    if (!userLoaded || uid == null || uid.isEmpty) return false;
    if (role != ShopRoles.owner) return false;
    if ((shop['ownerUid'] ?? '').toString() != uid) return false;
    if (!isNewShop(shop)) return false;
    return !alreadyHandled(userData, shopId);
  }

  static bool shouldRemind({
    required Map<String, dynamic> shop,
    required bool profileComplete,
  }) {
    return !profileComplete && isNewShop(shop);
  }

  static Future<void> remember({
    required String uid,
    required String shopId,
    required ShopAdminWelcomeChoice choice,
  }) {
    return FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'shopAdminWelcome': {
          shopId: {
            'status': choice == ShopAdminWelcomeChoice.started
                ? 'started'
                : 'later',
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
      },
      SetOptions(
        mergeFields: [
          FieldPath(['shopAdminWelcome', shopId]),
        ],
      ),
    );
  }
}
