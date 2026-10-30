import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/pet_profile_catalog.dart';
import 'package:petnest_saas/features/pet/widgets/pet_catalog_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'PetPreview',
    )..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> mount(
    WidgetTester t,
    GlobalKey capture, {
    bool multiple = false,
  }) async {
    await t.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'PetPreview'),
          home: Scaffold(
            backgroundColor: HomeThemeModel.modernDefault.backgroundColor,
            appBar: AppBar(title: const Text('寵物資料')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: PetCatalogField(
                label: multiple ? '醫療狀況' : '品種',
                value: multiple ? '' : '柴犬',
                options: multiple
                    ? PetProfileCatalog.medical('dog')
                    : PetProfileCatalog.breeds('dog'),
                multiple: multiple,
                exclusiveValues: const {'無', '不確定'},
                onChanged: (_) {},
                decoration: InputDecoration(
                  labelText: multiple ? '醫療狀況' : '品種',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byType(PetCatalogField));
    await t.pumpAndSettle();
  }

  for (final width in [390.0, 1000.0]) {
    testWidgets(
      'themed picker at $width has selected cards, a clear search state and a pinned confirm action',
      (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        await mount(t, capture);
        expect(find.text('選擇品種'), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
        final button = t.widget<FilledButton>(
          find.byWidgetPredicate((w) => w is FilledButton),
        );
        expect(
          button.style!.backgroundColor!.resolve({}),
          HomeThemeModel.modernDefault.primaryColor,
        );
        expect(
          t.getSize(find.byKey(const ValueKey('pet-menu-options'))).width,
          lessThanOrEqualTo(600),
        );
        expect(t.takeException(), isNull);
        if (Platform.environment['PET_MENU_PREVIEW'] != null) {
          await t.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${Platform.environment['PET_MENU_PREVIEW']}/pet_menu_${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await t.enterText(
          find.byKey(const ValueKey('pet-menu-search')),
          '不存在的品種',
        );
        await t.pumpAndSettle();
        expect(find.text('找不到符合的選項'), findsOneWidget);
        expect(find.text('其他（自行填寫）'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'keyboard keeps custom entry and confirmation usable on a short phone',
    (t) async {
      t.view.physicalSize = const Size(360, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      await mount(t, GlobalKey(), multiple: true);
      final other = find.text('其他（自行填寫）');
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('pet-menu-options')),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(other, 200, scrollable: scroll);
      await t.pumpAndSettle();
      await t.tap(other);
      await t.pumpAndSettle();
      t.view.viewInsets = const FakeViewPadding(bottom: 290);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final input = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '其他醫療狀況',
      );
      await t.scrollUntilVisible(input, 120, scrollable: scroll);
      await t.pumpAndSettle();
      await t.enterText(input, '需要額外照護');
      await t.pumpAndSettle();
      expect(
        t.getBottomRight(find.byWidgetPredicate((w) => w is FilledButton)).dy,
        lessThanOrEqualTo(410),
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
