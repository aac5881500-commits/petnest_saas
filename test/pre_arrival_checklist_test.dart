import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';

PreArrivalGuideModel guide({String label = '日常飼料'}) => PreArrivalGuideModel(
  shopId: '',
  serviceType: 'accommodation',
  enabled: true,
  blocks: <PreArrivalGuideBlock>[
    const PreArrivalGuideBlock(id: 'heading', type: 'heading', text: '必帶物品'),
    PreArrivalGuideBlock(
      id: 'food',
      type: 'checklist',
      text: label,
      sortOrder: 1,
    ),
    const PreArrivalGuideBlock(
      id: 'carrier',
      type: 'checklist',
      text: '外出籠',
      sortOrder: 2,
    ),
    const PreArrivalGuideBlock(
      id: 'empty',
      type: 'checklist',
      text: ' ',
      sortOrder: 3,
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'checklist round trips alongside existing content and ignores empty items',
    () {
      final original = guide();
      final restored = PreArrivalGuideModel.fromMap(
        shopId: '',
        serviceType: 'accommodation',
        data: original.toMap(updatedBy: 'owner'),
      );
      expect(restored.blocks[1].type, PreArrivalGuideBlockType.checklist);
      expect(restored.visibleBlocks.length, 3);
      expect(restored.hasCustomerContent, isTrue);
      expect(restored.copyWith(enabled: false).hasCustomerContent, isFalse);
      expect(
        PreArrivalGuideBlock.fromMap(<String, dynamic>{'type': 'unknown'}).type,
        'text',
      );
    },
  );

  Future<void> open(
    WidgetTester tester, {
    String? scope,
    String label = '日常飼料',
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: PreArrivalGuidePage(
          guide: guide(label: label),
          progressScope: scope,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'customer checks persist on reopen, allow uncheck, isolate booking and user',
    (tester) async {
      await open(tester, scope: 'user/shop/booking1');
      expect(find.text('準備進度 0 / 2'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('preparation-check-food')),
      );
      await tester.pumpAndSettle();
      expect(find.text('準備進度 1 / 2'), findsOneWidget);
      await open(tester, scope: 'user/shop/booking1');
      expect(find.text('準備進度 1 / 2'), findsOneWidget);
      await open(tester, scope: 'user/shop/booking2');
      expect(find.text('準備進度 0 / 2'), findsOneWidget);
      await open(tester, scope: 'other/shop/booking1');
      expect(find.text('準備進度 0 / 2'), findsOneWidget);
      await open(tester, scope: 'user/shop/booking1', label: '新的準備要求');
      expect(find.text('準備進度 0 / 2'), findsOneWidget);
      await open(tester, scope: 'user/shop/booking1');
      await tester.tap(
        find.byKey(const ValueKey<String>('preparation-check-food')),
      );
      await tester.pumpAndSettle();
      expect(find.text('準備進度 0 / 2'), findsOneWidget);
      await open(tester, scope: 'user/shop/booking1');
      expect(find.text('準備進度 0 / 2'), findsOneWidget);
    },
  );

  testWidgets(
    'preview is interactive without persisting and fits narrow screens with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: PreArrivalGuidePage(guide: guide()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('preparation-check-food')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('preparation-check-food')),
      );
      await tester.pumpAndSettle();
      expect(find.text('準備進度 1 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      await open(tester);
      expect(find.text('準備進度 0 / 2'), findsOneWidget);
    },
  );
}
