// 檔案名稱：test/daycare_date_card_test.dart
// 功能說明：安親日期卡片的單元測試（未選日期仍顯示選擇日期按鈕）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_date_card.dart';

void main() {
  testWidgets('未選日期仍顯示選擇日期按鈕', (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DaycareDateCard(
            date: null,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('選擇日期'), findsOneWidget);
    expect(find.text('尚未選擇日期'), findsOneWidget);
    await tester.tap(find.text('選擇日期'));
    expect(tapped, isTrue);
  });
}
