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
    required this.imageBuilder,
  });

  final String imageUrl;
  final String title;
  final String subtitle;

  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  }) imageBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageBuilder(
              imageUrl: imageUrl,
            ),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 22,
              right: 22,
              bottom: 22,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
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
}