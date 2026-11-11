import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/models/pre_arrival_appearance.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_style_picker.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_workspace.dart';

void main() {
  testWidgets(
    'desktop editing previews font and color changes beside collapsed choices',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        for (final e in {
          'jfOpenHuninn': 'assets/fonts/jf-openhuninn-2.1.ttf',
          'NotoSerifTC': 'assets/fonts/NotoSerifTC-VariableFont_wght.ttf',
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        }.entries) {
          await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
        }
      });
      await tester.binding.setSurfaceSize(const Size(1600, 1100));
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);
      var guide = const PreArrivalGuideModel(
        shopId: '',
        serviceType: 'accommodation',
        style: 'packing',
        title: '入住前準備',
        enabled: true,
        appearance: PreArrivalAppearance(
          fontFamily: 'NotoSerifTC',
          colorMode: 'custom',
          accentColor: 0xff466977,
          textColor: 0xff263f47,
          backgroundColor: 0xfff4f7f6,
          cardColor: 0xffffffff,
        ),
      );
      for (final item in preArrivalCatalog.take(6)) {
        guide = togglePreArrivalCatalog(guide, item, true);
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'jfOpenHuninn',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff4b5c96),
            ),
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('入住前準備')),
            body: RepaintBoundary(
              key: boundary,
              child: StatefulBuilder(
                builder: (context, update) => PreArrivalWorkspace(
                  editor: ColoredBox(
                    color: const Color(0xFFFFF8EE),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        PreArrivalStylePicker(
                          value: guide.style,
                          onChanged: (v) =>
                              update(() => guide = guide.copyWith(style: v)),
                        ),
                        const SizedBox(height: 16),
                        PreArrivalAppearanceEditor(
                          guide: guide,
                          onChanged: (v) => update(() => guide = v),
                        ),
                        const SizedBox(height: 16),
                        PreArrivalCatalogPicker(
                          guide: guide,
                          onChanged: (v) => update(() => guide = v),
                        ),
                      ],
                    ),
                  ),
                  preview: PreArrivalGuidePage(guide: guide, embedded: true),
                  onFullscreen: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('整頁字體與顏色'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      await tester.pumpAndSettle();
      expect(find.text('客戶即時預覽'), findsOneWidget);
      expect(find.text('更多選擇'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final path = Platform.environment['PRE_ARRIVAL_CAPTURE_DIR'];
      if (path != null) {
        await tester.runAsync(() async {
          await Directory(path).create(recursive: true);
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$path/pre-arrival-options-desktop.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}
