import 'package:petnest_saas/features/shop/widgets/pre_arrival_workspace.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_style_picker.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';

void main() {
  testWidgets('render customer styles with actual bundled Chinese fonts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      for (final entry in {
        'jfOpenHuninn': 'assets/fonts/jf-openhuninn-2.1.ttf',
        'NotoSerifTC': 'assets/fonts/NotoSerifTC-VariableFont_wght.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var guide = const PreArrivalGuideModel(
      shopId: '',
      serviceType: 'accommodation',
      title: '入住前準備',
    );
    for (final item in preArrivalCatalog.where(
      (i) => !['vaccine', 'parasite'].contains(i.id),
    )) {
      guide = togglePreArrivalCatalog(guide, item, true);
    }
    for (final width in [390.0, 1100.0]) {
      await tester.binding.setSurfaceSize(
        Size(width, width == 390 ? 1200 : 1450),
      );
      for (final style in ['packing', 'timeline', 'minimal']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              fontFamily: style == 'minimal' ? 'NotoSerifTC' : 'jfOpenHuninn',
            ),
            home: RepaintBoundary(
              key: const ValueKey('capture'),
              child: PreArrivalGuidePage(
                key: ValueKey('$style-$width'),
                guide: guide.copyWith(style: style),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')),
        );
        await tester.runAsync(() async {
          final picture = await boundary.toImage(pixelRatio: 1);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final output = Directory('build/pre_arrival_previews');
          await output.create(recursive: true);
          await File(
            '${output.path}/$style-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
    }
    await tester.binding.setSurfaceSize(const Size(1680, 1100));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'jfOpenHuninn'),
        home: RepaintBoundary(
          key: const ValueKey('workspace-capture'),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, refresh) => PreArrivalWorkspace(
                editor: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    PreArrivalStylePicker(
                      value: guide.style,
                      onChanged: (style) =>
                          refresh(() => guide = guide.copyWith(style: style)),
                    ),
                    const SizedBox(height: 24),
                    PreArrivalCatalogPicker(
                      guide: guide,
                      onChanged: (updated) => refresh(() => guide = updated),
                    ),
                  ],
                ),
                preview: PreArrivalGuidePage(
                  guide: guide.copyWith(
                    style: guide.style == 'classic' ? 'packing' : guide.style,
                  ),
                  embedded: true,
                ),
                onFullscreen: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final workspace = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('workspace-capture')),
    );
    await tester.runAsync(() async {
      final picture = await workspace.toImage(pixelRatio: 1);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/pre_arrival_previews/workspace-1680.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    await tester.tap(find.byKey(const ValueKey('guide-style-timeline')));
    await tester.pumpAndSettle();
    expect(find.text('出發時間軸'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
