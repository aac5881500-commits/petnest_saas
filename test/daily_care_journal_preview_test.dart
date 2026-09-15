// 檔案名稱：test/daily_care_journal_preview_test.dart
// 功能說明：設定即時預覽為完整手機 viewport，含安全區與 sticky 切換

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/widgets/daily_care_journal_renderer.dart';
import 'package:petnest_saas/features/shop/widgets/daily_care_full_journal_preview.dart';

void main() {
  Future<void> pumpPreview(
    WidgetTester tester, {
    DailyCarePreviewPhoneSize phoneSize = DailyCarePreviewPhoneSize.standard,
    DailyCareSettingModel setting = const DailyCareSettingModel(),
    bool isDaycare = false,
    String shopName = '毛孩旅館',
    bool usePhoneFrame = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 1100,
            child: DailyCareFullJournalPreview(
              setting: setting,
              isDaycare: isDaycare,
              sessionLabels: const <String>['上午場', '下午場'],
              sessionIndex: 0,
              showPhotos: true,
              usePhoneFrame: usePhoneFrame,
              shopName: shopName,
              phoneSize: phoneSize,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('預設標準手機 393×852 含系統列、AppBar 與返回', (WidgetTester tester) async {
    await pumpPreview(tester);

    expect(find.byType(DailyCareJournalRenderer), findsOneWidget);
    expect(find.byType(AppBar), findsWidgets);
    expect(find.byType(BackButtonIcon), findsWidgets);
    expect(find.byType(DailyCarePreviewStatusBar), findsOneWidget);
    expect(find.text('10:32'), findsWidgets);
    expect(find.text('毛孩旅館'), findsWidgets);
    expect(find.text('住宿照護紀錄'), findsWidgets);
    expect(find.textContaining('毛孩旅館・'), findsNothing);
    expect(find.text('安親'), findsNothing);
    expect(find.textContaining('預覽倍率'), findsNothing);
    expect(find.byType(FittedBox), findsNothing);
    expect(find.text('小米'), findsWidgets);
    expect(find.textContaining('28°C'), findsOneWidget);
    expect(find.textContaining('填寫 10:32'), findsOneWidget);
    expect(find.text('✓ 已填寫'), findsWidgets);

    final BuildContext rendererContext = tester.element(
      find.byType(DailyCareJournalRenderer),
    );
    expect(MediaQuery.sizeOf(rendererContext), const Size(393, 852));
    expect(tester.getSize(find.byType(DailyCareJournalRenderer)).width, 393);
  });

  testWidgets('三種預覽尺寸會同時改變寬與高', (WidgetTester tester) async {
    await pumpPreview(tester, phoneSize: DailyCarePreviewPhoneSize.small);
    BuildContext ctx = tester.element(find.byType(DailyCareJournalRenderer));
    expect(MediaQuery.sizeOf(ctx), const Size(360, 780));

    await pumpPreview(tester);
    ctx = tester.element(find.byType(DailyCareJournalRenderer));
    expect(MediaQuery.sizeOf(ctx), const Size(393, 852));

    await pumpPreview(tester, phoneSize: DailyCarePreviewPhoneSize.large);
    ctx = tester.element(find.byType(DailyCareJournalRenderer));
    expect(MediaQuery.sizeOf(ctx), const Size(430, 932));
  });

  testWidgets('歡迎文字不再顯示', (WidgetTester tester) async {
    await pumpPreview(tester);
    expect(find.text('今天也請放心把毛孩交給我們照顧。'), findsNothing);
  });

  testWidgets('上滑後日期與場次仍可切換', (WidgetTester tester) async {
    await pumpPreview(tester);
    expect(find.text('上午場'), findsWidgets);
    await tester.drag(
      find.byType(DailyCareJournalRenderer),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(find.text('上午場'), findsWidgets);
    expect(find.text('下午場'), findsWidgets);
    await tester.tap(find.text('下午場').first);
    await tester.pump();
    expect(find.textContaining('下午場'), findsWidgets);
  });

  testWidgets('安親示範走同一套 renderer，僅標題與資料不同', (WidgetTester tester) async {
    await pumpPreview(
      tester,
      isDaycare: true,
      usePhoneFrame: false,
      setting: const DailyCareSettingModel(photoEnabled: true),
    );

    expect(find.byType(DailyCareJournalRenderer), findsOneWidget);
    expect(find.byType(DailyCarePreviewStatusBar), findsNothing);
    expect(find.text('本次安親回報'), findsWidgets);
    expect(find.text('今日尚未上傳照護照片'), findsNothing);
  });
}
