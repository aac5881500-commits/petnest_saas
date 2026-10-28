import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/pet_service_module.dart';
import 'package:petnest_saas/features/shop/pages/services/shop_service_module_hub.dart';
import 'package:petnest_saas/features/shop/widgets/services/pet_service_overview.dart';
import '../tool/service_modules_fixture.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'jfOpenHuninn',
    )..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final module in PetServiceModule.all) {
    for (final size in [const Size(390, 1000), const Size(1440, 1000)]) {
      testWidgets(
        '${module.id} reference groups and navigation at ${size.width}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = ServiceModulesFixture();
          addTearDown(repo.changes.close);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                fontFamily: 'jfOpenHuninn',
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff50609a),
                ),
              ),
              home: Scaffold(
                body: RepaintBoundary(
                  key: boundary,
                  child: ShopServiceModuleHub(
                    shopId: 'fixture',
                    module: module,
                    canConfigure: true,
                    canManage: true,
                    repository: repo,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('今日營運'), findsOneWidget);
          expect(find.text('規則與紀錄'), findsOneWidget);
          final today = find.byKey(const ValueKey('service-today-section'));
          final cards = find.descendant(
            of: today,
            matching: find.byType(PetServiceMenuTile),
          );
          expect(cards, findsNWidgets(3));
          if (size.width > 1000) {
            final a = tester.getRect(cards.at(0)),
                b = tester.getRect(cards.at(1)),
                c = tester.getRect(cards.at(2));
            expect(a.top, closeTo(b.top, 1));
            expect(b.top, closeTo(c.top, 1));
            expect(a.width, closeTo(b.width, 1));
            final left = tester.getRect(
              find.byKey(const ValueKey('service-settings-section')),
            );
            final right = tester.getRect(
              find.byKey(const ValueKey('service-records-section')),
            );
            expect(left.right, lessThan(right.left));
            expect(left.top, closeTo(right.top, 1));
            expect(left.width, greaterThan(right.width));
            expect(left.left, greaterThanOrEqualTo(80));
          }
          expect(tester.takeException(), isNull);
          if (module.id == 'grooming' && size.width > 1000) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'C:/Users/aac58/OneDrive/文件/ChatGPT/貓咪旅店專案/review-work/service-module-layout/grooming-layout.png',
              ).writeAsBytes(png!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.ensureVisible(
            find.byKey(const ValueKey('service-menu-catalogue')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('service-menu-catalogue')),
          );
          await tester.pumpAndSettle();
          expect(find.text('新增項目'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
