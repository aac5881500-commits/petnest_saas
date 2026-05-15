// lib/features/shop/widgets/environment/environment_gallery_grid.dart
// 🐾 環境介紹照片牆
// 顯示環境照片 Grid，之後可擴充點圖放大、排序、刪除

import 'package:flutter/material.dart';

class EnvironmentGalleryGrid extends StatelessWidget {
  const EnvironmentGalleryGrid({
    super.key,
    required this.images,
    required this.imageBuilder,
  });

  final List<String> images;

  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  }) imageBuilder;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        itemCount: images.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: imageBuilder(
              imageUrl: images[index],
            ),
          );
        },
      ),
    );
  }
}