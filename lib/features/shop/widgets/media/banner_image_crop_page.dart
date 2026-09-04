// lib/features/shop/widgets/media/banner_image_crop_page.dart
// 相容包裝：既有呼叫改走共用固定比例裁切器。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_aspect_image_crop_page.dart';

class BannerImageCropPage extends StatelessWidget {
  const BannerImageCropPage({
    super.key,
    required this.imageBytes,
    this.cropAspectRatio = aspectRatio,
    this.outputWidth = 1600,
    this.outputHeight = 900,
    this.hintText = '框內區域就是前台活動海報主要顯示範圍。可拖曳、縮放圖片來選擇實際要顯示的內容。',
  });

  final Uint8List imageBytes;
  final double cropAspectRatio;
  final int outputWidth;
  final int outputHeight;
  final String hintText;

  static const double aspectRatio = 16 / 9;
  static const int jpegQuality = FixedAspectImageCropPage.jpegQuality;

  static Future<Uint8List?> open({
    required BuildContext context,
    required Uint8List imageBytes,
    double cropAspectRatio = aspectRatio,
    int outputWidth = 1600,
    int outputHeight = 900,
    String hintText = '框內區域就是前台活動海報主要顯示範圍。可拖曳、縮放圖片來選擇實際要顯示的內容。',
  }) {
    return FixedAspectImageCropPage.open(
      context: context,
      imageBytes: imageBytes,
      cropAspectRatio: cropAspectRatio,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      hintText: hintText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FixedAspectImageCropPage(
      imageBytes: imageBytes,
      cropAspectRatio: cropAspectRatio,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      hintText: hintText,
    );
  }
}
