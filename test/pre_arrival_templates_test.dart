import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_checklist_templates.dart';

void main() {
  test('switching templates replaces the previous section and preserves manual content after reload', () {
    const guide = PreArrivalGuideModel(shopId: '', serviceType: 'accommodation', blocks: [
      PreArrivalGuideBlock(id: 'manual-intro', type: 'text', text: '本店提醒'),
    ]);
    final first = applyPreArrivalTemplate(guide,
      const PreArrivalTemplateDraft(title: '餐食', description: '維持日常飲食', text: '飼料\n罐頭\n飼料'), revision: '1');
    expect(first.blocks.where((b) => b.type == 'checklist').length, 2);
    final withManual = first.copyWith(blocks: [...first.blocks,
      const PreArrivalGuideBlock(id: 'manual-tail', type: 'text', text: '手動補充')]);
    final restored = PreArrivalGuideModel.fromMap(shopId: '', serviceType: 'accommodation', data: withManual.toMap(updatedBy: 'test'));
    final second = applyPreArrivalTemplate(restored,
      const PreArrivalTemplateDraft(title: '安心小物', description: '帶熟悉氣味', text: '毛毯'), revision: '2');
    expect(second.blocks.map((b) => b.text), ['本店提醒', '安心小物', '帶熟悉氣味', '毛毯', '手動補充']);
    expect(second.blocks.where((b) => b.type == 'heading').length, 1);
    expect(second.blocks.map((b) => b.sortOrder), [0, 1, 2, 3, 4]);
    expect(second.enabled, guide.enabled);
    expect(second.title, guide.title);
  });

  testWidgets('template switching keeps edits and returns only the selected draft on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PreArrivalTemplateDraft? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      child: const Text('開啟'), onPressed: () async { result = await showDialog<PreArrivalTemplateDraft>(context: context,
        builder: (_) => const PreArrivalChecklistTemplateDialog()); },
    )))));
    await tester.tap(find.text('開啟')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '本店自訂物品');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('餐食分裝（5 項）').last); await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, contains('餵食時間'));
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('基本住宿（4 項）').last); await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, '本店自訂物品');
    await tester.tap(find.text('套用分段模板')); await tester.pumpAndSettle();
    expect(result!.text, '本店自訂物品');
    expect(result!.title, '基本住宿');
    expect(result!.description, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daycare starts with its own template and manual batch remains blank', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PreArrivalChecklistTemplateDialog(isDaycare: true))));
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, contains('當日'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PreArrivalChecklistTemplateDialog(useTemplate: false))));
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, isEmpty);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
