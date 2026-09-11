// 檔案名稱：lib/features/admin/widgets/admin_daycare_order_list.dart
// 功能說明：安親訂單列表：預設待確認，Firestore cursor 真分頁。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/features/admin/widgets/admin_paged_booking_list.dart';

class AdminDaycareOrderList extends StatelessWidget {
  const AdminDaycareOrderList({
    super.key,
    required this.shopId,
    this.showCreateButton = false,
  });

  final String shopId;
  final bool showCreateButton;

  @override
  Widget build(BuildContext context) {
    return AdminPagedBookingList(
      shopId: shopId,
      kind: BookingKind.daycare,
      initialFilter: 'pending',
      showCreateButton: showCreateButton,
    );
  }
}
