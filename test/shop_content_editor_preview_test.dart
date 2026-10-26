import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/features/shop/widgets/content/shop_content_editor_dialog.dart';

// Widget-test preview uses a bundled Chinese font to make the screenshots
// readable and repeatable. The production app continues to use its own theme.
TextStyle _previewStyle(TextStyle? original, double weight) =>
    (original ?? const TextStyle()).copyWith(
      fontFamily: 'NotoSansTC',
      fontVariations: [ui.FontVariation('wght', weight)],
    );

TextTheme _previewTextTheme(TextTheme original) => original.copyWith(
  displayLarge: _previewStyle(original.displayLarge, 700),
  displayMedium: _previewStyle(original.displayMedium, 700),
  displaySmall: _previewStyle(original.displaySmall, 700),
  headlineLarge: _previewStyle(original.headlineLarge, 700),
  headlineMedium: _previewStyle(original.headlineMedium, 700),
  headlineSmall: _previewStyle(original.headlineSmall, 700),
  titleLarge: _previewStyle(original.titleLarge, 700),
  titleMedium: _previewStyle(original.titleMedium, 600),
  titleSmall: _previewStyle(original.titleSmall, 600),
  bodyLarge: _previewStyle(original.bodyLarge, 400),
  bodyMedium: _previewStyle(original.bodyMedium, 400),
  bodySmall: _previewStyle(original.bodySmall, 400),
  labelLarge: _previewStyle(original.labelLarge, 600),
  labelMedium: _previewStyle(original.labelMedium, 500),
  labelSmall: _previewStyle(original.labelSmall, 500),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final viewport in <String, Size>{
    'phone_320': const Size(320, 800),
    'phone_390': const Size(390, 844),
    'desktop_1280': const Size(1280, 900),
  }.entries) {
    for (final isFaq in [true, false]) {
      final name = '${isFaq ? 'faq' : 'announcement'}_${viewport.key}';
      testWidgets('內容編輯內附字體預覽 $name', (tester) async {
        tester.view.physicalSize = viewport.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          final text = FontLoader('NotoSansTC')
            ..addFont(
              rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
            );
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await Future.wait([text.load(), icons.load()]);
        });
        final capture = GlobalKey();
        final baseTheme = PetNestAppTheme.build();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: baseTheme.copyWith(
                textTheme: _previewTextTheme(baseTheme.textTheme),
                primaryTextTheme: _previewTextTheme(baseTheme.primaryTextTheme),
                appBarTheme: baseTheme.appBarTheme.copyWith(
                  titleTextStyle: _previewStyle(
                    baseTheme.appBarTheme.titleTextStyle,
                    700,
                  ),
                  toolbarTextStyle: _previewStyle(
                    baseTheme.appBarTheme.toolbarTextStyle,
                    400,
                  ),
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: viewport.value,
                  textScaler: TextScaler.noScaling,
                ),
                child: child!,
              ),
              home: Scaffold(
                appBar: AppBar(title: Text(isFaq ? '常見問題管理' : '公告管理')),
                body: Builder(
                  builder: (context) => Center(
                    child: FilledButton(
                      onPressed: () => showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ShopContentEditorDialog(
                          isFaq: isFaq,
                          isNew: false,
                          initial: ShopContentDraft(
                            title: isFaq ? '入住前需要準備哪些物品？' : '春節營業時間與接送提醒',
                            body: isFaq
                                ? '請準備貓咪平常食用的飼料、近期健康紀錄與常用藥品。\n\n若有特殊照護需求，請在入住前與我們聯繫。'
                                : '春節期間照常提供住宿照護服務。接送時段調整為上午十點至下午六點，請提前與我們預約，謝謝您的配合。',
                            isPublished: true,
                            type: 'business_hours',
                          ),
                          onSave: (_) async {},
                        ),
                      ),
                      child: const Text('編輯內容'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('編輯內容'));
        await tester.pumpAndSettle();
        expect(find.byType(ShopContentEditorDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        final save = tester.getRect(find.text('儲存'));
        expect(save.right, lessThanOrEqualTo(viewport.value.width));
        expect(save.bottom, lessThanOrEqualTo(viewport.value.height));
        final output = Platform.environment['PETNEST_CONTENT_PREVIEW'];
        if (output != null && output.trim().isNotEmpty) {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            await Directory(output).create(recursive: true);
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$output/content_$name.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
      });
    }
  }
}
