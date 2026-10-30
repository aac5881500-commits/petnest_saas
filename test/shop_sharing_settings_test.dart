import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/shop_sharing_settings.dart';

Map<String, dynamic> settings({bool enabled = true, String code = ''}) => {
  'enabled': enabled,
  'qrToken': List.filled(48, 'a').join(),
  'searchCode': code,
};

Future<void> showSettings(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1,
  required ShopSharingRequest manage,
  GlobalKey? previewKey,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1250));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.runAsync(() async {
    final sans = FontLoader('NotoSansTC')
      ..addFont(
        rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
      );
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([sans.load(), icons.load()]);
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: PetNestAppTheme.build().copyWith(
        textTheme: PetNestAppTheme.build().textTheme.apply(
          fontFamily: 'NotoSansTC',
        ),
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1250),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF6F7FC),
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: previewKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ShopSharingSettings(
                  shopId: 'SHOP0018',
                  manageSharing: manage,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'sharing actions come first; search editor and destructive actions stay collapsed',
    (tester) async {
      await showSettings(tester, manage: (_, _) async => settings());
      expect(find.text('分享 QR 圖片'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('更換 QR Code'), findsNothing);
      expect(
        tester.getTopLeft(find.text('分享 QR 圖片')).dy,
        lessThan(tester.getTopLeft(find.text('手機 APP 搜尋碼')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search code edits are validated and explicitly saved', (
    tester,
  ) async {
    final calls = <String>[];
    var saved = settings();
    await showSettings(
      tester,
      manage: (action, code) async {
        calls.add(action);
        if (action == 'save') saved = settings(code: code);
        return saved;
      },
    );
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'short');
    await tester.tap(find.text('儲存搜尋碼'));
    await tester.pumpAndSettle();
    expect(calls, ['get']);
    expect(find.textContaining('不要使用 SHOP 流水號'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'cat_home_2026');
    await tester.tap(find.text('儲存搜尋碼'));
    await tester.pumpAndSettle();
    expect(calls, ['get', 'save']);
    expect(find.text('CAT_HOME_2026'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('duplicate code keeps input and retry in the editor', (
    tester,
  ) async {
    await showSettings(
      tester,
      manage: (action, _) async {
        if (action == 'save') {
          throw FirebaseFunctionsException(
            code: 'already-exists',
            message: '這組搜尋碼已被使用，請換一組',
          );
        }
        return settings(code: 'ORIGINAL_2026');
      },
    );
    await tester.tap(find.text('修改'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'TAKEN_CODE_2026');
    await tester.tap(find.text('儲存搜尋碼'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'TAKEN_CODE_2026',
    );
    expect(find.text('儲存搜尋碼'), findsOneWidget);
    expect(find.text('ORIGINAL_2026'), findsOneWidget);
  });

  testWidgets(
    'closing or cancelling advanced settings does not disable sharing',
    (tester) async {
      final calls = <String>[];
      await showSettings(
        tester,
        manage: (action, _) async {
          calls.add(action);
          return settings();
        },
      );
      await tester.tap(find.text('更多分享設定'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('關閉分享入口'));
      await tester.tap(find.text('關閉分享入口'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(calls, ['get']);
      expect(find.text('客人分享已啟用'), findsOneWidget);
    },
  );

  testWidgets('disabled entry offers a clear create action', (tester) async {
    final calls = <String>[];
    await showSettings(
      tester,
      manage: (action, _) async {
        calls.add(action);
        return settings(enabled: action != 'get');
      },
    );
    expect(find.text('產生專屬 QR Code'), findsOneWidget);
    expect(find.text('分享 QR 圖片'), findsNothing);
    await tester.tap(find.text('產生專屬 QR Code'));
    await tester.pumpAndSettle();
    expect(calls, ['get', 'save']);
    expect(find.text('客人分享已啟用'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets(
      'layout fits width $width with large text and long saved codes',
      (tester) async {
        final key = GlobalKey();
        await showSettings(
          tester,
          width: width,
          textScale: 1.2,
          previewKey: key,
          manage: (_, _) async =>
              settings(code: 'CAT_HOME_2026_PRIVATE_GUEST_12345'),
        );
        expect(tester.takeException(), isNull);
        final output = Platform.environment['SHARING_PREVIEW_DIR'];
        if (output != null) {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory(output).createSync(recursive: true);
            File(
              '$output/sharing-${width.toInt()}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}
