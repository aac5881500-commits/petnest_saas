import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_style_picker.dart';

void main() {
  testWidgets(
    'new optional items have heading and semantic artwork in all customer skins',
    (tester) async {
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
      await tester.binding.setSurfaceSize(const Size(1000, 1800));
      var guide = const PreArrivalGuideModel(
        shopId: '',
        serviceType: 'accommodation',
        title: '入住前準備',
      );
      for (final item in preArrivalCatalog.where(
        (i) => [
          'cold-food',
          'allergy-note',
          'supplements',
          'own-litter',
          'own-bowl',
          'bedding',
        ].contains(i.id),
      )) {
        guide = togglePreArrivalCatalog(guide, item, true);
      }
      for (final style in ['packing', 'timeline', 'minimal', 'classic']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'jfOpenHuninn'),
            home: RepaintBoundary(
              key: const ValueKey('items-capture'),
              child: PreArrivalGuidePage(
                key: ValueKey(style),
                guide: guide.copyWith(style: style),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('items-capture')),
        );
        await tester.runAsync(() async {
          final picture = await boundary.toImage(pixelRatio: 1);
          final data = await picture.toByteData(format: ui.ImageByteFormat.png);
          await Directory(
            'build/pre_arrival_item_previews',
          ).create(recursive: true);
          await File(
            'build/pre_arrival_item_previews/$style.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          picture.dispose();
        });
      }
    },
  );
}
