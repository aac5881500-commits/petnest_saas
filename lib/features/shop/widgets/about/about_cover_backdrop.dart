// lib/features/shop/widgets/about/about_cover_backdrop.dart
// 關於我們封面底圖：店家自訂圖優先，否則使用系統預設 asset。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_cover_frame_setting.dart';

class AboutCoverBackdrop extends StatelessWidget {
  const AboutCoverBackdrop({
    super.key,
    required this.shopImageUrl,
    required this.frame,
  });

  final String shopImageUrl;
  final AboutCoverFrameSetting frame;

  bool get hasShopImage => shopImageUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (hasShopImage) {
      return Image.network(
        shopImageUrl.trim(),
        fit: frame.boxFit,
        alignment: frame.alignment,
        width: double.infinity,
        height: double.infinity,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
          return _DefaultCover(frame: frame);
        },
      );
    }

    return _DefaultCover(frame: frame);
  }
}

class _DefaultCover extends StatelessWidget {
  const _DefaultCover({required this.frame});

  final AboutCoverFrameSetting frame;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AboutCoverFrameSetting.defaultAssetPath,
      fit: frame.boxFit,
      alignment: frame.alignment,
      width: double.infinity,
      height: double.infinity,
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
        return const ColoredBox(color: Color(0xFF2A1B12));
      },
    );
  }
}
