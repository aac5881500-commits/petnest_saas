// 檔案名稱：lib/features/shop/widgets/environment/environment_image_banner.dart
// 功能說明：環境介紹中間橫幅圖
// 顯示一張大圖 + 覆蓋文字

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:petnest_saas/core/models/environment_page_appearance.dart';

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
    this.titleColor,
  });

  final String imageUrl;
  final String title;
  final double height;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  final double? titleSize;
  final double radius;
  final double horizontalMargin;
  final Color? titleColor;

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
    final panel = (titleColor?.computeLuminance() ?? 1) > .179
        ? Colors.black87
        : Colors.white.withValues(alpha: .92);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter =
            TextPainter(
              text: TextSpan(
                text: title,
                style: TextStyle(
                  fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                  fontSize: resolvedTitleSize,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(
              maxWidth: math.max(
                1,
                constraints.maxWidth - horizontalMargin * 2 - 52,
              ),
            );
        final textHeight = painter.height;
        painter.dispose();
        return Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          height: math.max(height, textHeight + 40),
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
                    child: Container(
                      padding: titleColor != null
                          ? const EdgeInsets.all(8)
                          : EdgeInsets.zero,
                      color: titleColor != null ? panel : null,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: resolvedTitleSize,
                          height: 1.3,
                          fontWeight: FontWeight.w900,
                          color: titleColor == null
                              ? Colors.white
                              : EnvironmentPageAppearance.readable(
                                  titleColor!,
                                  panel,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
