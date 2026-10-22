// 檔案名稱：lib/features/shop/widgets/environment/environment_hero_section.dart
// 功能說明：環境介紹 Hero 區塊
// 顯示大圖 Banner + 主標題 + 副標題

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:petnest_saas/core/models/environment_page_appearance.dart';

class EnvironmentHeroSection extends StatelessWidget {
  const EnvironmentHeroSection({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.height = 260,
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.center,
    this.titleSize,
    this.subtitleSize,
    this.radius = 24,
    this.horizontalMargin = 16,
    this.imageBuilder,
    this.titleColor,
    this.subtitleColor,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final double height;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  final double? titleSize;
  final double? subtitleSize;
  final double radius;
  final double horizontalMargin;
  final Color? titleColor, subtitleColor;

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
    final bool compact = height <= 220;
    final double resolvedTitleSize = titleSize ?? (compact ? 20 : 25);
    final double resolvedSubtitleSize = subtitleSize ?? (compact ? 12 : 14);
    final double bottomPad = compact ? 14 : 22;
    final double sidePad = compact ? 16 : 22;
    final double titleGap = compact ? 6 : 10;
    final custom = titleColor != null || subtitleColor != null;
    final ink = titleColor ?? subtitleColor ?? Colors.white;
    final panel = ink.computeLuminance() > .179
        ? Colors.black87
        : Colors.white.withValues(alpha: .92);
    return LayoutBuilder(
      builder: (context, constraints) {
        double textHeight(String value, double size, FontWeight weight) {
          final painter =
              TextPainter(
                text: TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                    fontSize: size,
                    fontWeight: weight,
                    height: 1.25,
                  ),
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(
                maxWidth: math.max(
                  1,
                  constraints.maxWidth -
                      horizontalMargin * 2 -
                      sidePad * 2 -
                      (custom ? 16 : 0),
                ),
              );
          final measured = painter.height;
          painter.dispose();
          return measured;
        }

        return Container(
          margin: EdgeInsets.fromLTRB(
            horizontalMargin,
            12,
            horizontalMargin,
            0,
          ),
          height: math.max(
            height,
            textHeight(title, resolvedTitleSize, FontWeight.w900) +
                textHeight(subtitle, resolvedSubtitleSize, FontWeight.normal) +
                titleGap +
                bottomPad * 2 +
                (custom ? 16 : 0),
          ),
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
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x0D000000), Color(0x8C000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: sidePad,
                  right: sidePad,
                  bottom: bottomPad,
                  child: Container(
                    padding: custom ? const EdgeInsets.all(8) : EdgeInsets.zero,
                    color: custom ? panel : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: resolvedTitleSize,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                            color: custom
                                ? EnvironmentPageAppearance.readable(
                                    titleColor ?? Colors.white,
                                    panel,
                                  )
                                : Colors.white,
                          ),
                        ),
                        SizedBox(height: titleGap),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: resolvedSubtitleSize,
                            color: custom
                                ? EnvironmentPageAppearance.readable(
                                    subtitleColor ?? titleColor ?? Colors.white,
                                    panel,
                                  )
                                : Colors.white,
                          ),
                        ),
                      ],
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
