import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_guide_help.dart';

void main() {
  test('adding example preserves draft, publish settings, unique IDs and display order', () {
    const original = PreArrivalGuideModel(shopId: '', serviceType: 'daycare', title: '本店準備說明',
      blocks: [PreArrivalGuideBlock(id: 'old', type: 'heading', text: '本店說明', sortOrder: 99)]);
    final updated = appendPreArrivalExample(original, idPrefix: 'first');
    expect(original.blocks.length, 1);
    expect(updated.blocks.first.id, 'old');
    expect(updated.title, original.title);
    expect(updated.enabled, isFalse);
    expect(updated.blocks[3].text, contains('當日'));
    expect(updated.visibleBlocks.map((b) => b.id), updated.blocks.map((b) => b.id));
    final twice = appendPreArrivalExample(updated, idPrefix: 'second');
    expect(twice.blocks.map((b) => b.id).toSet().length, twice.blocks.length);
  });

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('help and real interactive sample at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var additions = 0;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
        body: ListView(children: [PreArrivalGuideHelpCard(
          onAddExample: () => additions++,
          onDemo: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
            PreArrivalGuidePage(guide: preArrivalExample(shopId: '')))),
        )]),
      ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('看示範・可試勾'));
      await tester.pumpAndSettle();
      expect(find.text('入住前準備示範'), findsOneWidget);
      expect(find.text('準備進度 0 / 4'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('preparation-check-food')));
      await tester.pumpAndSettle();
      expect(find.text('準備進度 1 / 4'), findsOneWidget);
      expect(additions, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('加入示範到草稿'));
      expect(additions, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('inherited daycare content explains where to edit and offers preview only', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [
      PreArrivalGuideHelpCard(isDaycare: true, inherit: true, onDemo: () {}, onAddExample: () {}),
    ]))));
    expect(find.text('加入示範到草稿'), findsNothing);
    expect(find.textContaining('請到「住宿」分頁修改'), findsOneWidget);
  });
}
