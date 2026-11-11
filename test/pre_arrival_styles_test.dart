import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_style_picker.dart';

PreArrivalGuideModel sample() {
  var guide = const PreArrivalGuideModel(
    shopId: '',
    serviceType: 'accommodation',
  );
  for (final item in preArrivalCatalog) {
    guide = togglePreArrivalCatalog(guide, item, true);
  }
  return guide;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'skins serialize and preserve one edited shared list, catalog toggles are idempotent',
    () {
      var guide = sample();
      final food = guide.blocks.indexWhere((b) => b.id == 'catalog-food');
      final edited = [...guide.blocks];
      edited[food] = edited[food].copyWith(text: '本店特別提醒，請分裝');
      guide = guide.copyWith(blocks: edited);
      for (final style in ['packing', 'timeline', 'minimal']) {
        guide = guide.copyWith(style: style);
        guide = PreArrivalGuideModel.fromMap(
          shopId: '',
          serviceType: 'accommodation',
          data: guide.toMap(updatedBy: 'owner'),
        );
        expect(guide.style, style);
        expect(guide.blocks[food].text, '本店特別提醒，請分裝');
        expect(
          togglePreArrivalCatalog(
            guide,
            preArrivalCatalog.first,
            true,
          ).blocks.length,
          guide.blocks.length,
        );
      }
      final removed = togglePreArrivalCatalog(
        guide,
        preArrivalCatalog.first,
        false,
      );
      expect(removed.blocks.any((b) => b.id == 'catalog-food'), isFalse);
      expect(removed.blocks.any((b) => b.id == 'catalog-carrier'), isTrue);
      expect(
        PreArrivalGuideModel.fromMap(
          shopId: '',
          serviceType: 'daycare',
          data: {},
        ).style,
        'classic',
      );
      expect(guide.copyWith(style: 'future').style, 'classic');
      expect(
        guide.blocks
            .where(
              (b) => [
                'catalog-litter',
                'catalog-bowl',
                'catalog-time',
                'catalog-contact',
              ].contains(b.id),
            )
            .every((b) => b.type == 'text'),
        isTrue,
      );
    },
  );
  for (final style in ['packing', 'timeline', 'minimal']) {
    for (final width in [320.0, 1100.0]) {
      testWidgets('$style fits $width and keeps progress across style changes', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Future<void> open(String selected) async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.8 : 1),
                ),
                child: child!,
              ),
              home: PreArrivalGuidePage(
                guide: sample().copyWith(style: selected),
                progressScope: 'user/shop/booking',
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await open(style);
        expect(tester.takeException(), isNull);
        final food = find.byKey(
          const ValueKey('preparation-check-catalog-food'),
        );
        await tester.ensureVisible(food);
        await tester.pumpAndSettle();
        await tester.tap(food);
        await tester.pumpAndSettle();
        await open(style == 'packing' ? 'minimal' : 'packing');
        expect(
          find.text(
            '準備進度 1 / ${sample().visibleBlocks.where((b) => b.type == PreArrivalGuideBlockType.checklist).length}',
          ),
          findsOneWidget,
        );
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('owner skin and catalog controls work on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var guide = const PreArrivalGuideModel(shopId: '', serviceType: 'daycare');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ListView(
              children: [
                PreArrivalStylePicker(
                  value: guide.style,
                  onChanged: (style) =>
                      setState(() => guide = guide.copyWith(style: style)),
                ),
                PreArrivalCatalogPicker(
                  guide: guide,
                  onChanged: (updated) => setState(() => guide = updated),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('guide-style-timeline')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('更多選擇'));
    await tester.tap(find.text('更多選擇'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('catalog-picker-food')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-picker-food')));
    await tester.pumpAndSettle();
    expect(guide.style, 'timeline');
    expect(guide.blocks.any((b) => b.id == 'catalog-food'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
