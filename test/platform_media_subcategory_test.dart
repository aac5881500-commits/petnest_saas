import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/features/platform/pages/platform_media_library_page.dart';

void main() {
  test('subcategory survives parsing, saving and copying; legacy assets remain unclassified', () {
    final old = PlatformMediaAsset.fromMap('old', {'category': 'dailyCarePage'});
    expect(old.subcategory, isEmpty);
    final grouped = old.copyWith(subcategory: '自然風景');
    final restored = PlatformMediaAsset.fromMap('old', grouped.toMap());
    expect(restored.subcategory, '自然風景');
    expect(restored.category, 'dailyCarePage');
    expect(restored.copyWith(name: '山景').subcategory, '自然風景');
    expect(restored.copyWith(subcategory: '').subcategory, isEmpty);
    expect(PlatformMediaCategories.label(old.category), '共用頁面背景');
  });

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('new asset editor supports grouping and validation at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
        PlatformMediaAssetEditorDialog(defaultCategory: PlatformMediaCategories.dailyCarePage,
          subcategories: ['自然風景', '貓咪']))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('新增共用素材'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(ActionChip, '貓咪'));
      await tester.tap(find.widgetWithText(ActionChip, '貓咪'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      expect(tester.widget<TextFormField>(fields.at(1)).controller!.text, '貓咪');
      await tester.tap(find.text('新增素材'));
      await tester.pumpAndSettle();
      expect(find.text('請輸入圖片名稱'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
