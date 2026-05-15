// lib/features/shop/widgets/environment/environment_gallery_manager.dart
// 🖼️ 後台環境照片牆管理區塊

import 'package:flutter/material.dart';

class EnvironmentGalleryManager extends StatelessWidget {
  const EnvironmentGalleryManager({
    super.key,
    required this.images,
    required this.onDelete,
    required this.onUpload,
  });

  final List<String> images;
  final Function(int index) onDelete;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isEmpty)
          Container(
            height: 120,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0E0CC)),
            ),
            child: const Text(
              '尚未上傳環境照片',
              style: TextStyle(
                color: Color(0xFF8A6A45),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: images.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final imageUrl = images[index];

              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () => onDelete(index),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: images.length >= 12 ? null : onUpload,
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