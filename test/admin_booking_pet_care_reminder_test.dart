// 檔案名稱：test/admin_booking_pet_care_reminder_test.dart
// 功能說明：有寵物的訂單固定顯示照護提醒卡

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_care_reminder.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_strip.dart';

void main() {
  testWidgets('只要有寵物就顯示固定照護提醒卡', (WidgetTester tester) async {
    await tester.pumpWidget(
      ShopFrontendThemeInherited(
        theme: ShopFrontendTheme.fallback,
        child: const MaterialApp(
          home: Scaffold(
            body: AdminBookingPetStrip(
              pets: <Map<String, dynamic>>[
                <String, dynamic>{'name': '咪', 'petId': 'p1'},
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('寵物照護資料提醒'), findsOneWidget);
    expect(
      find.text('請點選上方寵物卡，查看寵物基本資料、安全資訊與店家照護資料。'),
      findsOneWidget,
    );
    expect(find.byType(AdminBookingPetCareReminderCard), findsOneWidget);
  });
}
