// lib/features/shop/widgets/room/room_feature_tags.dart
// 🔥 共用房型特色小卡：顯示房型設備與特色，例如獨立包廂、每日整理、全日監控

import 'package:flutter/material.dart';

class RoomFeatureTags extends StatelessWidget {
  const RoomFeatureTags({
    super.key,
    required this.features,
  });

  final List features;

  static final Map<String, Map<String, dynamic>> featureOptions = {
    'private_space': {'name': '獨立包廂', 'icon': Icons.home},
    'daily_clean': {'name': '每日整理', 'icon': Icons.cleaning_services},
    'camera': {'name': '全日監控', 'icon': Icons.videocam},
    'aircon': {'name': '舒適空調', 'icon': Icons.ac_unit},
    'private_door': {'name': '獨立房門', 'icon': Icons.lock},
    'cat_window': {'name': '透明貓窗', 'icon': Icons.window},
    'sky_walk': {'name': '天空步道', 'icon': Icons.architecture},
    'scratch': {'name': '貓抓板', 'icon': Icons.pets},
    'jump': {'name': '跳台設計', 'icon': Icons.stairs},
    'bed': {'name': '舒眠睡窩', 'icon': Icons.bed},
  };

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) {
      return const SizedBox();
    }

    return LayoutBuilder(
  builder: (context, constraints) {
    const spacing = 10.0;

    final itemWidth =
        (constraints.maxWidth - spacing * 2) / 3;

    return Wrap(
      spacing: spacing,
      runSpacing: 10,
      children: features.map<Widget>((key) {
        final item = featureOptions[key];

        if (item == null) {
          return const SizedBox();
        }

        return SizedBox(
          width: itemWidth,
          child: RoomFeatureCard(
            icon: item['icon'] as IconData,
            text: item['name'] as String,
          ),
        );
      }).toList(),
    );
  },
);
  }
}

class RoomFeatureCard extends StatelessWidget {
  const RoomFeatureCard({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
  mainAxisAlignment: MainAxisAlignment.center,
  mainAxisSize: MainAxisSize.max,
  children: [
    Icon(icon, size: 18),

    const SizedBox(width: 6),

    Flexible(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
),
    );
  }
}