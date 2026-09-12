// 檔案名稱：lib/features/admin/widgets/admin_shop_identity_debug_card.dart
// 功能說明：僅 kDebugMode debugPrint 店主身分對照，不進入畫面、不同步權限。

import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/models/shop_staff_identity_snapshot.dart';
import 'package:petnest_saas/core/services/shop_member_permission_service.dart';

class AdminShopIdentityLog {
  AdminShopIdentityLog._();

  static final Set<String> _logged = <String>{};

  static void logOnce({
    required String bookingId,
    required String shopId,
    required String bookingShopId,
    required bool settlementLocked,
  }) {
    if (!kDebugMode) {
      return;
    }
    final String key = '$bookingId|$shopId|$bookingShopId|$settlementLocked';
    if (!_logged.add(key)) {
      return;
    }
    ShopMemberPermissionService.instance
        .inspectShopIdentity(
          shopId: shopId,
          bookingShopId: bookingShopId,
          settlementLocked: settlementLocked,
        )
        .then((ShopStaffIdentitySnapshot snapshot) {
          debugPrint(ShopOwnerIdentity.debugText(snapshot));
        })
        .catchError((Object error) {
          debugPrint('SHOP_IDENTITY inspect failed: $error');
        });
  }
}
