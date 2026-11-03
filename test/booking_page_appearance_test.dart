import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';

void main() {
  test('legacy and malformed settings retain defaults', () {
    for (final shop in <Map<String, dynamic>>[
      {},
      {'homeAppearance': false},
      {
        'homeAppearance': {'bookingPage': 'bad'},
      },
      {
        'homeAppearance': {
          'bookingPage': {'reminderTitle': '', 'compact': 'true'},
        },
      },
    ]) {
      final value = BookingPageAppearance.fromShop(shop);
      expect(value.reminderTitle, '預約前提醒');
      expect(value.compact, false);
    }
  });
  testWidgets(
    'mobile preview and leave confirmation preserve or discard draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey<BookingAppearanceEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingAppearanceEditor(
              key: key,
              shopId: 'test',
              shopStream: Stream.value({}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '入住小提醒');
      await tester.pump();
      expect(key.currentState!.hasChanges, true);
      var leave = key.currentState!.confirmLeave();
      await tester.pumpAndSettle();
      await tester.tap(find.text('繼續編輯'));
      await tester.pumpAndSettle();
      expect(await leave, false);
      expect(key.currentState!.hasChanges, true);
      leave = key.currentState!.confirmLeave();
      await tester.pumpAndSettle();
      await tester.tap(find.text('放棄變更並離開'));
      await tester.pumpAndSettle();
      expect(await leave, true);
      expect(key.currentState!.hasChanges, false);
      expect(tester.takeException(), isNull);
    },
  );
}
