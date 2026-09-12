// 檔案名稱：lib/features/admin/widgets/admin_booking_pet_care_reminder.dart
// 功能說明：寵物資訊區下方的照護表單提醒卡，重用訂單頁已載入的表單資料。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_pet_care_form_loader.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_care_scope.dart';

class AdminBookingPetCareReminderCard extends StatelessWidget {
  const AdminBookingPetCareReminderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminBookingPetCareScope? scope = AdminBookingPetCareScope.maybeOf(
      context,
    );
    if (scope == null || scope.loading || scope.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<BookingPetCareFormItem> items = scope.items;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AdminBookingDetailCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '⚠ 寵物照護資料提醒',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text('本訂單有 ${items.length} 隻寵物已填寫照護資料，請於照護前查看。'),
            const SizedBox(height: 8),
            for (final BookingPetCareFormItem item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('${item.name}：已填 ${item.filledCount} 題'),
              ),
          ],
        ),
      ),
    );
  }
}
