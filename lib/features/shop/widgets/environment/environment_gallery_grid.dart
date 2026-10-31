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
    this.captions = const [],
    this.layout = 'grid',
  });

  final List<String> images, captions;
  final String layout;
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
          Widget tile(int index) {
            final caption = index < captions.length ? captions[index] : '';
            return InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => Dialog(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: InteractiveViewer(
                          child: imageBuilder(
                            imageUrl: images[index],
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      if (caption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(caption),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('關閉'),
                      ),
                    ],
                  ),
                ),
              ),
              child: Semantics(
                label: caption.isEmpty ? '放大環境照片 ${index + 1}' : caption,
                button: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageBuilder(imageUrl: images[index], fit: BoxFit.cover),
                      if (caption.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withValues(alpha: .65),
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (layout == 'mosaic' && images.length >= 3) {
            final height = (constraints.maxWidth / 2).clamp(180.0, 400.0);
            return Column(
              children: [
                for (var index = 0; index < images.length; index += 3)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: SizedBox(
                      height: height,
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: tile(index)),
                          if (index + 1 < images.length) ...[
                            SizedBox(width: spacing),
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(child: tile(index + 1)),
                                  if (index + 2 < images.length) ...[
                                    SizedBox(height: spacing),
                                    Expanded(child: tile(index + 2)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }
          return GridView.builder(
            itemCount: images.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: layout == 'single'
                  ? 1
                  : columns.clamp(1, images.length),
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: layout == 'single'
                  ? constraints.maxWidth /
                        (constraints.maxWidth / (4 / 3)).clamp(100.0, 400.0)
                  : 4 / 3,
            ),
            itemBuilder: (context, index) => tile(index),
          );
        },
      ),
    );
  }
}
