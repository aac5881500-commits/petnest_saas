// 功能：關於我們分區編輯與範本、正式內容隔離的局部驗證。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_intro_view.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';

void main() {
  testWidgets('範本只改排列，保留輸入，原儲存與離開取消可用', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final writes = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ShopAboutManagePage(
          shopId: 'local',
          shopStream: Stream<Map<String, dynamic>?>.value(const {
            'name': '測試店',
            'aboutTitle': '自己寫的店名',
            'aboutDescription': '自己的簡介',
          }),
          saveAbout: (data) async => writes.add(data),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '修改的店名');
    await tester.tap(find.text('版型範本'));
    await tester.pumpAndSettle();
    expect(find.text('手機完整排版'), findsOneWidget);
    expect(find.text('電腦完整排版'), findsOneWidget);
    expect(find.text('補齊示範內容與照片'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('about-apply-daylight-template')),
    );
    await tester.tap(
      find.byKey(const ValueKey('about-apply-daylight-template')),
    );
    await tester.pumpAndSettle();
    final actual = tester
        .widgetList<AboutIntroView>(find.byType(AboutIntroView))
        .first;
    expect(actual.setting.layout, 'daylight');
    expect(actual.shop['aboutTitle'], '修改的店名');
    expect(actual.setting.items('principles'), isEmpty);
    expect(actual.setting.cover.source, isNot('builtin'));
    expect(writes, isEmpty);
    final state =
        tester.state(find.byType(ShopAboutManagePage))
            as ShopDashboardLeaveAware;
    final leaving = state.dashboardConfirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(await leaving, isFalse);
    await tester.tap(find.text('封面與介紹'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '修改的店名',
    );
    await tester.tap(find.widgetWithText(TextButton, '儲存'));
    await tester.pumpAndSettle();
    expect(writes.single['aboutTitle'], '修改的店名');
    expect(writes.single['homeAppearance.aboutPage.layout'], 'daylight');
    expect(
      writes.single.containsKey('homeAppearance.aboutPage.cover.source'),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('預覽空白提示可以切到正確分頁，正式頁無提示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ShopAboutManagePage(
          shopId: 'local',
          shopStream: Stream<Map<String, dynamic>?>.value(const {'name': '店家'}),
          saveAbout: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('新增照護理念').first);
    await tester.tap(find.text('新增照護理念').first);
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AboutIntroView(
            shop: const {'name': '店家'},
            setting: AboutPageSetting(),
            theme: HomeThemeModel.classicDefault,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新增照護理念'), findsNothing);
    expect(find.text('加入封面照片與介紹'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('手機分頁與編輯預覽切換保留文字', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ShopAboutManagePage(
          shopId: 'local',
          shopStream: Stream<Map<String, dynamic>?>.value(const {'name': '店家'}),
          saveAbout: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '手機輸入');
    await tester.tap(find.text('預覽'));
    await tester.pumpAndSettle();
    expect(find.text('手機輸入'), findsOneWidget);
    await tester.tap(find.text('編輯'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '手機輸入',
    );
    expect(tester.takeException(), isNull);
  });
}
