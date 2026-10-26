import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/appearance_category_bar.dart';

void main() {
  for (final double width in <double>[320, 390, 500]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('mobile categories visible and tappable at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int selected = AppearanceCategories.brand;
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
          builder: (context, setState) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(alignment: Alignment.topCenter, child: AppearanceCategoryMobileNav(
                selected: selected,
                onSelected: (value) => setState(() => selected = value),
              )),
            ),
          ),
        ))));
        for (final item in AppearanceCategories.all) {
          final finder = find.byKey(ValueKey<String>('appearance-mobile-category-${item.id}'));
          expect(finder.hitTestable(), findsOneWidget);
          expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
          await tester.tap(finder);
          await tester.pump();
          expect(selected, item.id);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
