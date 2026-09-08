// 檔案名稱：lib/features/admin/pages/admin_daycare_list_page.dart
// 功能說明：舊「安親訂單」入口相容：導向訂單管理的安親分頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_list_page.dart';

class AdminDaycareListPage extends StatelessWidget {
  const AdminDaycareListPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return AdminBookingListPage(
      shopId: shopId,
      initialKind: BookingKind.daycare,
    );
  }
}
