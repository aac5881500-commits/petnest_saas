import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/services/fixed_aspect_crop_math.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_aspect_image_crop_page.dart';

Uint8List _jpegBytes({required int width, required int height}) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(40, 120, 80));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

void main() {
  group('FixedAspectCropMath', () {
    const List<FixedImageSpec> specs = FixedImageSpec.allCropped;

    test('各固定比例 viewport 可由橫圖與直圖 cover', () {
      for (final FixedImageSpec spec in specs) {
        final Size viewport = Size(
          spec.aspectWidth.toDouble() * 10,
          spec.aspectHeight.toDouble() * 10,
        );
        final Size landscape = Size(viewport.width * 2, viewport.height);
        final Size portrait = Size(viewport.width, viewport.height * 2);

        for (final Size image in <Size>[landscape, portrait]) {
          final ClampedCropTransform cover = FixedAspectCropMath.initialCover(
            image: image,
            viewport: viewport,
          );
          expect(
            FixedAspectCropMath.imageCoversViewport(
              image: image,
              viewport: viewport,
              scale: cover.scale,
              tx: cover.tx,
              ty: cover.ty,
            ),
            isTrue,
            reason: '${spec.id} ${image.width}x${image.height}',
          );
          final Rect crop = FixedAspectCropMath.cropRectInImage(
            image: image,
            viewport: viewport,
            scale: cover.scale,
            tx: cover.tx,
            ty: cover.ty,
          );
          expect(crop.width / crop.height, closeTo(spec.cropAspectRatio, 0.02));
        }
      }
    });

    test('拖曳不得露出裁切框外空白', () {
      const Size image = Size(400, 200);
      const Size viewport = Size(160, 90);
      final ClampedCropTransform cover = FixedAspectCropMath.initialCover(
        image: image,
        viewport: viewport,
      );
      final ClampedCropTransform panned = FixedAspectCropMath.clampTransform(
        image: image,
        viewport: viewport,
        scale: cover.scale,
        tx: 80,
        ty: 80,
      );
      expect(
        FixedAspectCropMath.imageCoversViewport(
          image: image,
          viewport: viewport,
          scale: panned.scale,
          tx: panned.tx,
          ty: panned.ty,
        ),
        isTrue,
      );
      expect(panned.tx, lessThanOrEqualTo(0));
      expect(panned.ty, lessThanOrEqualTo(0));
    });

    test('最小為 cover、最大為 cover × 4', () {
      const Size image = Size(800, 400);
      const Size viewport = Size(160, 80);
      final double cover = FixedAspectCropMath.coverScale(
        image: image,
        viewport: viewport,
      );
      final ClampedCropTransform tooSmall = FixedAspectCropMath.clampTransform(
        image: image,
        viewport: viewport,
        scale: cover * 0.2,
        tx: 0,
        ty: 0,
      );
      expect(tooSmall.scale, closeTo(cover, 0.0001));
      final ClampedCropTransform tooLarge = FixedAspectCropMath.clampTransform(
        image: image,
        viewport: viewport,
        scale: cover * 20,
        tx: 0,
        ty: 0,
      );
      expect(
        tooLarge.scale,
        closeTo(cover * FixedAspectCropMath.maxZoomMultiplier, 0.0001),
      );
    });
  });

  testWidgets('取消裁切不回傳圖片', (WidgetTester tester) async {
    Uint8List? popped = Uint8List.fromList(<int>[1]);
    final Uint8List bytes = _jpegBytes(width: 200, height: 120);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute<Uint8List>(
                    builder: (_) => FixedAspectImageCropPage(
                      imageBytes: bytes,
                      cropAspectRatio: 16 / 9,
                      outputWidth: 160,
                      outputHeight: 90,
                    ),
                  ),
                );
              },
              child: const Text('go'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(popped, isNull);
  });

  test('內容型照片入口未接入強制裁切', () {
    const List<String> paths = <String>[
      'lib/features/shop/widgets/chat/shop_chat_composer.dart',
      'lib/features/booking/pages/booking_review_page.dart',
      'lib/features/room/pages/daily_care_record_edit_page.dart',
      'lib/features/shop/pages/shop_pre_arrival_guide_setting_page.dart',
    ];
    for (final String path in paths) {
      final String source = File(path).readAsStringSync();
      expect(
        source.contains('FixedAspectImageCropPage'),
        isFalse,
        reason: path,
      );
      expect(source.contains('FixedImagePickFlow'), isFalse, reason: path);
      expect(source.contains('BannerImageCropPage'), isFalse, reason: path);
    }
  });
}
