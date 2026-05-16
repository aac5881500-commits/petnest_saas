// lib/features/shop/widgets/environment/environment_icon_picker_dialog.dart
// 🐾 環境特色 Icon 選擇 Dialog

import 'package:flutter/material.dart';

class EnvironmentIconPickerDialog extends StatelessWidget {
  const EnvironmentIconPickerDialog({
    super.key,
    required this.onSelect,
  });

  final Function(String key) onSelect;

  @override
  Widget build(BuildContext context) {
    final icons = [
      {
        'key': 'home',
        'label': '住宿空間',
        'icon': Icons.home_rounded,
      },
      {
        'key': 'clean',
        'label': '清潔消毒',
        'icon': Icons.cleaning_services_rounded,
      },
      {
        'key': 'air',
        'label': '空調',
        'icon': Icons.ac_unit_rounded,
      },
      {
        'key': 'camera',
        'label': '監視',
        'icon': Icons.videocam_rounded,
      },
      {
        'key': 'hospital',
        'label': '醫療',
        'icon': Icons.local_hospital_rounded,
      },
      {
        'key': 'water',
        'label': '飲水',
        'icon': Icons.water_drop_rounded,
      },
      {
        'key': 'sun',
        'label': '日照',
        'icon': Icons.wb_sunny_rounded,
      },
      {
        'key': 'clean_hand',
        'label': '定期消毒',
        'icon': Icons.clean_hands_rounded,
      },
      {
        'key': 'pets',
        'label': '寵物照護',
        'icon': Icons.pets_rounded,
      },
      {
        'key': 'toys',
        'label': '遊戲活動',
        'icon': Icons.toys_rounded,
      },
    ];

    return AlertDialog(
      title: const Text('選擇特色圖示'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: icons.map((item) {
            return InkWell(
              onTap: () {
                onSelect(item['key'] as String);
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0E0CC)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color: const Color(0xFFB87535),
                    ),
                    const SizedBox(height: 8),
                    Text(item['label'] as String),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}