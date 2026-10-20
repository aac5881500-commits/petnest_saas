import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/core/services/stay_booking_readiness.dart';
import 'package:petnest_saas/features/shop/widgets/shop_opening_progress.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_editor.dart';

void main() {
  testWidgets('本機字體的引導與編輯器視覺輸出', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await (FontLoader('NotoSansTC')..addFont(
            rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [390.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      for (final editor in [false, true]) {
        final theme = PetNestAppTheme.build();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'NotoSansTC'),
              appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                  fontFamily: 'NotoSansTC',
                ),
              ),
            ),
            home: RepaintBoundary(
              key: const ValueKey('setup-capture'),
              child: editor
                  ? const ShopRoomTypeEditorPage(
                      shopId: 'local-preview',
                      existing: {
                        'id': 't',
                        'name': '靜謐花園房',
                        'price': 1200,
                        'capacity': 2,
                        'extraPrice': 200,
                        'totalRooms': 3,
                        'description': '獨立舒適的休息空間，讓貓咪安心適應新環境。',
                        'features': ['camera', 'private_space'],
                      },
                    )
                  : Scaffold(
                      appBar: AppBar(title: const Text('店家後台')),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ShopOpeningProgress(
                          key: ValueKey(width),
                          shopId: 'local-preview',
                          userId: 'local-preview',
                          shop: {
                            'bookingEnabled': false,
                            'phoneSetupCompleted': true,
                            'addressSetupCompleted': true,
                            'plan': 'basic',
                            'paidUntil': Timestamp.fromDate(
                              DateTime.now().add(const Duration(days: 30)),
                            ),
                          },
                          readinessStream: Stream.value(
                            StayBookingReadiness([], []),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('setup-capture')),
          );
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/shop_setup_visuals/${editor ? 'editor' : 'opening'}_${width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
