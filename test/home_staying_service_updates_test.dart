import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_staying_daily_care_section.dart';
import 'booking_care_flow_test.dart' as fixture;

void main() {
  testWidgets('checkout removes the customer home service updates', (
    tester,
  ) async {
    for (final patch in [
      {'status': 'checked_out'},
      {'status': 'completed'},
      {'status': 'checked_in', 'checkOutAt': '2026-11-10T10:00:00Z'},
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StayingServiceUpdates(
              booking: {...fixture.booking(), ...patch},
              theme: HomeThemeModel.modernDefault,
              onOpen: () {},
            ),
          ),
        ),
      );
      expect(find.text('餵藥與用藥'), findsNothing);
      expect(find.text('專屬加購'), findsNothing);
    }
  });

  testWidgets('only booked categories appear and open the order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = 0;
    Future<void> show(Map<String, dynamic> data) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StayingServiceUpdates(
              booking: data,
              theme: HomeThemeModel.modernDefault,
              today: DateTime(2026, 11, 10),
              onOpen: () => opened++,
            ),
          ),
        ),
      ),
    );
    final data = fixture.booking();
    await show(data);
    expect(find.text('餵藥與用藥'), findsOneWidget);
    expect(find.text('專屬加購'), findsOneWidget);
    expect(find.textContaining('今日 1／1 次已記錄'), findsOneWidget);
    expect(find.textContaining('今日 0／2 次已記錄'), findsOneWidget);
    await tester.tap(find.text('專屬加購'));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
    data.remove('medication');
    await show(data);
    expect(find.text('餵藥與用藥'), findsNothing);
    expect(find.text('專屬加購'), findsOneWidget);
    data.remove('addons');
    await show(data);
    expect(find.text('專屬加購'), findsNothing);
  });

  testWidgets('unconfirmed medication stays hidden', (tester) async {
    final data = fixture.booking()..remove('addons');
    (data['medication'] as Map)['state'] = 'pending_customer';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StayingServiceUpdates(
            booking: data,
            theme: HomeThemeModel.modernDefault,
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.text('餵藥與用藥'), findsNothing);
  });
}
