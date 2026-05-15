// lib/features/shop/widgets/environment/environment_image_upload_box.dart
// 🖼️ 後台環境介紹單張圖片上傳區塊

import 'package:flutter/material.dart';

class EnvironmentImageUploadBox extends StatelessWidget {
  const EnvironmentImageUploadBox({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.uploading,
    required this.onUpload,
  });

  final String title;
  final String imageUrl;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF3A2A1A),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 150,
            width: double.infinity,
            color: const Color(0xFFF5EBDD),
            child: imageUrl.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.image_rounded,
                      size: 42,
                      color: Color(0xFFB87535),
                    ),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          size: 42,
                          color: Color(0xFFB87535),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: uploading ? null : onUpload,
            icon: uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_rounded),
            label: Text(uploading ? '圖片上傳中...' : '上傳$title'),
          ),
        ),
      ],
    );
  }
}