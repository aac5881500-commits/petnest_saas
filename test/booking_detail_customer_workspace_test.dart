import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_booked_services.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_tabs.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:petnest_saas/features/medication/medication_widgets.dart';

BookingDetailViewData example({bool legacy = false}) =>
    BookingDetailViewData.fromBooking(
      docId: 'sample',
      data: {
        'status': 'pending',
        'depositAmount': 431,
        'payAmountType': 'deposit',
        'totalPrice': 4520,
        'roomSubtotal': 2400,
        'discountCampaignName': '滿額優惠',
        'discountAmount': 280,
        if (!legacy)
          'discountExplanation': {
            'type': 'minimumAmount',
            'minimumAmount': 2500,
            'eligibleAmount': 2800,
            'baseAmount': 2800,
            'valueType': 'percent',
            'value': 10,
          },
        'pets': [
          {'petId': 'a', 'name': '小花'},
          {'petId': 'b', 'name': '小橘'},
        ],
        'addons': [
          {
            'name': '每日專屬陪玩時光',
            'type': 'daily_timed',
            'price': 50,
            'count': 2,
            'total': 100,
            'selections': [
              {
                'petId': 'a',
                'dates': [
                  {
                    'date': '2026-11-09',
                    'slotLabels': ['10:00–11:00'],
                  },
                ],
              },
              {
                'petId': 'b',
                'dates': [
                  {
                    'date': '2026-11-10',
                    'slotLabels': ['13:00–14:00'],
                  },
                ],
              },
            ],
          },
        ],
        'medicationRequest': {
          'preferences': [
            {
              'petId': 'a',
              'types': ['oral'],
              'times': ['09:30', '12:00'],
            },
          ],
        },
      },
    );

void main() {
  test('historical discount basis and amount due now stay distinct', () {
    final view = example();
    final campaign = view.feeLines.singleWhere((line) => line.isDiscount);
    expect(campaign.amount, 280);
    expect(
      campaign.subtitle,
      allOf(contains('2500'), contains('2800'), contains('10%')),
    );
    expect(view.paymentProgressSubtitle, contains('431'));
    expect(view.paymentProgressSubtitle, isNot(contains('4520')));
    expect(
      example(
        legacy: true,
      ).feeLines.singleWhere((line) => line.isDiscount).subtitle,
      contains('未保存門檻金額'),
    );
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('separate customer service and payment views at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tabs = TabController(length: 4, vsync: tester);
      addTearDown(tabs.dispose);
      final view = example();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingDetailTabs(
              controller: tabs,
              view: view,
              overview: const Text('訂單狀態摘要'),
              guests: const Text('聯絡資料'),
              services: Column(
                children: [
                  BookingDetailBookedServices(view: view),
                  BookingMedicationPanel(
                    bookingId: view.docId,
                    booking: view.raw,
                    customerDetails: true,
                  ),
                ],
              ),
              payment: const Text('付款摘要'),
            ),
          ),
        ),
      );
      expect(find.text('訂單狀態摘要').hitTestable(), findsOneWidget);
      expect(find.text('付款摘要').hitTestable(), findsNothing);
      await tester.tap(find.text('服務與用藥'));
      await tester.pumpAndSettle();
      final schedule = find.textContaining('10:00–11:00').hitTestable();
      expect(schedule, findsOneWidget);
      final services = find.byType(BookingDetailBookedServices);
      expect(
        find.descendant(of: services, matching: find.text('小花')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('小橘').hitTestable(), findsOneWidget);
      expect(find.text('2026/11/10｜13:00–14:00').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('09:30'));
      expect(find.text('09:30').hitTestable(), findsOneWidget);
      expect(find.text('12:00').hitTestable(), findsOneWidget);
      tabs.index = BookingDetailTab.payment.index;
      await tester.pumpAndSettle();
      expect(find.text('付款摘要').hitTestable(), findsOneWidget);
      expect(schedule.hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
