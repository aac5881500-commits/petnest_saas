import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/models/store_banner_templates.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_template_picker.dart';

void main() {
  for (final width in <double>[320, 500]) {
    for (final scale in <double>[1, 2]) {
      testWidgets('visual template picker fits $width / $scale and all templates can be selected', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? selected;
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
          home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: StoreBannerTemplatePicker(
            scope: PetNestBannerScope.home, onSelected: (value) => selected = value))),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey<String>('poster-template-leftCopy')));
        expect(selected, StoreBannerTemplates.leftCopy);
        await tester.tap(find.text('查看全部'));
        await tester.pumpAndSettle();
        expect(find.text('選擇海報構圖'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final last = find.byKey(const ValueKey<String>('poster-template-promo'));
        await tester.scrollUntilVisible(last, 180, scrollable: find.descendant(of: find.byType(GridView), matching: find.byType(Scrollable)));
        await tester.pumpAndSettle();
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(selected, StoreBannerTemplates.promo);
        expect(find.text('選擇海報構圖'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('centered composition balances the actual content block and keeps readable subtitle', () {
    final banner = StoreBannerTemplates.apply(const StoreBannerModel(id: 'balance'), StoreBannerTemplates.centerCopy);
    final title = banner.textElements.first;
    final sub = banner.textElements.last;
    final end = banner.ctaPositionY * 900 + StoreBannerCtaSizes.box(banner.ctaSize).occupiedHeight;
    expect(((title.positionY * 900 + end) / 2 - 450).abs(), lessThan(2));
    expect(sub.posterFontPx, greaterThanOrEqualTo(48));
    expect(title.posterFontPx / sub.posterFontPx, lessThan(2.1));
  });
}
