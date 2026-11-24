import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_appearance_preset.dart';
import 'package:petnest_saas/features/shop/pages/home_preset_settings_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_appearance_preset_strip.dart';
import 'home_storybook_test.dart' show fixture;
import 'home_diary_test.dart' show openShop;

Widget launcher(String id, ValueChanged<HomePresetSettingsResult?> done) =>
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final preset = homeAppearancePresetById(id)!;
              done(
                await Navigator.push<HomePresetSettingsResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomePresetSettingsPage(
                      preset: preset,
                      initialDraft: preset.apply(fixture()),
                      navigationState: openShop,
                      previewBuilder: (draft) => Center(
                        child: Text(
                          '即時預覽：${draft.theme.storybook.diary.coverTitle}',
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: const Text('開啟風格'),
          ),
        ),
      ),
    );

void main() {
  test(
    'retired cottage is absent from selection but saved IDs remain readable',
    () {
      expect(homeAppearancePresets.map((p) => p.id), [
        'creamOrange',
        'catDiary',
      ]);
      expect(homeAppearancePresetById('storybookCottage')?.name, '繪本小屋');
    },
  );
  testWidgets(
    'gallery opens the selected settings instead of applying or previewing',
    (tester) async {
      String? opened;
      var applied = false, previewed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeAppearancePresetStrip(
                draft: fixture(),
                presetId: null,
                accent: Colors.blue,
                onPreview: (_) => previewed = true,
                onApply: (_) => applied = true,
                onRestore: () {},
                onOpenSettings: (preset) => opened = preset.id,
              ),
            ),
          ),
        ),
      );
      expect(find.text('繪本小屋'), findsNothing);
      await tester.ensureVisible(find.text('C｜貓咪日常誌'));
      await tester.tap(find.text('C｜貓咪日常誌'));
      expect(opened, 'catDiary');
      expect(applied, false);
      expect(previewed, false);
      await tester.ensureVisible(
        find.byKey(const Key('home-preset-apply-creamOrange')),
      );
      await tester.tap(find.byKey(const Key('home-preset-apply-creamOrange')));
      expect(opened, 'creamOrange');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets('C settings are isolated until apply returns the edited draft', (
    tester,
  ) async {
    HomePresetSettingsResult? result;
    final before = homeAppearanceDraftSignature(fixture());
    await tester.pumpWidget(launcher('catDiary', (value) => result = value));
    await tester.tap(find.text('開啟風格'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('style-settings-catDiary')),
      findsOneWidget,
    );
    expect(find.text('奶油暖橘・版面重點'), findsNothing);
    final field = find.widgetWithText(TextFormField, '封面主標題');
    await tester.ensureVisible(field);
    await tester.enterText(field, '自己的日記封面');
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(homeAppearanceDraftSignature(fixture()), before);
    await tester.tap(find.byKey(const Key('apply-style-settings')));
    await tester.pumpAndSettle();
    expect(result?.draft.theme.storybook.diary.coverTitle, '自己的日記封面');
    expect(find.text('開啟風格'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'cream page has no C controls and unchanged back returns no draft',
    (tester) async {
      var called = false;
      HomePresetSettingsResult? result;
      await tester.pumpWidget(
        launcher('creamOrange', (value) {
          called = true;
          result = value;
        }),
      );
      await tester.tap(find.text('開啟風格'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('style-settings-creamOrange')),
        findsOneWidget,
      );
      expect(find.text('C 原圖構圖・新增版型功能'), findsNothing);
      expect(find.widgetWithText(TextFormField, '封面主標題'), findsNothing);
      await tester.tap(find.text('返回風格清單'));
      await tester.pumpAndSettle();
      expect(called, true);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'discarding changed C settings leaves the original draft untouched',
    (tester) async {
      var returned = false;
      HomePresetSettingsResult? result;
      await tester.pumpWidget(
        launcher('catDiary', (value) {
          returned = true;
          result = value;
        }),
      );
      await tester.tap(find.text('開啟風格'));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextFormField, '封面主標題');
      await tester.ensureVisible(field);
      await tester.enterText(field, '未套用的標題');
      await tester.tap(find.text('返回風格清單'));
      await tester.pumpAndSettle();
      expect(find.text('放棄這個風格的調整？'), findsOneWidget);
      await tester.tap(find.text('繼續編輯'));
      await tester.pumpAndSettle();
      expect(returned, false);
      await tester.tap(find.text('返回風格清單'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放棄調整'));
      await tester.pumpAndSettle();
      expect(returned, true);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('preview thumbnail also enters its own settings page', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeAppearancePresetStrip(
              draft: fixture(),
              presetId: null,
              accent: Colors.blue,
              onPreview: (_) {},
              onApply: (_) {},
              onRestore: () {},
              onOpenSettings: (p) => opened = p.id,
              devicePreviewBuilder: (p, desktop, enlarged) => Text(p.id),
            ),
          ),
        ),
      ),
    );
    final card = find.byKey(const Key('home-preset-creamOrange'));
    final thumb = find.descendant(
      of: card,
      matching: find.byKey(const ValueKey('home-example-phone')),
    );
    await tester.ensureVisible(thumb);
    await tester.tap(thumb);
    await tester.pumpAndSettle();
    expect(opened, 'creamOrange');
    expect(find.byType(Dialog), findsNothing);
  });
  testWidgets('style page fits a narrow phone with large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p = homeAppearancePresetById('catDiary')!;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
          child: HomePresetSettingsPage(
            preset: p,
            initialDraft: p.apply(fixture()),
            navigationState: openShop,
            previewBuilder: (_) => const Center(child: Text('預覽')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
