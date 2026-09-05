// 檔案名稱：lib/features/shop/widgets/environment/environment_gallery_grid.dart
// 功能說明：環境介紹照片牆：手機 2 欄、平板 3 欄，固定比例 cover。

import 'package:flutter/material.dart';

class EnvironmentGalleryGrid extends StatelessWidget {
  const EnvironmentGalleryGrid({
    super.key,
    required this.images,
    required this.imageBuilder,
    this.horizontalPadding = 16,
    this.spacing = 9,
    this.columnsBuilder,
  });

  final List<String> images;
  final double horizontalPadding;
  final double spacing;
  final int Function(double width)? columnsBuilder;

  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  })
  imageBuilder;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = columnsBuilder?.call(constraints.maxWidth) ?? 2;
          return GridView.builder(
            itemCount: images.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: 4 / 3,
            ),
            itemBuilder: (BuildContext context, int index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: imageBuilder(imageUrl: images[index], fit: BoxFit.cover),
              );
            },
          );
        },
      ),
    );
  }
}
