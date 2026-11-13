import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/room/widgets/daily_care_pet_reports.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_medication_fees.dart';
import 'package:petnest_saas/features/medication/medication_task_page.dart';

class _RouteObserver extends NavigatorObserver {
  MaterialPageRoute<void>? opened;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && route is MaterialPageRoute<void>) opened = route;
  }
}

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('individual drafts and publication at width $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final calls = <Map<String, dynamic>>[];
      final drafts = <String, Map<String, dynamic>>{};
      Future<Map<String, dynamic>> request(Map<String, dynamic> action) async {
        calls.add(Map.of(action));
        switch (action['mode']) {
          case 'read':
            return {
              'pets': [{'id': 'a', 'name': '栗子'}, {'id': 'b', 'name': '麻糬'}],
              'drafts': drafts,
              'writable': true,
            };
          case 'draft':
            drafts[action['petId'] as String] = {
              'revision': 1, 'values': Map.of(action['values'] as Map),
            };
            return {'revision': 1};
          default:
            return {'published': true};
        }
      }

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: DailyCarePetReports(request: request))));
      await tester.pumpAndSettle();
      final appetite = find.widgetWithText(TextFormField, '飲食');
      await tester.enterText(appetite, '栗子正常吃完');
      await tester.tap(find.text('儲存草稿'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('麻糬 · 待填'));
      await tester.pumpAndSettle();
      expect(find.text('栗子正常吃完'), findsNothing);
      await tester.enterText(appetite, '麻糬少吃');
      await tester.tap(find.text('儲存草稿'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('栗子 · 草稿'));
      await tester.pumpAndSettle();
      expect(find.text('栗子正常吃完'), findsOneWidget);
      await tester.tap(find.text('發送這隻貓的回報'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認發送'));
      await tester.pumpAndSettle();
      expect(calls.last['mode'], 'publish');
      expect(calls.last['petId'], 'a');
      expect(calls.last['revision'], 1);
      expect(calls.last['values'], {'appetite': '栗子正常吃完'});
      expect(find.text('麻糬 · 草稿'), findsOneWidget);
      expect(find.text('栗子 · 已發送'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('billing opens the selected medication at width $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final observer = _RouteObserver();
      final booking = <String, dynamic>{
        'status': 'checked_in',
        'pets': [{'petId': 'p', 'name': '栗子'}],
        'medication': {
          'state': 'confirmed',
          'request': {'medicines': [{'id': 'm', 'type': 'oral'}]},
          'tasks': [
            {'id': 'dose', 'petId': 'p', 'medicineIds': ['m'], 'scheduledAt': '2026-11-12T04:00:00Z', 'result': 'pending'},
          ],
        },
      };
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(body: AdminBookingMedicationFees(
          booking: booking, inFinance: true, canEdit: true, shopId: 's', bookingId: 'b',
        )),
      ));
      expect(find.text('待補登用藥 · 1 筆'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('2026-11-12  12:00'));
      final route = observer.opened!;
      final page = route.builder(tester.element(find.byType(AdminBookingMedicationFees))) as MedicationTaskPage;
      expect(page.taskId, 'dose');
      expect(page.bookingId, 'b');
      route.navigator!.pop();
    });
  }
}
