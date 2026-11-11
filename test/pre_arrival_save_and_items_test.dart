import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/models/pre_arrival_appearance.dart';
import 'package:petnest_saas/features/booking/models/pre_arrival_item_presentation.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_style_picker.dart';

void main() {
  test('every catalog option has a distinct heading and semantic icon', () {
    for (final item in preArrivalCatalog) {
      final block = PreArrivalGuideBlock(
        id: 'catalog-${item.id}',
        type: item.checkable ? 'checklist' : 'text',
        text: item.text,
      );
      final presentation = PreArrivalItemPresentation.forBlock(block);
      expect(
        PreArrivalItemPresentation.catalog.containsKey(item.id),
        isTrue,
        reason: item.id,
      );
      expect(presentation.title, isNotEmpty, reason: item.id);
      expect(presentation.icon, isNot(Icons.pets), reason: item.id);
    }
  });
  test(
    'deployed-contract storage round trips styles, fonts, colors and original block IDs',
    () async {
      var guide = const PreArrivalGuideModel(
        shopId: 'SAVE',
        serviceType: 'accommodation',
        enabled: true,
      );
      for (final item in preArrivalCatalog) {
        guide = togglePreArrivalCatalog(guide, item, true);
      }
      const appearance = PreArrivalAppearance(
        fontFamily: 'NotoSerifTC',
        fontScale: 1.2,
        colorMode: 'custom',
        accentColor: 0xff445566,
      );
      final fixtures = <String, dynamic>{};
      for (final style in PreArrivalGuideStyle.values) {
        final original = guide.copyWith(style: style, appearance: appearance);
        final data = original.toStorageMap(updatedBy: 'owner');
        expect(data.containsKey('style'), isFalse);
        expect(data.containsKey('appearance'), isFalse);
        final restored = PreArrivalGuideModel.fromMap(
          shopId: 'SAVE',
          serviceType: 'accommodation',
          data: data,
        );
        expect(restored.style, style);
        expect(restored.appearance.toMap(), appearance.toMap());
        expect(
          restored.blocks.map((b) => b.toMap()).toList(),
          original.blocks.map((b) => b.toMap()).toList(),
        );
        expect(
          restored.visibleBlocks.any(
            (b) => b.id == PreArrivalGuideModel.presentationBlockId,
          ),
          isFalse,
        );
        fixtures[style] = {...data}..remove('updatedAt');
      }
      final reset = guide
          .copyWith(style: 'classic', appearance: const PreArrivalAppearance())
          .toStorageMap(updatedBy: 'owner');
      expect(
        (reset['blocks'] as List).any(
          (b) => b['id'] == PreArrivalGuideModel.presentationBlockId,
        ),
        isFalse,
      );
      fixtures['reset'] = {...reset}..remove('updatedAt');
      // Feed the actual Dart serialization to the Firestore emulator contract tests.
      await Directory('build').create(recursive: true);
      await File(
        'build/pre_arrival_storage_fixture.json',
      ).writeAsString(jsonEncode(fixtures));
    },
  );
  for (final style in PreArrivalGuideStyle.values) {
    testWidgets(
      '$style shows heading and icon for newly added cold-food option',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        var guide = PreArrivalGuideModel(
          shopId: '',
          serviceType: 'accommodation',
          style: style,
        );
        final option = preArrivalCatalog.firstWhere(
          (item) => item.id == 'cold-food',
        );
        guide = togglePreArrivalCatalog(guide, option, true);
        await tester.pumpWidget(
          MaterialApp(home: PreArrivalGuidePage(guide: guide)),
        );
        await tester.pumpAndSettle();
        final heading = find.text('冷藏與冷凍餐食');
        await tester.ensureVisible(heading);
        await tester.pumpAndSettle();
        expect(heading, findsOneWidget);
        expect(find.byIcon(Icons.ac_unit_outlined), findsOneWidget);
        expect(find.text(option.text), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
