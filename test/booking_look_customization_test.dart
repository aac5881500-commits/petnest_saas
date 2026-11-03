import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_preview.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_layout.dart';

void main() {
  test('per-layout looks persist and shaped templates stay protected', () {
    const appearance = BookingPageAppearance(
      style: 'soft',
      looks: {
        'soft': BookingPageLook(
          background: 0xFFF0F6FC,
          text: 0xFF273B59,
          primary: 0xFF3878AC,
          font: 'jfOpenHuninn',
        ),
        'house': BookingPageLook(text: 0xFF273B59),
      },
    );
    final loaded = BookingPageAppearance.fromShop({
      'homeAppearance': {'bookingPage': appearance.toMap()},
    });
    expect(loaded.look.font, 'jfOpenHuninn');
    expect(
      BookingArrivalLayout.themeFor(
        'soft',
        appearance: loaded,
      ).backgroundColorValue,
      0xFFF0F6FC,
    );
    final locked = BookingPageAppearance(style: 'house', looks: loaded.looks);
    expect(locked.lookEditable, false);
    expect(locked.look.text, null);
    expect(
      BookingPageLook.fromMap({
        'font': 'bad',
        'background': 'red',
        'text': 0xFFFFFFFF,
      }).toMap(),
      {'font': ''},
    );
  });
  testWidgets('changing colors keeps separate drafts when switching layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingAppearanceEditor(
            shopId: 'test',
            shopStream: Stream.value({
              'homeAppearance': {
                'bookingPage': const BookingPageAppearance(
                  style: 'soft',
                ).toMap(),
              },
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final color = find.byType(DropdownButtonFormField<int>).first;
    tester.widget<DropdownButtonFormField<int>>(color).onChanged!(0xFFF0F6FC);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BookingArrivalPreview>(find.byType(BookingArrivalPreview))
          .appearance
          .look
          .background,
      0xFFF0F6FC,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('booking-style-original')),
    );
    await tester.tap(find.byKey(const ValueKey('booking-style-original')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BookingArrivalPreview>(find.byType(BookingArrivalPreview))
          .appearance
          .look
          .background,
      null,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('booking-style-soft')),
    );
    await tester.tap(find.byKey(const ValueKey('booking-style-soft')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BookingArrivalPreview>(find.byType(BookingArrivalPreview))
          .appearance
          .look
          .background,
      0xFFF0F6FC,
    );
    await tester.ensureVisible(find.text('還原本版型配色與字型'));
    await tester.tap(find.text('還原本版型配色與字型'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BookingArrivalPreview>(find.byType(BookingArrivalPreview))
          .appearance
          .look
          .background,
      null,
    );
    expect(tester.takeException(), isNull);
  });
}
