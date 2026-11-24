import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_service_task.dart';
import 'package:petnest_saas/core/models/shop_task_item.dart';
import 'package:petnest_saas/core/widgets/booking_care_activity.dart';
import 'package:petnest_saas/core/widgets/daily_care_medication_summary.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_panel.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_schedule.dart';

Map<String, dynamic> booking() => {
  'bookingId': 'b',
  'shopId': 's',
  'status': 'checked_in',
  'roomName': 'A01',
  'startDate': '2026-11-10',
  'pets': [
    {'petId': 'p1', 'name': '小布'},
    {'petId': 'p2', 'name': '奶茶'},
  ],
  'addons': [
    {
      'serviceId': 'play',
      'name': '專屬陪玩',
      'type': 'daily_timed',
      'selections': [
        {
          'petId': 'p1',
          'petName': '小布',
          'dates': [
            {
              'date': '2026-11-10',
              'slotIds': ['s1'],
              'slotLabels': ['09:30'],
            },
          ],
        },
        {
          'petId': 'p2',
          'petName': '奶茶',
          'dates': [
            {
              'date': '2026-11-10',
              'slotIds': ['s1'],
              'slotLabels': ['09:30'],
            },
          ],
        },
      ],
    },
  ],
  'medication': {
    'state': 'confirmed',
    'request': {
      'medicines': [
        {'id': 'm', 'type': 'oral'},
      ],
    },
    'tasks': [
      {
        'id': 'm1',
        'petId': 'p1',
        'scheduledAt': '2026-11-10T02:00:00Z',
        'medicineIds': ['m'],
        'result': 'done',
        'finished': true,
        'actualAt': '2026-11-10T02:01:00Z',
        'note': '已完成並喝水。',
      },
    ],
  },
};
void main() {
  test(
    'service IDs are independent of ordering and match the server contract',
    () {
      final b = booking();
      final tasks = BookingServiceTask.fromBooking(b);
      expect(tasks.length, 2);
      expect(
        utf8.decode(base64Url.decode(base64Url.normalize(tasks.first.id))),
        jsonEncode(['play', 'p1', '2026-11-10', 's1']),
      );
      expect(
        tasks.first.scheduledAt.toUtc(),
        DateTime.utc(2026, 11, 10, 1, 30),
      );
      b['addons'] = (b['addons'] as List).reversed.toList();
      expect(
        BookingServiceTask.fromBooking(b).map((t) => t.id),
        tasks.map((t) => t.id),
      );
    },
  );
  test(
    'records never spill to another pet/time; settled orders cannot record',
    () {
      final b = booking();
      final task = BookingServiceTask.fromBooking(b).first;
      b['careServiceRecords'] = {
        task.id: {
          'scheduledAt': task.scheduledAt.toIso8601String(),
          'result': 'skipped',
          'actualAt': '2026-11-10T01:31:00Z',
          'note': '家長取消',
        },
      };
      expect(BookingServiceTask.fromBooking(b).first.pending, false);
      expect(BookingServiceTask.fromBooking(b).last.pending, true);
      expect(BookingServiceTask.fromBooking(b).first.resultLabel, '未執行');
      b['settlementLocked'] = true;
      expect(BookingServiceTask.canRecord(b), false);
      (b['careServiceRecords'] as Map)[task.id]['scheduledAt'] =
          '2026-11-11T01:30:00Z';
      expect(BookingServiceTask.fromBooking(b).first.pending, true);
    },
  );
  test(
    'cross-midnight daycare uses the next calendar day and invalid labels are ignored',
    () {
      final tasks = BookingServiceTask.fromBooking({
        'scheduledStartAt': '2026-11-10T22:00:00+08:00',
        'addons': [
          {
            'id': 'play',
            'type': 'dailyTimedServices',
            'name': '陪玩',
            'selectedPetIds': ['p1'],
            'selectedTimeSlots': [
              {'id': 'a', 'label': '01:00'},
              {'id': 'b', 'label': '稍後'},
            ],
          },
        ],
      });
      expect(tasks.single.day, '2026-11-11');
      expect(tasks.single.scheduledAt.toUtc(), DateTime.utc(2026, 11, 10, 17));
    },
  );
  test(
    'timed service results feed the order timeline and status does not imply successful care',
    () {
      final b = booking();
      final task = BookingServiceTask.fromBooking(b).first;
      b['careServiceRecords'] = {
        task.id: {
          'scheduledAt': task.scheduledAt.toIso8601String(),
          'result': 'partial',
        },
      };
      final entries = AdminBookingScheduleData(
        shopId: 's',
        bookingId: 'b',
        booking: b,
        canEdit: true,
      ).entries(showMedication: true);
      expect(entries.where((e) => e.service != null).length, 2);
      expect(entries.first.completed, true);
      expect(entries.first.service!.result, 'partial');
    },
  );
  testWidgets(
    'without report the customer sees all care; report includes only actual records',
    (tester) async {
      final b = booking();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingCareActivity(bookingId: 'b', booking: b),
            ),
          ),
        ),
      );
      expect(find.text('專屬陪玩'), findsNWidgets(2));
      expect(find.text('小布'), findsNWidgets(3));
      expect(find.text('口服藥'), findsOneWidget);
      expect(find.text('填寫結果'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyCareMedicationSummary(booking: b, dateKey: '2026-11-10'),
          ),
        ),
      );
      expect(find.text('小布'), findsNWidgets(2));
      expect(find.text('口服藥'), findsOneWidget);
      expect(find.text('專屬陪玩'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'recorded service is shared with reports and completed orders have no execution action',
    (tester) async {
      final b = booking();
      final t = BookingServiceTask.fromBooking(b).first;
      b['careServiceRecords'] = {
        t.id: {
          'scheduledAt': t.scheduledAt.toIso8601String(),
          'actualAt': '2026-11-10T01:40:00Z',
          'result': 'partial',
          'note': '陪玩後休息，已通知家長',
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyCareMedicationSummary(
                booking: b,
                dateKey: '2026-11-10',
              ),
            ),
          ),
        ),
      );
      expect(find.text('部分完成'), findsOneWidget);
      expect(find.text('陪玩後休息，已通知家長'), findsOneWidget);
      b['status'] = 'completed';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingCareActivity(
                bookingId: 'b',
                booking: b,
                staff: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('填寫結果'), findsNothing);
      expect(find.text('未留執行紀錄'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'disabled services are hidden and the care workbench excludes booking totals',
    (tester) async {
      const snapshot = ShopTaskCenterSnapshot(
        bookingEnabled: true,
        medicationEnabled: true,
        serviceEnabled: true,
        items: [
          ShopTaskItem(
            id: 'b',
            type: ShopTaskType.booking,
            shopId: 's',
            title: '新預約',
            subtitle: '',
            statusLabel: '待確認',
            targetType: 'booking',
            targetId: 'b',
          ),
        ],
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShopTaskCenterContent(
              snapshot: snapshot,
              showViewAll: false,
              closeBeforeOpen: false,
              careOnly: true,
            ),
          ),
        ),
      );
      expect(find.text('全部 0'), findsOneWidget);
      expect(find.text('新預約'), findsNothing);
      expect(find.text('陪玩／預約服務 0'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShopTaskCenterContent(
              snapshot: ShopTaskCenterSnapshot(),
              showViewAll: false,
              closeBeforeOpen: false,
            ),
          ),
        ),
      );
      expect(find.textContaining('陪玩／預約服務'), findsNothing);
    },
  );
  testWidgets('mobile and desktop care activity fit at large text sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final font = FontLoader('CarePreview')
      ..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final width in [360.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 1100);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'CarePreview',
            colorSchemeSeed: const Color(0xFF526596),
          ),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1100),
                textScaler: TextScaler.linear(1.2),
              ),
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: const ValueKey('care-preview'),
                  child: BookingCareActivity(
                    bookingId: 'b',
                    booking: booking(),
                    staff: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CARE_PREVIEW')) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('care-preview')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/care-flow-${width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
