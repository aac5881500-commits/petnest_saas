import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_manage_page.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_draft_preview.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';

void main() {
  Future<void> open(WidgetTester tester, Map<String, dynamic> intro,
      List<Map<String, dynamic>> writes) async {
    const size = Size(1400, 1100);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(size: size), child: child!),
      home: ShopEnvironmentManagePage(shopId: 'fixture',
        loadShop: () async => {'environmentIntro': intro},
        saveIntro: (payload) async => writes.add(payload)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('empty preview shows guidance for all presets and devices, starter is draft until saved', (tester) async {
    final writes = <Map<String, dynamic>>[];
    await open(tester, {}, writes);
    final state = tester.state(find.byType(ShopEnvironmentManagePage)) as ShopDashboardLeaveAware;
    expect(find.text('環境介紹尚未加入內容'), findsOneWidget);
    expect(state.dashboardHasUnsavedChanges, isFalse);
    for (final preset in ['溫暖旅宿', '清爽簡約', '照片導覽', '安心照護']) {
      await tester.tap(find.text(preset));
      await tester.pumpAndSettle();
      expect(find.text('環境介紹尚未加入內容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('桌機'));
    await tester.pumpAndSettle();
    expect(find.text('環境介紹尚未加入內容'), findsOneWidget);
    await tester.tap(find.text('手機'));
    await tester.pumpAndSettle();
    for (final label in ['小', '大', '標準']) {
      await tester.tap(find.descendant(of: find.byType(EnvironmentDraftPreview), matching: find.byType(DropdownButton<int>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(writes, isEmpty);
    await tester.tap(find.byKey(const ValueKey<String>('environment-add-starter-copy')));
    await tester.pumpAndSettle();
    expect(find.text('環境介紹尚未加入內容'), findsNothing);
    final preview = find.byType(EnvironmentDraftPreview);
    expect(find.descendant(of: preview, matching: find.text('歡迎參觀我們的環境')), findsOneWidget);
    expect(writes, isEmpty);
    expect(state.dashboardHasUnsavedChanges, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, '儲存').first);
    await tester.pumpAndSettle();
    expect(writes.single['heroTitle'], '歡迎參觀我們的環境');
    expect(state.dashboardHasUnsavedChanges, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved content renders in preview without substituting starter content', (tester) async {
    final writes = <Map<String, dynamic>>[];
    await open(tester, {'heroTitle': '真實環境介紹', 'heroSubtitle': '原有內容'}, writes);
    expect(find.text('環境介紹尚未加入內容'), findsNothing);
    expect(find.descendant(of: find.byType(EnvironmentDraftPreview), matching: find.text('真實環境介紹')), findsOneWidget);
    expect(writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
