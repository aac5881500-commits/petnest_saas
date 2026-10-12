// 檔案名稱：lib/features/shop/widgets/modern_home/shop_modern_logo.dart
// 功能說明：新版 Beta 共用店家 Logo。
// 1. Logo 完整等比例顯示，不裁切、不變形。
// 2. 移除額外背景色，與首頁背景自然融合。
// 3. 保留圖片載入、錯誤圖示、尺寸及圓角設定。

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
        child: url.isEmpty
            ? _FallbackIcon(color: primaryColor, size: iconSize)
            : Image.network(
                url,
                width: size,
                height: size,

                // 完整顯示圖片，不再裁切。
                fit: BoxFit.contain,
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

                      // 載入期間不額外加背景色。
                      return Center(
                        child: SizedBox(
                          width: size * 0.28,
                          height: size * 0.28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
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
                      return _FallbackIcon(color: primaryColor, size: iconSize);
                    },
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
