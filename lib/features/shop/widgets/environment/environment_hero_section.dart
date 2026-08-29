// lib/features/shop/widgets/environment/environment_hero_section.dart
// 🐾 環境介紹 Hero 區塊
// 顯示大圖 Banner + 主標題 + 副標題

import 'package:flutter/material.dart';

class EnvironmentHeroSection extends StatelessWidget {
  const EnvironmentHeroSection({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.height = 260,
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.center,
    this.imageBuilder,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final double height;
  final BoxFit imageFit;
  final Alignment imageAlignment;

  /// 舊呼叫端仍可傳入；實際顯示以 [imageFit] / [imageAlignment] 為準。
  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  })? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final bool compact = height <= 220;
    final double titleSize = compact ? 20 : 25;
    final double subtitleSize = compact ? 12 : 14;
    final double bottomPad = compact ? 14 : 22;
    final double sidePad = compact ? 16 : 22;
    final double titleGap = compact ? 6 : 10;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                        (BuildContext context, Widget child, ImageChunkEvent? progress) {
                      if (progress == null) {
                        return child;
                      }
                      return _placeholder();
                    },
                    errorBuilder:
                        (BuildContext context, Object error, StackTrace? stackTrace) {
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
                  colors: [
                    Color(0x0D000000),
                    Color(0x8C000000),
                  ],
                ),
              ),
            ),
            Positioned(
              left: sidePad,
              right: sidePad,
              bottom: bottomPad,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleSize,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: titleGap),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: Colors.white,
                    ),
                  ),
                ],
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
