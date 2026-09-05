// 檔案名稱：lib/features/shop/widgets/environment/environment_feature_manager.dart
// 功能說明：後台環境特色卡片管理區塊

import 'package:flutter/material.dart';

class EnvironmentFeatureManager extends StatelessWidget {
  const EnvironmentFeatureManager({
    super.key,
    required this.features,
    required this.onAdd,
    required this.onDelete,
    required this.onEdit,
    required this.onChangeIcon,
    required this.onChangeLayout,
    required this.onManageImage,
    this.busy = false,
  });

  final List<Map<String, dynamic>> features;
  final VoidCallback onAdd;
  final Future<void> Function(int index) onDelete;
  final Future<void> Function(int index) onEdit;
  final Future<void> Function(int index) onChangeIcon;
  final Future<void> Function(int index) onChangeLayout;
  final Future<void> Function(int index) onManageImage;
  final bool busy;

  IconData _featureIcon(String key) {
    switch (key) {
      case 'home':
        return Icons.home_rounded;
      case 'clean':
        return Icons.cleaning_services_rounded;
      case 'air':
        return Icons.ac_unit_rounded;
      case 'camera':
        return Icons.videocam_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'sun':
        return Icons.wb_sunny_rounded;
      case 'clean_hand':
        return Icons.clean_hands_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'toys':
        return Icons.toys_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '特色圖片建議使用 4:3 橫式照片。前台版型由上方「環境特色卡片版型」統一控制；沒有圖片時不會留空框。橫向圖卡仍可用右側按鈕切換圖片左右。',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Color(0xFF8A6A45),
          ),
        ),
        const Text(
          '建議尺寸：1200 × 900。最低建議：900 × 675。單張最大 5 MB，支援 JPG、PNG、WEBP。',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Color(0xFF8A6A45),
          ),
        ),
        const SizedBox(height: 12),
        if (features.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0E0CC)),
            ),
            child: const Text(
              '尚未新增環境特色',
              style: TextStyle(
                color: Color(0xFF8A6A45),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...features.asMap().entries.map((
            MapEntry<int, Map<String, dynamic>> entry,
          ) {
            final int index = entry.key;
            final Map<String, dynamic> item = entry.value;
            final String imageUrl = (item['imageUrl'] ?? '').toString().trim();

            return InkWell(
              onTap: busy ? null : () => onEdit(index),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0E0CC)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 42,
                        child: imageUrl.isEmpty
                            ? const ColoredBox(
                                color: Color(0xFFF0E0CC),
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 20,
                                  color: Color(0xFFB87535),
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) {
                                      return const ColoredBox(
                                        color: Color(0xFFF0E0CC),
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          size: 20,
                                          color: Color(0xFFB87535),
                                        ),
                                      );
                                    },
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      _featureIcon(item['icon'] ?? ''),
                      color: const Color(0xFFB87535),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item['title'] ?? '未命名特色',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3A2A1A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: busy ? null : () => onManageImage(index),
                      tooltip: '特色圖片',
                      icon: const Icon(Icons.image_rounded),
                    ),
                    IconButton(
                      onPressed: busy ? null : () => onChangeIcon(index),
                      icon: const Icon(Icons.apps_rounded),
                    ),
                    IconButton(
                      onPressed: busy ? null : () => onChangeLayout(index),
                      icon: Icon(
                        item['layout'] == 'imageLeft'
                            ? Icons.format_indent_decrease_rounded
                            : Icons.format_indent_increase_rounded,
                      ),
                    ),
                    IconButton(
                      onPressed: busy ? null : () => onDelete(index),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新增環境特色'),
          ),
        ),
      ],
    );
  }
}
