import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/features/booking/models/pre_arrival_shortcut.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'Taipei calendar countdown and actual check-in govern the reminder separately',
    () {
      final arrival = DateTime.utc(2026, 11, 10, 7);
      expect(
        PreArrivalShortcut.countdown(arrival, DateTime.utc(2026, 11, 7, 15)),
        '距離入住還有 3 天',
      );
      expect(
        PreArrivalShortcut.countdown(arrival, DateTime.utc(2026, 11, 9, 16)),
        '今天入住',
      );
      BookingDetailViewData view(Map<String, dynamic> extra) =>
          BookingDetailViewData.fromBooking(
            docId: 'booking',
            data: {
              'shopId': 'shop',
              'status': 'confirmed',
              'startDate': arrival.toIso8601String(),
              ...extra,
            },
          );
      expect(PreArrivalShortcut.eligible(view({})), isTrue);
      expect(
        PreArrivalShortcut.schedule(
          view({'scheduledStartAt': arrival.toIso8601String()}),
        ),
        '11/10（二） 15:00 入住',
      );
      expect(
        PreArrivalShortcut.schedule(
          view({
            'addons': [
              {'type': 'time', 'name': '09:00 - 09:59 入住'},
            ],
          }),
        ),
        '11/10（二） 09:00–09:59 入住',
      );
      for (final status in [
        'checked_in',
        'checked_out',
        'cancelled',
        'no_show',
        'completed',
      ]) {
        expect(PreArrivalShortcut.eligible(view({'status': status})), isFalse);
      }
      expect(
        PreArrivalShortcut.eligible(
          view({'checkInAt': arrival.toIso8601String()}),
        ),
        isFalse,
      );
    },
  );

  for (final accepted in [true, false]) {
    testWidgets('return asks once when customer chooses $accepted', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      const shortcut = PreArrivalShortcut('user', 'shop', 'booking');
      final guide = PreArrivalGuideModel(
        shopId: '',
        serviceType: 'accommodation',
        enabled: true,
        style: accepted ? 'packing' : 'classic',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PreArrivalGuidePage(
                      guide: guide,
                      shortcut: shortcut,
                      progressScope: shortcut.scope,
                    ),
                  ),
                ),
                child: const Text('打開清單'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打開清單'));
      await tester.pumpAndSettle();
      if (accepted) {
        await tester.tap(find.text('返回訂單'));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.text('下次更快找到準備清單'), findsOneWidget);
      await tester.tap(find.text(accepted ? '加到店家首頁' : '不用了，返回訂單'));
      await tester.pumpAndSettle();
      expect(find.text('打開清單'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(shortcut.choice(prefs), accepted);
      expect(
        const PreArrivalShortcut('other', 'shop', 'booking').choice(prefs),
        isNull,
      );
      await tester.tap(find.text('打開清單'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('下次更快找到準備清單'), findsNothing);
      expect(find.text('打開清單'), findsOneWidget);
    });
  }
}
