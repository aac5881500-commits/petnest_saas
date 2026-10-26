// 檔案名稱：lib/features/shop/widgets/environment/environment_icon_picker_dialog.dart
// 功能說明：環境特色 Icon 選擇 Dialog

import 'package:flutter/material.dart';
import '../../data/environment_feature_icons.dart';

class EnvironmentIconPickerDialog extends StatelessWidget {
  const EnvironmentIconPickerDialog({super.key, required this.onSelect});

  final Function(String key) onSelect;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('選擇特色圖示'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
      content: SizedBox(
        width: 640,
        height: (MediaQuery.sizeOf(context).height * 0.65).clamp(160.0, 480.0),
        child: GridView(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            mainAxisExtent: 96,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          children: environmentFeatureIcons.map((item) {
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
                    Text(
                      item['label'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
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
