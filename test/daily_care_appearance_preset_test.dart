import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_appearance_preset.dart';
import 'package:petnest_saas/core/models/daily_care_journal_layout.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_paid_plan.dart';
import 'package:petnest_saas/core/models/daily_care_offer_quota.dart';
import 'package:petnest_saas/core/models/daily_care_report_mode.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/core/widgets/daily_care_card_surface.dart';
import 'package:petnest_saas/features/shop/pages/daily_care_setting_page.dart';
import 'package:petnest_saas/features/shop/widgets/daily_care_full_journal_preview.dart';

final initial = DailyCareSettingModel(
  enabled: true,
  sessionCount: 3,
  sessionLabels: const ['第一場', '第二場', '第三場'],
  enabledFields: const ['water', 'generalNote', 'wandToy'],
  customFields: const [
    DailyCareCustomField(
      id: 'custom_keep',
      label: '梳毛',
      category: 'activity',
      inputType: 'text',
    ),
  ],
  stayReportMode: DailyCareReportMode.paidAddon,
  stayPaidPlan: const DailyCarePaidPlan(
    price: 300,
    reports: 3,
    sessionLabels: ['第一場', '第二場', '第三場'],
  ),
  stayOfferQuotas: const {
    'room': DailyCareOfferQuota(reports: 2, sessionLabels: ['甲', '乙']),
  },
  daycareEnabled: true,
  daycareSessionCount: 2,
  daycareSessionLabels: const ['安親一', '安親二'],
  daycarePaidPlan: const DailyCarePaidPlan(price: 150, reports: 2),
  photoEnabled: false,
  logoVisible: false,
  revision: 27,
  journalDisplay: const DailyCareJournalDisplayFlags(showPhotoSection: false),
  journalCards: {
    ...DailyCareJournalCardLayout.mapFrom(null),
    'food': const DailyCareJournalCardLayout(
      key: 'food',
      visible: false,
      order: 8,
      iconAssetId: 'keep_library_icon',
    ),
  },
);
Map<String, dynamic> business(DailyCareSettingModel s) => {...s.toMap()}
  ..removeWhere(
    (key, value) => DailyCareAppearancePreset.appearanceKeys.contains(key),
  );
Future<void> pumpPage(
  WidgetTester tester, {
  Size size = const Size(1400, 950),
  DailyCareSettingModel? setting,
  Future<void> Function({
    required DailyCareSettingModel setting,
    required int? expectedRevision,
    required DailyCareSettingSection section,
  })?
  save,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: DailyCareSettingPage(
        shopId: 'local-test',
        initialSetting: setting ?? initial,
        shopData: const {'name': '本店日誌預覽', 'daycareEnabled': true},
        showTaskCenterButton: false,
        saveOverride:
            save ??
            ({
              required setting,
              required expectedRevision,
              required section,
            }) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> appearance(WidgetTester tester) async {
  await tester.tap(find.text('外觀設定'));
  await tester.pumpAndSettle();
}

void main() {
  for (final preset in dailyCareAppearancePresets) {
    test(
      '${preset.name} changes only appearance and preserves enabled content/rights',
      () {
        final next = preset.apply(initial);
        expect(business(next), business(initial));
        expect(next.logoVisible, initial.logoVisible);
        expect(next.journalDisplay.toMap(), initial.journalDisplay.toMap());
        expect(next.resolvedJournalCards['food']!.visible, false);
        expect(
          next.resolvedJournalCards['food']!.iconAssetId,
          'keep_library_icon',
        );
        expect(next.resolvedJournalCards['food']!.order, 8);
        expect(next.resolvedJournalCards['environment']!.isPinned, true);
        expect(preset.matches(next), true);
        expect(preset.matches(preset.apply(next)), true);
        final restored = DailyCareSettingModel.fromMap(next.toMap());
        expect(
          DailyCareAppearancePreset.appearanceSignature(restored),
          DailyCareAppearancePreset.appearanceSignature(next),
        );
      },
    );
  }
  test(
    'appearance dirty detection includes background colors, dimensions and header ink',
    () {
      expect(
        DailyCareAppearancePreset.appearanceSignature(
          initial.copyWith(cardGap: 7),
        ),
        isNot(DailyCareAppearancePreset.appearanceSignature(initial)),
      );
      expect(
        DailyCareAppearancePreset.appearanceSignature(
          initial.copyWith(backgroundColorKey: 'pink'),
        ),
        isNot(DailyCareAppearancePreset.appearanceSignature(initial)),
      );
      expect(
        DailyCareAppearancePreset.appearanceSignature(
          initial.copyWith(stayPaidPlan: const DailyCarePaidPlan(price: 999)),
        ),
        DailyCareAppearancePreset.appearanceSignature(initial),
      );
    },
  );
  testWidgets(
    'previewing and cancelling a preset does not alter the current draft',
    (tester) async {
      await pumpPage(tester);
      await appearance(tester);
      final before = tester
          .widget<DailyCareFullJournalPreview>(
            find.byType(DailyCareFullJournalPreview).first,
          )
          .setting;
      final card = find.byKey(const ValueKey('daily-care-preset-journal'));
      final preview = find.descendant(
        of: card,
        matching: find.widgetWithText(TextButton, '預覽'),
      );
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.text('奶油日誌預覽'), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      final after = tester
          .widget<DailyCareFullJournalPreview>(
            find.byType(DailyCareFullJournalPreview).first,
          )
          .setting;
      expect(
        DailyCareAppearancePreset.appearanceSignature(after),
        DailyCareAppearancePreset.appearanceSignature(before),
      );
      expect(find.byKey(const Key('undo-daily-care-template')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'apply, undo and appearance-only save keep plans and custom fields',
    (tester) async {
      DailyCareSettingModel? saved;
      DailyCareSettingSection? savedSection;
      int? revision;
      await pumpPage(
        tester,
        save:
            ({
              required setting,
              required expectedRevision,
              required section,
            }) async {
              saved = setting;
              revision = expectedRevision;
              savedSection = section;
            },
      );
      await appearance(tester);
      final before = tester
          .widget<DailyCareFullJournalPreview>(
            find.byType(DailyCareFullJournalPreview).first,
          )
          .setting;
      final button = find.byKey(const ValueKey('apply-daily-care-preset-blue'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      final styled = tester
          .widget<DailyCareFullJournalPreview>(
            find.byType(DailyCareFullJournalPreview).first,
          )
          .setting;
      expect(styled.backgroundColorKey, 'blue');
      expect(business(styled), business(before));
      final undo = find.byKey(const Key('undo-daily-care-template'));
      await tester.ensureVisible(undo);
      await tester.pumpAndSettle();
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(
        DailyCareAppearancePreset.appearanceSignature(
          tester
              .widget<DailyCareFullJournalPreview>(
                find.byType(DailyCareFullJournalPreview).first,
              )
              .setting,
        ),
        DailyCareAppearancePreset.appearanceSignature(before),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認儲存此分頁'));
      await tester.pumpAndSettle();
      expect(savedSection, DailyCareSettingSection.appearance);
      expect(saved?.backgroundColorKey, 'blue');
      expect(saved?.stayPaidPlan.price, 300);
      expect(saved?.customFields.single.id, 'custom_keep');
      expect(saved?.photoEnabled, false);
      expect(revision, 27);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'geometry edits use the same renderer and guard unsaved navigation',
    (tester) async {
      await pumpPage(tester);
      await appearance(tester);
      await tester.tap(
        find.byKey(const ValueKey('daily-care-appearance-tab-1')),
      );
      await tester.pumpAndSettle();
      final slider = find.byKey(const ValueKey('daily-care-geometry-卡片間距'));
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(40, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('回報規則'));
      await tester.pumpAndSettle();
      expect(find.text('有尚未儲存的變更'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('category filters do not deselect care fields', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('照護內容'));
    await tester.pumpAndSettle();
    final before = tester
        .widget<DailyCareFullJournalPreview>(
          find.byType(DailyCareFullJournalPreview).first,
        )
        .setting
        .enabledFields;
    await tester.tap(find.byKey(const ValueKey('daily-care-content-activity')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, '逗貓棒'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, '飲水'), findsNothing);
    expect(
      tester
          .widget<DailyCareFullJournalPreview>(
            find.byType(DailyCareFullJournalPreview).first,
          )
          .setting
          .enabledFields,
      before,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('all three settings tabs fit a 320px phone at large text', (
    tester,
  ) async {
    final originalError = FlutterError.onError;
    FlutterError.onError = (d) {
      FlutterError.dumpErrorToConsole(d);
      originalError?.call(d);
    };
    addTearDown(() => FlutterError.onError = originalError);
    await tester.binding.setSurfaceSize(const Size(320, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
          child: DailyCareSettingPage(
            shopId: 'test',
            initialSetting: initial,
            shopData: const {'name': '測試店', 'daycareEnabled': false},
            showTaskCenterButton: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final tab in ['照護內容', '外觀設定']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'every preset renders with the shared customer journal at supported phone sizes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(850, 1150));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final preset in dailyCareAppearancePresets) {
        for (final phone in DailyCarePreviewPhoneSize.all) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DailyCareFullJournalPreview(
                  setting: preset.apply(initial),
                  isDaycare: false,
                  sessionLabels: const [],
                  sessionIndex: 0,
                  phoneSize: phone,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${preset.id}/${phone.id}',
          );
          final surface = tester.widget<DailyCareCardSurface>(
            find.byType(DailyCareCardSurface).last,
          );
          expect(surface.setting.cardRadius, preset.radius);
        }
      }
    },
  );
  testWidgets('legacy default labels do not create unsaved changes', (
    tester,
  ) async {
    await pumpPage(tester, setting: const DailyCareSettingModel());
    await appearance(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('daily-care-appearance-list')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  final output = Platform.environment['PETNEST_CARE_SETTINGS_PREVIEW'] ?? '';
  testWidgets('export actual settings layout for visual review', (
    tester,
  ) async {
    for (final (family, path) in [
      ('NotoSansTC', 'assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family)..addFont(rootBundle.load(path));
      await loader.load();
    }
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansTC'),
        home: RepaintBoundary(
          key: key,
          child: DailyCareSettingPage(
            shopId: 'fixture',
            initialSetting: const DailyCareSettingModel(
              enabled: true,
              sessionCount: 3,
              sessionLabels: ['第一場', '第二場', '第三場'],
            ),
            shopData: const {'name': '每日照護・示意預覽', 'daycareEnabled': true},
            showTaskCenterButton: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final (index, tab) in ['回報規則', '照護內容', '外觀設定'].indexed) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      if (index == 2) {
        expect(
          find.byKey(const ValueKey('daily-care-appearance-list')),
          findsOneWidget,
        );
      }
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$output-$index.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  }, skip: output.isEmpty);
}
