import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/internal_handover_entry.dart';
import 'package:petnest_saas/features/admin/widgets/internal_handover_composer.dart';
import 'package:petnest_saas/features/admin/widgets/admin_internal_handover_card.dart';

void main() {
  test('分類內容保留換行，記錄人與版本可讀回', () {
    final entry = InternalHandoverEntry.fromMap('one', {
      'text': InternalHandoverEntry.encode('餵藥交代', ' 飯後餵藥\n留意吐藥 '),
      'revision': 2,
      'updatedByEmail': 'staff@test.tw',
      'updatedAt': DateTime(2026, 11, 20),
    });
    expect(entry.category, '餵藥交代');
    expect(entry.content, '飯後餵藥\n留意吐藥');
    expect(entry.author, 'staff@test.tw');
    expect(entry.revision, 2);
    expect(entry.createdAt, isNotNull);
  });
  test('舊文字交接完整保留，分類和空內容會檢查', () {
    final entry = InternalHandoverEntry.fromMap('legacy', {
      'text': '原本交代\n不要覆蓋',
      'revision': 1,
    });
    expect(entry.category, '原有交接');
    expect(entry.content, '原本交代\n不要覆蓋');
    expect(
      () => InternalHandoverEntry.encode('不存在', '內容'),
      throwsArgumentError,
    );
    expect(
      () => InternalHandoverEntry.encode('住宿交代', '  '),
      throwsArgumentError,
    );
    expect(
      () => InternalHandoverEntry.encode('住宿交代', '字' * 3001),
      throwsArgumentError,
    );
    expect(
      InternalHandoverEntry.encode('住宿交代', '字' * 3000).length,
      lessThan(4000),
    );
  });
  for (final width in [320.0, 900.0]) {
    testWidgets('分類後可連續新增兩筆，$width 寬不覆蓋上一筆', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: InternalHandoverComposer(
                  onSave: (category, content) async {
                    saved.add('$category：$content');
                  },
                ),
              ),
            ),
          ),
        ),
      );
      FilledButton button() => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('新增交接'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      expect(button().onPressed, isNull);
      await tester.enterText(find.byType(TextField), '怕生慢慢接近');
      expect(button().onPressed, isNull);
      await tester.tap(find.text('住宿交代'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增交接'));
      await tester.pumpAndSettle();
      expect(saved, ['住宿交代：怕生慢慢接近']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(button().onPressed, isNull);
      await tester.tap(find.text('餵藥交代'));
      await tester.enterText(find.byType(TextField), '飯後服藥');
      await tester.pump();
      await tester.tap(find.text('新增交接'));
      await tester.pumpAndSettle();
      expect(saved, ['住宿交代：怕生慢慢接近', '餵藥交代：飯後服藥']);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('儲存失敗保留分類和草稿，可重試', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InternalHandoverComposer(
            onSave: (_, _) async => throw Exception('offline'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('健康觀察'));
    await tester.enterText(find.byType(TextField), '食慾偏低');
    await tester.pump();
    await tester.tap(find.text('新增交接'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '食慾偏低',
    );
    expect(find.textContaining('內容已保留'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '健康觀察'))
          .selected,
      isTrue,
    );
  });
  testWidgets('紀錄顯示分類、內容及人員', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InternalHandoverEntryTile(
            entry: InternalHandoverEntry(
              id: 'e',
              category: '住宿交代',
              content: '下一班請留意',
              author: 'staff@test.tw',
              revision: 1,
            ),
          ),
        ),
      ),
    );
    expect(find.text('住宿交代'), findsOneWidget);
    expect(find.text('下一班請留意'), findsOneWidget);
    expect(find.textContaining('staff@test.tw'), findsOneWidget);
  });
}
