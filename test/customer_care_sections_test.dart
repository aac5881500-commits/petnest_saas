import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/widgets/booking_care_activity.dart';
import 'package:petnest_saas/features/medication/medication_widgets.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_booked_services.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'booking_care_flow_test.dart' as fixture;
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';

void main() {
  testWidgets('scheduled items and care explanations remain visible', (
    tester,
  ) async {
    final data = fixture.booking();
    (data['medication'] as Map)['tasks'][0]['note'] = '已協助喝水，晚間持續觀察';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingCareActivity(bookingId: 'b', booking: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已協助喝水，晚間持續觀察'), findsOneWidget);
    expect(find.text('店家照護說明'), findsOneWidget);
    expect(find.text('已到時間 · 待填寫'), findsNWidgets(2));
    expect(find.textContaining('1 / 3 項已記錄'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'all stay dates and pet filters remain available without reports',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = fixture.booking()..['endDate'] = '2026-11-13';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingCareActivity(
                bookingId: 'b',
                booking: data,
                recordedOnly: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('11/12'), findsOneWidget);
      expect(find.textContaining('11/13'), findsOneWidget);
      expect(find.text('全部寵物'), findsOneWidget);
      await tester.tap(find.textContaining('11/12'));
      await tester.pumpAndSettle();
      expect(find.text('這一天尚無此類照護紀錄。'), findsOneWidget);
      await tester.tap(find.textContaining('11/10'));
      await tester.tap(find.text('奶茶'));
      await tester.pumpAndSettle();
      expect(find.text('這一天尚無此類照護紀錄。'), findsOneWidget);
      await tester.tap(find.text('小布'));
      await tester.pumpAndSettle();
      expect(find.text('成功'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('expanded details do not read scroll offsets as booleans', (
    tester,
  ) async {
    final bucket = PageStorageBucket();
    final booking = fixture.booking();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: Builder(
              key: const PageStorageKey('customer-services-scroll'),
              builder: (context) {
                bucket.writeState(context, 0.0);
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      BookingMedicationPanel(
                        bookingId: 'b',
                        booking: booking,
                        customerDetails: true,
                      ),
                      BookingDetailBookedServices(
                        view: BookingDetailViewData.fromBooking(
                          docId: 'b',
                          data: booking,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('藥品與使用指示'));
    await tester.tap(find.text('藥品與使用指示'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('專屬陪玩'));
    await tester.tap(find.text('專屬陪玩'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'customer care categories show only selected content at mobile width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CustomerCareSections(
                reports: Text('測試回報內容'),
                medication: Text('測試藥品內容'),
                addons: Text('測試加購內容'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('測試回報內容'), findsOneWidget);
      expect(find.text('測試藥品內容'), findsNothing);
      await tester.tap(find.text('用藥安排'));
      await tester.pump();
      expect(find.text('測試藥品內容'), findsOneWidget);
      expect(find.text('測試回報內容'), findsNothing);
      await tester.tap(find.text('加購內容'));
      await tester.pump();
      expect(find.text('測試加購內容'), findsOneWidget);
      expect(find.text('測試藥品內容'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
