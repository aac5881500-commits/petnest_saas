// lib/features/shop/widgets/environment/environment_feature_manager.dart
// 🐾 後台環境特色卡片管理區塊

import 'package:flutter/material.dart';

class EnvironmentFeatureManager extends StatelessWidget {
  const EnvironmentFeatureManager({
    super.key,
    required this.features,
    required this.onAdd,
    required this.onDelete,
    required this.onEdit,
    required this.onChangeIcon,
    required this.onUploadImage,
  });

  final List<Map<String, dynamic>> features;
  final VoidCallback onAdd;
  final Function(int index) onDelete;
  final Function(int index) onEdit;
  final Function(int index) onChangeIcon;
  final Function(int index) onUploadImage;

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
          ...features.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            return InkWell(
  onTap: () => onEdit(index),
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
  onPressed: () => onUploadImage(index),
  icon: const Icon(Icons.image_rounded),
),
                  IconButton(
  onPressed: () => onChangeIcon(index),
  icon: const Icon(Icons.apps_rounded),
),
IconButton(
  onPressed: () => onDelete(index),
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
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新增環境特色'),
          ),
        ),
      ],
    );
  }
}