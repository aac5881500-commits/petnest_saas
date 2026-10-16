// 檔案名稱：test/home_poster_compose_confirm_test.dart
// 功能說明：海報文字在不同畫布維持同一比例，確認視窗顯示的就是要上傳的 JPEG。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/services/store_banner_render_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_banner_editor_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('編輯器像素與 1600×900 使用同一高度比例', () {
    const double editorPx = 10;
    final double preview = StoreBannerFontSizes.scaleEditorPx(
      editorPx,
      StoreBannerFontSizes.editorReferenceHeight,
    );
    final double output = StoreBannerFontSizes.scaleEditorPx(editorPx, 900);
    expect(preview, closeTo(editorPx, 0.001));
    expect(
      output / 900,
      closeTo(preview / StoreBannerFontSizes.editorReferenceHeight, 0.0001),
    );
    expect(output, greaterThan(preview));
    expect(StoreBannerFontSizes.scaleDesign(104, 900), closeTo(104, 0.001));
    expect(
      StoreBannerFontSizes.scaleDesign(104, 236.25) /
          StoreBannerFontSizes.scaleDesign(104, 900),
      closeTo(236.25 / 900, 0.0001),
    );
  });

  test('比例不同的來源置中，不拉成另一個長寬比', () {
    final img.Image square = img.Image(width: 20, height: 20);
    img.fill(square, color: img.ColorRgb8(10, 20, 30));
    final img.Image canvas = StoreBannerRenderService.fitHomeCanvas(square);
    expect(canvas.width, 1600);
    expect(canvas.height, 900);
    expect(canvas.getPixel(0, 0).r.toInt(), 255);
    expect(canvas.getPixel(800, 450).r.toInt(), 10);

    final img.Image wide = img.Image(width: 32, height: 18);
    img.fill(wide, color: img.ColorRgb8(4, 5, 6));
    final img.Image fitted = StoreBannerRenderService.fitHomeCanvas(wide);
    expect(fitted.width, 1600);
    expect(fitted.height, 900);
    expect(fitted.getPixel(0, 0).r.toInt(), 4);
    expect(fitted.getPixel(1599, 899).r.toInt(), 4);
  });

  test('改文字後簽名不同，未改則與確認時同一份', () {
    const StoreBannerModel banner = StoreBannerModel(
      id: 'poster',
      title: '主標題',
      subtitle: '副標題',
      ctaText: '預約',
    );
    expect(
      posterComposeSignature(banner),
      posterComposeSignature(banner.copyWith(ctaText: '預約')),
    );
    expect(
      posterComposeSignature(banner),
      isNot(posterComposeSignature(banner.copyWith(title: '已修改'))),
    );
  });

  testWidgets('外層很窄時合成畫布仍是 1600×900', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              const SizedBox(width: 280, height: 160),
              Positioned(
                left: -4000,
                top: 0,
                child: HomePosterCaptureFrame(
                  child: RepaintBoundary(
                    key: key,
                    child: const ColoredBox(color: Color(0xFF224466)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byKey(key)), const Size(1600, 900));
  });

  testWidgets('左上與右下文字在預覽和 1600×900 的比例一致', (WidgetTester tester) async {
    final StoreBannerModel banner = _poster();
    final _PosterSample preview = await _sample(tester, banner, 420);
    final _PosterSample output = await _sample(tester, banner, 1600);

    expect(preview.aspect, closeTo(16 / 9, 0.02));
    expect(output.aspect, closeTo(16 / 9, 0.02));
    expect(output.width, 1600);
    expect(output.height, closeTo(900, 1));
    expect(preview.titleFraction.dx, closeTo(output.titleFraction.dx, 0.02));
    expect(preview.titleFraction.dy, closeTo(output.titleFraction.dy, 0.02));
    expect(
      preview.subtitleFraction.dx,
      closeTo(output.subtitleFraction.dx, 0.02),
    );
    expect(
      preview.subtitleFraction.dy,
      closeTo(output.subtitleFraction.dy, 0.02),
    );
    expect(
      preview.titleFont / preview.height,
      closeTo(output.titleFont / output.height, 0.001),
    );
    expect(
      preview.subtitleFont / preview.height,
      closeTo(output.subtitleFont / output.height, 0.001),
    );
    expect(
      preview.titlePadding / preview.height,
      closeTo(output.titlePadding / output.height, 0.002),
    );
    expect(preview.imageAlignment, output.imageAlignment);
    expect(preview.imageScale, closeTo(output.imageScale, 0.001));
    expect(preview.titleWeight, output.titleWeight);
    expect(preview.titleColor, output.titleColor);
    expect(preview.titleMaxLines, output.titleMaxLines);
    expect(preview.titleHeight, output.titleHeight);
  });

  testWidgets('確認視窗顯示同一張 JPEG，返回修改不上傳', (WidgetTester tester) async {
    final Uint8List jpeg = _jpeg();
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return HomePosterConfirmDialog(jpegBytes: jpeg);
                    },
                  );
                },
                child: const Text('開啟'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(find.text('確認海報成品'), findsOneWidget);
    expect(find.text('請確認文字、圖片及排版是否正確。確認後將使用這張完整圖片發布。'), findsOneWidget);
    final Image image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
    expect(identical((image.image as MemoryImage).bytes, jpeg), isTrue);
    expect(find.byType(StoreBannerView), findsNothing);

    await tester.tap(find.text('返回修改'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('確認海報成品'), findsNothing);
  });

  testWidgets('確認並發布回傳這張 JPEG，且桌機與手機都不溢出', (WidgetTester tester) async {
    Future<void> open(Size size) async {
      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final Uint8List jpeg = _jpeg();
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return HomePosterConfirmDialog(jpegBytes: jpeg);
                      },
                    );
                  },
                  child: const Text('開啟'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('開啟'));
      await tester.pumpAndSettle();
      expect(find.text('確認並發布'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final Image image = tester.widget<Image>(find.byType(Image));
      expect(identical((image.image as MemoryImage).bytes, jpeg), isTrue);
      await tester.tap(find.text('確認並發布'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    }

    await open(const Size(1100, 800));
    await open(const Size(390, 780));
    await tester.binding.setSurfaceSize(null);
  });
}

StoreBannerModel _poster() {
  return StoreBannerModel(
    id: 'poster',
    contentMode: StoreBannerContentModes.templateOverlay,
    imageUrl: 'https://example.com/poster.jpg',
    imageScale: 1.35,
    imageAlignmentX: 0.15,
    imageAlignmentY: 0.8,
    overlayMode: StoreBannerOverlayModes.left,
    ctaEnabled: false,
    textElements: <StoreBannerTextElement>[
      StoreBannerTextElement(
        id: 'title',
        text: '左上主標題',
        positionX: 0.08,
        positionY: 0.1,
        fontSize: 96,
        fontSizePreset: StoreBannerFontSizes.display,
        fontWeightPreset: StoreBannerFontWeights.extraBold,
        textColor: StoreBannerCommonColors.white,
        textAlign: 'left',
        backgroundEnabled: true,
        backgroundStyle: StoreBannerTextBgStyles.rounded,
        paddingPreset: StoreBannerTextPaddings.standard,
        maxWidthPreset: StoreBannerTextWidthPresets.narrow,
      ),
      StoreBannerTextElement(
        id: 'subtitle',
        text: '右下副標換行\n第二行',
        positionX: 0.5,
        positionY: 0.62,
        fontSize: 36,
        fontSizePreset: StoreBannerFontSizes.body,
        fontWeightPreset: StoreBannerFontWeights.medium,
        textColor: StoreBannerCommonColors.orange,
        textAlign: 'right',
        backgroundEnabled: true,
        backgroundStyle: StoreBannerTextBgStyles.square,
        paddingPreset: StoreBannerTextPaddings.roomy,
        maxWidthPreset: StoreBannerTextWidthPresets.wide,
      ),
    ],
  );
}

Future<_PosterSample> _sample(
  WidgetTester tester,
  StoreBannerModel banner,
  double width,
) async {
  await tester.binding.setSurfaceSize(Size(width + 40, width));
  tester.view.physicalSize = Size(width + 40, width);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: StoreBannerView(
              banner: banner,
              theme: HomeThemeModel.modernDefault,
              scope: PetNestBannerScope.home,
              composeLive: true,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final Size bannerSize = tester.getSize(find.byType(StoreBannerView));
  Offset fraction(String text) {
    final RenderBox box = tester.renderObject<RenderBox>(find.text(text));
    final RenderBox root = tester.renderObject<RenderBox>(
      find.byType(StoreBannerView),
    );
    final Offset delta =
        box.localToGlobal(Offset.zero) - root.localToGlobal(Offset.zero);
    return Offset(delta.dx / root.size.width, delta.dy / root.size.height);
  }

  final Text title = tester.widget<Text>(find.text('左上主標題'));
  final Text subtitle = tester.widget<Text>(find.text('右下副標換行\n第二行'));
  final Padding titlePad = tester.widget<Padding>(
    find.ancestor(of: find.text('左上主標題'), matching: find.byType(Padding)).first,
  );
  final Transform image = tester.widget<Transform>(
    find.byType(Transform).first,
  );
  return _PosterSample(
    width: bannerSize.width,
    height: bannerSize.height,
    titleFraction: fraction('左上主標題'),
    subtitleFraction: fraction('右下副標換行\n第二行'),
    titleFont: title.style!.fontSize!,
    subtitleFont: subtitle.style!.fontSize!,
    titlePadding: titlePad.padding.resolve(TextDirection.ltr).vertical,
    imageAlignment: image.alignment as Alignment,
    imageScale: image.transform.getMaxScaleOnAxis(),
    titleWeight: title.style!.fontWeight!,
    titleColor: title.style!.color!,
    titleMaxLines: title.maxLines!,
    titleHeight: title.style!.height!,
  );
}

Uint8List _jpeg() {
  final img.Image picture = img.Image(width: 32, height: 18);
  img.fill(picture, color: img.ColorRgb8(210, 120, 40));
  return Uint8List.fromList(img.encodeJpg(picture, quality: 80));
}

class _PosterSample {
  const _PosterSample({
    required this.width,
    required this.height,
    required this.titleFraction,
    required this.subtitleFraction,
    required this.titleFont,
    required this.subtitleFont,
    required this.titlePadding,
    required this.imageAlignment,
    required this.imageScale,
    required this.titleWeight,
    required this.titleColor,
    required this.titleMaxLines,
    required this.titleHeight,
  });

  final double width;
  final double height;
  final Offset titleFraction;
  final Offset subtitleFraction;
  final double titleFont;
  final double subtitleFont;
  final double titlePadding;
  final Alignment imageAlignment;
  final double imageScale;
  final FontWeight titleWeight;
  final Color titleColor;
  final int titleMaxLines;
  final double titleHeight;

  double get aspect => width / height;
}
