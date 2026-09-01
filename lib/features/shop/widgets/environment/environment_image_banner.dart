// lib/features/shop/widgets/environment/environment_image_banner.dart
// 🐾 環境介紹中間橫幅圖
// 顯示一張大圖 + 覆蓋文字

import 'package:flutter/material.dart';

class EnvironmentImageBanner extends StatelessWidget {
  const EnvironmentImageBanner({
    super.key,
    required this.imageUrl,
    required this.title,
    this.height = 150,
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.center,
    this.titleSize,
    this.radius = 22,
    this.horizontalMargin = 16,
    this.imageBuilder,
  });

  final String imageUrl;
  final String title;
  final double height;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  final double? titleSize;
  final double radius;
  final double horizontalMargin;

  /// 舊呼叫端仍可傳入；實際顯示以 [imageFit] / [imageAlignment] 為準。
  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  })?
  imageBuilder;

  @override
  Widget build(BuildContext context) {
    final bool compact = height <= 130;
    final double resolvedTitleSize = titleSize ?? (compact ? 16 : 20);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            imageUrl.trim().isEmpty
                ? _placeholder()
                : Image.network(
                    imageUrl,
                    fit: imageFit,
                    alignment: imageAlignment,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder:
                        (
                          BuildContext context,
                          Widget child,
                          ImageChunkEvent? progress,
                        ) {
                          if (progress == null) {
                            return child;
                          }
                          return _placeholder();
                        },
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          if (imageBuilder != null) {
                            return imageBuilder!(
                              imageUrl: imageUrl,
                              fit: imageFit,
                            );
                          }
                          return _placeholder();
                        },
                  ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
            Positioned(
              left: compact ? 14 : 18,
              right: compact ? 14 : 18,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: resolvedTitleSize,
                    height: 1.3,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const ColoredBox(
      color: Color(0xFFF5EBDD),
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: Color(0xFFB87535),
        ),
      ),
    );
  }
}
