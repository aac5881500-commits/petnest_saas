// 檔案名稱：test/booking_pet_section_layout_test.dart
// 功能說明：確認單一寵物 StreamBuilder 不會把同欄的日期選擇卡一起弄丟。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_date_card.dart';

void main() {
  testWidgets('單一 StreamBuilder 時日期卡與寵物區都可見', (WidgetTester tester) async {
    final Stream<List<String>> stream = Stream<List<String>>.value(
      const <String>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              DaycareDateCard(date: null, onTap: () {}),
              StreamBuilder<List<String>>(
                stream: stream,
                builder: (_, __) => const Text('pets-ok'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('選擇日期'), findsOneWidget);
    expect(find.text('pets-ok'), findsOneWidget);
  });
}
