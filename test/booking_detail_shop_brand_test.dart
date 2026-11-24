import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_shop_brand.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';

void main() {
  testWidgets(
    'brand follows each booking shop without retaining previous shop',
    (tester) async {
      final a = StreamController<Map<String, dynamic>?>();
      final b = StreamController<Map<String, dynamic>?>();
      addTearDown(a.close);
      addTearDown(b.close);
      Widget screen(String id, String name) => MaterialApp(
        home: BookingDetailMilkTeaScope(
          child: Scaffold(
            body: BookingDetailShopBrand(
              booking: {'shopId': id, 'shopName': name},
              shopStream: (id) => id == 'a' ? a.stream : b.stream,
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen('a', '第一間旅館'));
      a.add({'name': '陽光貓咪旅店'});
      await tester.pumpAndSettle();
      expect(find.text('陽光貓咪旅店'), findsOneWidget);
      await tester.pumpWidget(screen('b', '第二間旅館'));
      expect(find.text('陽光貓咪旅店'), findsNothing);
      expect(find.text('第二間旅館'), findsOneWidget);
      b.add({'name': '森林貓咪旅店'});
      await tester.pumpAndSettle();
      expect(find.text('森林貓咪旅店'), findsOneWidget);
      expect(find.text('陽光貓咪旅店'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('long shop name and missing logo fit on narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: BookingDetailMilkTeaScope(
          child: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: const BookingDetailBrandHeader(
                name: '森林裡的陽光貓咪旅館竹北分店與住宿服務中心',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
