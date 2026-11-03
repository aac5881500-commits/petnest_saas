import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_pet_choice.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_pet_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_layout.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_inline_calendar.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';

Widget layout(String style) => BookingArrivalLayout(
  style: style,
  shopName: 'test',
  dateSection: const Text('date-slot'),
  petsSection: const Text('pets-slot'),
  reminder: const Text('reminder-slot'),
  campaign: const SizedBox(),
  calendar: const Text('calendar-slot'),
  hasDates: true,
  petCount: 2,
  dateLabel: '11/2 → 11/5',
);
FrontCalendarPayload payload({Set<String> blocked = const {}}) =>
    FrontCalendarPayload(
      blockedDateKeys: blocked,
      blockedDateReasons: const {},
      unbookableDateKeys: const {},
      priceMap: const {},
      remainingRoomsMap: const {},
    );
void main() {
  testWidgets('guided layout switches one question at a time and returns', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: layout('minimal'))),
      ),
    );
    expect(find.text('date-slot'), findsOneWidget);
    expect(find.text('pets-slot'), findsNothing);
    await tester.tap(find.text('日期選好了，選貓咪'));
    await tester.pumpAndSettle();
    expect(find.text('date-slot'), findsNothing);
    expect(find.text('pets-slot'), findsOneWidget);
    await tester.tap(find.text('返回日期'));
    await tester.pumpAndSettle();
    expect(find.text('date-slot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pet-first order and desktop dashboard columns differ', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: layout('soft'))),
      ),
    );
    expect(
      tester.getTopLeft(find.text('pets-slot')).dy,
      lessThan(tester.getTopLeft(find.text('date-slot')).dy),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: layout('compact'))),
      ),
    );
    expect(
      tester.getTopLeft(find.text('date-slot')).dx,
      lessThan(tester.getTopLeft(find.text('本次住宿計畫')).dx),
    );
    await tester.binding.setSurfaceSize(const Size(390, 1300));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('本次住宿計畫')).dy,
      lessThan(tester.getTopLeft(find.text('date-slot')).dy),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('inline calendar blocks closed ranges and applies valid dates', (
    tester,
  ) async {
    final applied = <DateTimeRange>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingInlineCalendar(
              today: DateTime(2026, 11, 1),
              maxDays: 60,
              loadMonth: (_) async => payload(blocked: {'2026-11-04'}),
              onApply: (start, end) =>
                  applied.add(DateTimeRange(start: start, end: end)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<BookingCalendar>(find.byType(BookingCalendar))
        .onDayTap(DateTime(2026, 11, 3));
    await tester.pumpAndSettle();
    tester
        .widget<BookingCalendar>(find.byType(BookingCalendar))
        .onDayTap(DateTime(2026, 11, 6));
    await tester.pumpAndSettle();
    expect(find.text('這段住宿包含休息日或已滿日期，請重新選擇'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '套用住宿日期'))
          .onPressed,
      isNull,
    );
    tester
        .widget<BookingCalendar>(find.byType(BookingCalendar))
        .onDayTap(DateTime(2026, 11, 2));
    await tester.pumpAndSettle();
    tester
        .widget<BookingCalendar>(find.byType(BookingCalendar))
        .onDayTap(DateTime(2026, 11, 3));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('套用住宿日期'));
    await tester.tap(find.text('套用住宿日期'));
    await tester.pumpAndSettle();
    expect(applied.single.start, DateTime(2026, 11, 2));
    expect(applied.single.end, DateTime(2026, 11, 3));
  });
  testWidgets(
    'inline calendar checks cross-month availability and fails closed',
    (tester) async {
      final months = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingInlineCalendar(
                today: DateTime(2026, 11, 1),
                maxDays: 90,
                loadMonth: (month) async {
                  months.add(month.month);
                  if (month.month == 12) throw StateError('offline');
                  return payload();
                },
                onApply: (_, end) => fail('must not apply unavailable range'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<BookingCalendar>(find.byType(BookingCalendar))
          .onDayTap(DateTime(2026, 11, 29));
      await tester.pumpAndSettle();
      tester
          .widget<BookingCalendar>(find.byType(BookingCalendar))
          .onDayTap(DateTime(2026, 12, 3));
      await tester.pumpAndSettle();
      expect(months, containsAll([11, 12]));
      expect(find.text('無法確認這段日期，請重新選擇退房日再試'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '套用住宿日期'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real pet-first tiles keep selection callback and disabled state',
    (tester) async {
      var toggles = 0;
      Widget screen(bool enabled) => MaterialApp(
        home: Scaffold(
          body: BookingAppearanceScope(
            appearance: const BookingPageAppearance(style: 'soft'),
            child: BookingPetSection(
              shopId: 'test',
              selectedPetIds: const [],
              theme: HomeThemeModel.classicDefault,
              enabled: enabled,
              isLoggedIn: true,
              petsStream: Stream.value([
                {'petId': 'cat-1', 'name': '奶茶', 'species': 'cat'},
              ]),
              onPetsLoaded: (_) {},
              onTogglePet: (id, selected) {
                expect(id, 'cat-1');
                expect(selected, true);
                toggles++;
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BookingPetChoice>(find.byType(BookingPetChoice)).portrait,
        true,
      );
      await tester.tap(find.text('奶茶'));
      await tester.pumpAndSettle();
      expect(toggles, 1);
      await tester.pumpWidget(screen(false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('奶茶'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(toggles, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
