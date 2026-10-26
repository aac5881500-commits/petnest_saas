import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_template_picker.dart';

void main() {
  for (final kind in <PointerDeviceKind>[PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('template strip drags both ways with $kind without choosing a template', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int selections = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: StoreBannerTemplatePicker(
        scope: PetNestBannerScope.home, onSelected: (_) => selections++))));
      final strip = find.byKey(const ValueKey<String>('poster-template-strip'));
      final scrollable = find.descendant(of: strip, matching: find.byType(Scrollable));
      final position = tester.state<ScrollableState>(scrollable).position;
      await tester.drag(strip, const Offset(-260, 0), kind: kind);
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      final after = position.pixels;
      await tester.drag(strip, const Offset(180, 0), kind: kind);
      await tester.pumpAndSettle();
      expect(position.pixels, lessThan(after));
      expect(selections, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
