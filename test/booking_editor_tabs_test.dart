import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_editor_tabs.dart';

void main() {
  for (final width in [320.0, 500.0, 1200.0]) {
    for (final numbered in [false, true]) {
      testWidgets(
        'tabs $width numbered=$numbered remain tappable with large text',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = 1;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, update) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2)),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: BookingEditorTabs(
                        selected: selected,
                        numbered: numbered,
                        labels: numbered
                            ? const {1: '日期與貓咪', 2: '房型與服務', 3: '費用確認'}
                            : const {1: '模板與配色', 2: '日期選擇器', 3: '頁面預覽'},
                        onSelected: (v) => update(() => selected = v),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          for (var i = 1; i <= 3; i++) {
            final tab = find.byKey(
              ValueKey('booking-${numbered ? 'step' : 'workspace'}-$i'),
            );
            expect(tester.getSize(tab).height, greaterThanOrEqualTo(48));
            await tester.tap(tab);
            await tester.pump();
            expect(selected, i);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
