import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/environment_layout_settings.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_manage_page.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_draft_preview.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_quick_template_card.dart';

void main() {
  test('區塊色彩兼容RGB ARGB與錯誤資料且不做動態位元運算', () {
    final s = EnvironmentLayoutSettings({
      'rgb': 0x718064,
      'argb': 0xff718064,
      'invalid': true,
      'large': double.infinity,
    });
    expect(s.color('rgb', Colors.red).toARGB32(), 0xff718064);
    expect(s.color('argb', Colors.red).toARGB32(), 0xff718064);
    expect(s.color('invalid', Colors.red), Colors.red);
    expect(s.color('large', Colors.red), Colors.red);
  });
  for (final size in [const Size(2560, 1400), const Size(390, 844)]) {
    testWidgets('單一完整範例與進階分頁 ${size.width}', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final writes = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: size),
            child: child!,
          ),
          home: ShopEnvironmentManagePage(
            shopId: 'fixture',
            loadShop: () async => {
              'environmentIntro': {'heroTitle': '保留原內容'},
            },
            saveIntro: (data) async => writes.add(data),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EnvironmentQuickTemplateCard), findsOneWidget);
      expect(find.text('清爽簡約'), findsNothing);
      expect(find.text('照片導覽'), findsNothing);
      expect(find.text('安心照護'), findsNothing);
      expect(find.text('手機完整排版'), findsOneWidget);
      expect(find.text('電腦完整排版'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      if (size.width >= 1100) {
        final rect = tester.getRect(find.byType(EnvironmentDraftPreview));
        expect(rect.left, lessThan(24));
        expect(rect.width, greaterThan(900));
      }
      await tester.ensureVisible(find.text('進階外觀'));
      await tester.tap(find.text('進階外觀'));
      await tester.pumpAndSettle();
      expect(find.text('APP 排版設定'), findsOneWidget);
      expect(find.text('快速排版｜溫暖旅宿'), findsNothing);
      expect(find.byType(Slider), findsWidgets);
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('版型範本'));
      await tester.tap(find.text('版型範本'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('放大查看範本'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放大查看範本'));
      await tester.pumpAndSettle();
      expect(find.text('溫暖旅宿｜完整效果示意'), findsOneWidget);
      await tester.tap(find.byTooltip('關閉範本預覽'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
