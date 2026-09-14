// 檔案名稱：test/daily_care_journal_preview_test.dart
// 功能說明：設定即時預覽使用共用 renderer，固定 390 寬且無縮放倍率

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/widgets/daily_care_journal_renderer.dart';
import 'package:petnest_saas/features/shop/widgets/daily_care_full_journal_preview.dart';

void main() {
  testWidgets('預覽使用共用 renderer 且寬度為 390', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 900,
            child: DailyCareFullJournalPreview(
              setting: DailyCareSettingModel(),
              isDaycare: false,
              sessionLabels: <String>['上午場', '下午場'],
              sessionIndex: 0,
              showPhotos: true,
              usePhoneFrame: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DailyCareJournalRenderer), findsOneWidget);
    expect(find.text('住宿照護紀錄'), findsOneWidget);
    expect(find.textContaining('預覽倍率'), findsNothing);
    expect(find.text('小米'), findsWidgets);

    final Size rendererSize = tester.getSize(
      find.byType(DailyCareJournalRenderer),
    );
    expect(rendererSize.width, 370);
  });

  testWidgets('安親示範與無照片仍走同一套 renderer', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 800,
            child: DailyCareFullJournalPreview(
              setting: DailyCareSettingModel(photoEnabled: true),
              isDaycare: true,
              sessionLabels: <String>['本次回報'],
              sessionIndex: 0,
              showPhotos: false,
              usePhoneFrame: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DailyCareJournalRenderer), findsOneWidget);
    expect(find.text('今日尚未上傳照護照片'), findsOneWidget);
  });
}
