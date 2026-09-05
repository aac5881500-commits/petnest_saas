// 檔案名稱：lib/features/shop/widgets/modern_home/shop_modern_logo.dart
// 功能說明：新版 Beta 共用店家 Logo：固定正方形、cover、失敗顯示圖示。

import 'package:flutter/material.dart';

class ShopModernLogo extends StatelessWidget {
  const ShopModernLogo({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.primaryColor,
    this.borderRadius = 12,
  });

  final String imageUrl;
  final double size;
  final Color primaryColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl.trim();
    final double iconSize = size * 0.46;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: ColoredBox(
          color: primaryColor.withValues(alpha: 0.10),
          child: url.isEmpty
              ? _FallbackIcon(color: primaryColor, size: iconSize)
              : Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                  loadingBuilder:
                      (
                        BuildContext context,
                        Widget child,
                        ImageChunkEvent? progress,
                      ) {
                        if (progress == null) {
                          return child;
                        }
                        return ColoredBox(
                          color: primaryColor.withValues(alpha: 0.08),
                          child: Center(
                            child: SizedBox(
                              width: size * 0.28,
                              height: size * 0.28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        );
                      },
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return _FallbackIcon(
                          color: primaryColor,
                          size: iconSize,
                        );
                      },
                ),
        ),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.pets_rounded, color: color, size: size),
    );
  }
}
