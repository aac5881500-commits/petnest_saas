// lib/features/shop/widgets/environment/environment_gallery_manager.dart
// 🖼️ 後台環境照片牆管理區塊

import 'package:flutter/material.dart';

class EnvironmentGalleryManager extends StatelessWidget {
  const EnvironmentGalleryManager({
    super.key,
    required this.images,
    required this.onDelete,
    required this.onUpload,
    this.busy = false,
  });

  final List<String> images;
  final Future<void> Function(int index) onDelete;
  final VoidCallback onUpload;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bool canAdd = images.length < 12;
    final int itemCount = images.length + (canAdd ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '建議使用橫式照片，4:3 或 16:9 效果最佳。',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Color(0xFF8A6A45),
          ),
        ),
        const Text(
          '建議尺寸：1600 × 1200 或 1600 × 900。最低建議：1200 × 900。',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Color(0xFF8A6A45),
          ),
        ),
        const Text(
          '單張最大 5 MB，支援 JPG、PNG、WEBP。系統會自動壓縮圖片，建議上傳清晰原圖。',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Color(0xFF8A6A45),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount == 0 ? 1 : itemCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 4 / 3,
          ),
          itemBuilder: (BuildContext context, int index) {
            final bool isAddTile = index >= images.length;
            if (isAddTile) {
              return _AddTile(
                enabled: !busy && canAdd,
                onTap: onUpload,
              );
            }

            return _GalleryThumb(
              imageUrl: images[index],
              enabled: !busy,
              onDelete: () => onDelete(index),
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: busy || images.length >= 12 ? null : onUpload,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: Text(
              images.length >= 12
                  ? '已達 12 張上限'
                  : '上傳環境照片 (${images.length}/12)',
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({
    required this.imageUrl,
    required this.enabled,
    required this.onDelete,
  });

  final String imageUrl;
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFFF5EBDD),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Color(0xFFB87535),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? onDelete : null,
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFCF7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0E0CC)),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Color(0xFFB87535)),
                SizedBox(height: 4),
                Text(
                  '新增',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A6A45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
