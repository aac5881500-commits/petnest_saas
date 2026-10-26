import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_form_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('NotoSansTC')
      ..addFont(
        rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
      );
    await loader.load();
  });
  Future<void> show(
    WidgetTester tester, {
    double width = 1100,
    double scale = 1,
    InventoryItemModel? item,
  }) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansTC'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          child: ShopInventoryFormPage(shopId: 'shop', item: item),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  for (final width in [320.0, 390.0, 820.0, 1440.0]) {
    testWidgets('responsive form at $width', (tester) async {
      await show(tester, width: width);
      expect(find.text('建立品項'), findsOneWidget);
      expect(find.text('基本資料'), findsOneWidget);
      expect(tester.getSize(field('品項名稱 *')).width, lessThan(800));
      if (width >= 800) {
        expect(
          tester.getTopLeft(find.text('品項圖片')).dx,
          greaterThan(tester.getTopLeft(find.text('基本資料')).dx),
        );
      }
      expect(tester.takeException(), isNull);
      const capture = String.fromEnvironment('FORM_CAPTURE_DIR');
      if (capture.isNotEmpty && (width == 390 || width == 1440)) {
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile(Uri.file('$capture/form-${width.toInt()}.png')),
        );
      }
    });
  }
  testWidgets('large text has no overflow', (tester) async {
    await show(tester, width: 320, scale: 1.5);
    await tester.scrollUntilVisible(
      find.text('允許小數用量'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('建立品項'), findsOneWidget);
  });
  testWidgets('required fields stop save before network requests', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('建立品項'));
    await tester.pumpAndSettle();
    expect(find.text('請輸入品項名稱'), findsOneWidget);
    await tester.enterText(field('計量單位 *'), '');
    await tester.tap(find.text('建立品項'));
    await tester.pumpAndSettle();
    expect(find.text('請輸入計量單位'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('stock thresholds reject invalid and non-finite values', (
    tester,
  ) async {
    await show(tester);
    for (final input in ['', 'abc', 'NaN', 'Infinity', '-1']) {
      await tester.enterText(field('安全庫存 *'), input);
      await tester.tap(find.text('建立品項'));
      await tester.pumpAndSettle();
      expect(
        find.text(input == '-1' ? '安全庫存不可為負數' : '請輸入有效數字'),
        findsOneWidget,
      );
    }
    await tester.enterText(field('安全庫存 *'), '0.5');
    await tester.pumpAndSettle();
    expect(find.text('請輸入有效數字'), findsNothing);
    expect(find.text('安全庫存不可為負數'), findsNothing);
  });
  testWidgets('edit preserves legacy category and stock context', (
    tester,
  ) async {
    final item = InventoryItemModel(
      id: 'old',
      shopId: 'shop',
      name: '原有品項',
      category: '舊分類',
      currentStock: 7,
      safetyStock: 2,
      unit: '包',
      allowDecimal: false,
      enabled: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await show(tester, item: item);
    expect(find.text('儲存變更'), findsOneWidget);
    expect(find.text('原有品項'), findsOneWidget);
    expect(find.text('舊分類'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switches.every((tile) => !tile.value), isTrue);
    expect(tester.takeException(), isNull);
  });
}
