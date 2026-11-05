import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_editorial_design.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_preview.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_confirmation_preview.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_service_template_editor.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_summary_helper.dart';

void main() {
  test('suite colors and hero persist with safe legacy defaults', () {
    const a = BookingPageAppearance(
      style: 'editorial',
      serviceStyle: 'editorial',
      suiteColorMode: 'custom',
      heroImage: 'https://example.com/cat.jpg',
      looks: {
        'editorial': BookingPageLook(
          background: 0xFF123456,
          text: 0xFF273B59,
          primary: 0xFF3878AC,
          fontWeight: 700,
          font: 'NotoSansTC',
        ),
      },
    );
    final saved = BookingPageAppearance.fromShop({
      'homeAppearance': {'bookingPage': a.toMap()},
    });
    expect(saved.suiteColorMode, 'custom');
    expect(saved.heroImage, a.heroImage);
    expect(saved.look.primary, 0xFF3878AC);
    expect(saved.look.font, 'NotoSansTC');
    expect(saved.look.background, 0xFF123456);
    expect(saved.look.fontWeight, 700);
    expect(BookingPageAppearance.fromShop({}).heroImage, '');
    expect(
      BookingPageAppearance.fromShop({
        'homeAppearance': {
          'bookingPage': {'heroImage': 'javascript:alert(1)'},
        },
      }).heroImage,
      '',
    );
  });
  testWidgets('all editorial controls use shared frontend or custom colors', (
    tester,
  ) async {
    final front = HomeThemeModel.modernDefault.copyWith(
      backgroundColorValue: 0xFFF0F6FC,
      textColorValue: 0xFF273B59,
      primaryColorValue: 0xFF3878AC,
    );
    for (final mode in ['frontend', 'custom']) {
      final a = BookingPageAppearance(
        style: 'editorial',
        serviceStyle: 'editorial',
        suiteColorMode: mode,
        looks: const {
          'editorial': BookingPageLook(
            background: 0xFFF0F6FC,
            text: 0xFF273B59,
            primary: 0xFF3878AC,
          ),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BookingAppearanceScope(
            appearance: a,
            frontendTheme: front,
            child: Scaffold(
              body: Column(
                children: [
                  BookingEditorial.brand(shopName: '本店測試旅館'),
                  const BookingEditorialProgress(step: 3),
                  BookingEditorial.button('下一步', () {}),
                  BookingEditorial.heading('費用明細'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(
        button.style!.backgroundColor!.resolve({}),
        const Color(0xFF3878AC),
      );
      expect(
        tester.widget<Text>(find.text('費用明細')).style!.color,
        const Color(0xFF273B59),
      );
      expect(find.text('本店測試旅館'), findsOneWidget);
      expect(find.text('PetNest'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'settings apply one suite and share color mode in all three previews',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingAppearanceEditor(
              shopId: 'test',
              shopStream: Stream.value({'name': '本店測試旅館'}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final suite = find.byKey(const ValueKey('booking-editorial-suite'));
      await tester.ensureVisible(suite);
      await tester.tap(suite);
      await tester.pumpAndSettle();
      final mode = find.byKey(const ValueKey('suite-color-frontend'));
      await tester.ensureVisible(mode);
      await tester.tap(mode);
      await tester.pumpAndSettle();
      final a = tester
          .widget<BookingArrivalPreview>(
            find.byType(BookingArrivalPreview, skipOffstage: false),
          )
          .appearance;
      final b = tester
          .widget<BookingServicePreview>(
            find.byType(BookingServicePreview, skipOffstage: false),
          )
          .appearance;
      final c = tester
          .widget<BookingConfirmationPreview>(
            find.byType(BookingConfirmationPreview, skipOffstage: false),
          )
          .appearance;
      expect(a.toMap(), b.toMap());
      expect(b.toMap(), c.toMap());
      expect(c.suiteColorMode, 'frontend');
      expect(find.widgetWithText(ChoiceChip, '房型與服務'), findsNothing);
      expect(
        find.byKey(const ValueKey('booking-service-template-premium')),
        findsNothing,
      );
      final preview = find.widgetWithText(ChoiceChip, '即時預覽');
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      final third = find.byKey(const ValueKey('suite-preview-3'));
      await tester.ensureVisible(third);
      await tester.tap(third);
      await tester.pumpAndSettle();
      expect(find.text('確認住宿安排'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'confirmation shows real service totals and every discount, hides empty custom service',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingAppearanceScope(
              appearance: const BookingPageAppearance(
                style: 'editorial',
                serviceStyle: 'editorial',
              ),
              child: SingleChildScrollView(
                child: BookingSummaryHelper.buildSummary(
                  startDateText: '2026/11/05',
                  endDateText: '2026/11/07',
                  nights: 2,
                  selectedPetIds: const ['a', 'b'],
                  pets: const [
                    {'petId': 'a', 'name': '奶茶'},
                    {'petId': 'b', 'name': '芝麻'},
                  ],
                  selectedRoomType: const {
                    'name': '標準房',
                    'price': 500,
                    'extraPrice': 100,
                  },
                  totalPrice: 1330,
                  originalTotal: 1500,
                  discountAmount: 100,
                  couponDiscountAmount: 50,
                  pointAmount: 20,
                  specialDateSurchargeAmount: 100,
                  selectedTimeAddon: const {'label': '正常入住', 'price': 0},
                  selectedValueServices: const [
                    {'name': '點心', 'price': 100},
                  ],
                  selectedCustomServices: const {'不應顯示': []},
                  selectedDailyTimedServices: const {
                    'play': {
                      'a': {
                        '2026-11-05': ['am', 'pm'],
                      },
                    },
                  },
                  addonData: const {
                    'dailyTimedServices': [
                      {'id': 'play', 'name': '陪玩', 'price': 50},
                    ],
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NT\$ 1330'), findsOneWidget);
      expect(find.text('陪玩（2 次）'), findsOneWidget);
      expect(find.text('不應顯示'), findsNothing);
      for (final text in [
        'NT\$ -100',
        'NT\$ -50',
        'NT\$ -20',
        'NT\$ 1200',
        'NT\$ 200',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
