// 檔案名稱：test/daily_care_setting_page_test.dart
// 功能說明：每日照護設定頁場次名稱不會在 build 跳 SnackBar，回報規則可雙欄排列。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_paid_plan.dart';
import 'package:petnest_saas/core/models/daily_care_report_mode.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/features/shop/pages/daily_care_setting_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Map<String, dynamic> shopData = <String, dynamic>{
    'daycareEnabled': true,
    'name': '測試店',
  };

  DailyCareSettingModel setting({
    int sessionCount = 3,
    List<String> sessionLabels = const <String>['上午場', '下午場', '晚上場'],
    bool enabled = true,
    bool daycareEnabled = true,
    int daycareSessionCount = 2,
    List<String> daycareSessionLabels = const <String>['安親一', '安親二'],
    String stayReportMode = DailyCareReportMode.includedFixed,
    String daycareReportMode = DailyCareReportMode.includedFixed,
  }) {
    return DailyCareSettingModel(
      enabled: enabled,
      sessionCount: sessionCount,
      sessionLabels: sessionLabels,
      daycareEnabled: daycareEnabled,
      daycareSessionCount: daycareSessionCount,
      daycareSessionLabels: daycareSessionLabels,
      stayReportMode: stayReportMode,
      daycareReportMode: daycareReportMode,
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    DailyCareSettingModel? initialSetting,
    Future<void> Function({
      required DailyCareSettingModel setting,
      required int? expectedRevision,
      required DailyCareSettingSection section,
    })?
    saveOverride,
    bool pushRoute = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final DailyCareSettingPage page = DailyCareSettingPage(
      shopId: 'shop-1',
      initialSetting: initialSetting ?? setting(),
      shopData: shopData,
      saveOverride: saveOverride,
      showTaskCenterButton: false,
    );

    if (pushRoute) {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => page));
                  },
                  child: const Text('開啟設定'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('開啟設定'));
      await tester.pumpAndSettle();
      return;
    }

    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  Finder labelField(String label) {
    return find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.labelText == label,
    );
  }

  Future<void> replaceField(
    WidgetTester tester,
    Finder field,
    String value,
  ) async {
    await tester.enterText(field, value);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
  }

  testWidgets('輸入、清空、再輸入場次名稱不會在 build 期間跳 SnackBar', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, size: const Size(1280, 900));

    final Finder first = labelField('第 1 場名稱').first;
    expect(find.text('上午場'), findsWidgets);

    await replaceField(tester, first, '上');
    expect(find.text('上'), findsWidgets);

    await replaceField(tester, first, '');
    expect(find.text('住宿第 1 場名稱不可空白'), findsNothing);

    await replaceField(tester, first, '上午照護');
    expect(find.text('上午照護'), findsWidgets);
    expect(find.text('住宿第 1 場名稱不可空白'), findsNothing);
  });

  testWidgets('場次名稱空白時，只有按儲存才出現驗證提示', (WidgetTester tester) async {
    var saveCalls = 0;
    await pumpPage(
      tester,
      size: const Size(1280, 900),
      saveOverride:
          ({
            required DailyCareSettingModel setting,
            required int? expectedRevision,
            required DailyCareSettingSection section,
          }) async {
            saveCalls += 1;
          },
    );

    await replaceField(tester, labelField('第 1 場名稱').first, '');
    expect(saveCalls, 0);

    await tester.tap(find.text('確認儲存此分頁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('住宿第 1 場名稱不可空白'), findsOneWidget);
    expect(saveCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('安親場次名稱空白時，按儲存才提示', (WidgetTester tester) async {
    await pumpPage(
      tester,
      size: const Size(1280, 900),
      initialSetting: setting(enabled: false),
    );

    await replaceField(tester, labelField('第 1 場名稱').last, '');
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('確認儲存此分頁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('安親第 1 場名稱不可空白'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1280 為住宿與安親雙欄，390 為單欄且不 overflow', (WidgetTester tester) async {
    await pumpPage(tester, size: const Size(1280, 900));
    expect(find.byKey(const Key('daily-care-rules-columns')), findsOneWidget);
    expect(find.text('住宿回報規則'), findsOneWidget);
    expect(find.text('安親回報規則'), findsOneWidget);
    expect(find.text('每筆安親服務於服務當日提供回報。'), findsOneWidget);
    final Offset stay = tester.getTopLeft(find.text('住宿回報規則'));
    final Offset daycare = tester.getTopLeft(find.text('安親回報規則'));
    expect((stay.dy - daycare.dy).abs(), lessThan(8));
    expect(daycare.dx, greaterThan(stay.dx + 300));
    expect(tester.takeException(), isNull);

    await pumpPage(tester, size: const Size(390, 844));
    expect(find.byKey(const Key('daily-care-rules-columns')), findsNothing);
    expect(find.text('住宿回報規則'), findsOneWidget);
    expect(find.byType(RadioListTile<String>), findsWidgets);
    final Finder rulesList = find.byKey(const Key('daily-care-rules-list'));
    for (
      int step = 0;
      step < 6 && find.text('安親回報規則').evaluate().isEmpty;
      step++
    ) {
      await tester.drag(rulesList, const Offset(0, -320));
      await tester.pumpAndSettle();
    }
    expect(find.text('安親回報規則'), findsOneWidget);
    expect(find.text('每筆安親服務於服務當日提供回報。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切換場次數量只改變顯示，不清除已輸入名稱', (WidgetTester tester) async {
    await pumpPage(
      tester,
      size: const Size(1280, 1100),
      initialSetting: setting(sessionLabels: const <String>['甲場', '乙場', '丙場']),
    );

    expect(find.text('乙場'), findsOneWidget);
    expect(find.text('丙場'), findsOneWidget);

    await tester.tap(find.text('3 場'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 場').last);
    await tester.pumpAndSettle();

    expect(find.text('甲場'), findsOneWidget);
    expect(find.text('乙場'), findsNothing);
    expect(find.text('丙場'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('1 場'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 場').last);
    await tester.pumpAndSettle();

    expect(find.text('甲場'), findsOneWidget);
    expect(find.text('乙場'), findsOneWidget);
    expect(find.text('丙場'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未儲存時切換分頁與離開會提示，儲存成功與修訂衝突仍顯示既有訊息', (WidgetTester tester) async {
    DailyCareSettingSection? savedSection;
    int? savedRevision;
    var conflict = false;
    await pumpPage(
      tester,
      size: const Size(1280, 900),
      pushRoute: true,
      saveOverride:
          ({
            required DailyCareSettingModel setting,
            required int? expectedRevision,
            required DailyCareSettingSection section,
          }) async {
            savedSection = section;
            savedRevision = expectedRevision;
            if (conflict) {
              throw const DailyCareSettingSaveException(
                '設定已被其他人更新，請重新載入後再儲存',
                code: 'revision-conflict',
              );
            }
          },
    );

    await tester.enterText(labelField('第 1 場名稱').first, '上午照護');
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('照護內容'));
    await tester.pumpAndSettle();
    expect(find.text('有尚未儲存的變更'), findsOneWidget);
    expect(find.text('要先儲存目前分頁，還是放棄變更再前往？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('住宿回報規則'), findsOneWidget);

    await tester.tap(find.text('照護內容'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存並前往'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(savedSection, DailyCareSettingSection.rules);
    expect(savedRevision, 0);
    expect(find.text('每日照護紀錄設定已儲存'), findsOneWidget);
    expect(find.text('場次數量與名稱請在「回報規則」設定。此頁只編輯顧客日誌會出現的照護項目。'), findsOneWidget);

    await tester.tap(find.text('回報規則'));
    await tester.pumpAndSettle();
    expect(find.text('有尚未儲存的變更'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    conflict = true;
    await tester.enterText(labelField('第 1 場名稱').first, '衝突測試');
    await tester.pump();
    await tester.tap(find.text('確認儲存此分頁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('設定已被其他人更新，請重新載入後再儲存'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('離開前要儲存、放棄，還是繼續編輯？'), findsOneWidget);
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(find.text('住宿回報規則'), findsOneWidget);
  });

  testWidgets('舊資料 reports 超出 0～2 時不會越界，規則分頁仍帶 revision', (
    WidgetTester tester,
  ) async {
    DailyCareSettingSection? savedSection;
    int? savedRevision;
    DailyCareSettingModel? saved;
    await pumpPage(
      tester,
      size: const Size(1280, 1400),
      initialSetting:
          setting(
            stayReportMode: DailyCareReportMode.paidAddon,
            daycareReportMode: DailyCareReportMode.paidAddon,
          ).copyWith(
            revision: 4,
            stayPaidPlan: const DailyCarePaidPlan(
              reports: 0,
              sessionLabels: <String>['早'],
            ),
            daycarePaidPlan: const DailyCarePaidPlan(
              name: '寫真回報',
              description: '兩場',
              price: 300,
              reports: 8,
              sessionLabels: <String>['安親一', '安親二'],
            ),
          ),
      saveOverride:
          ({
            required DailyCareSettingModel setting,
            required int? expectedRevision,
            required DailyCareSettingSection section,
          }) async {
            saved = setting;
            savedSection = section;
            savedRevision = expectedRevision;
          },
    );

    expect(tester.takeException(), isNull);
    expect(find.text('寫真回報'), findsWidgets);

    await tester.tap(find.text('確認儲存此分頁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(savedSection, DailyCareSettingSection.rules);
    expect(savedRevision, 4);
    expect(saved, isNotNull);
    expect(saved!.stayPaidPlan.reports, inInclusiveRange(1, 3));
    expect(saved!.daycarePaidPlan.reports, inInclusiveRange(1, 3));
    expect(saved!.stayPaidPlan.sessionLabels.length, lessThanOrEqualTo(3));
    expect(saved!.daycarePaidPlan.sessionLabels.length, lessThanOrEqualTo(3));
    expect(find.text('每日照護紀錄設定已儲存'), findsOneWidget);
  });
}
