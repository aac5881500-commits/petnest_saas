// lib/features/shop/widgets/environment/environment_image_banner.dart
// 🐾 環境介紹中間橫幅圖
// 顯示一張大圖 + 覆蓋文字

import 'package:flutter/material.dart';

class EnvironmentImageBanner extends StatelessWidget {
  const EnvironmentImageBanner({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.imageBuilder,
  });

  final String imageUrl;
  final String title;

  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  }) imageBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageBuilder(
              imageUrl: imageUrl,
            ),
            Container(
              color: Colors.black.withOpacity(0.28),
            ),
            Positioned(
              left: 18,
              right: 18,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.4,
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
}