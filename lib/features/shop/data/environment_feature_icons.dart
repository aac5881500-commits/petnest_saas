// 檔案名稱：lib/features/shop/data/environment_feature_icons.dart
// 功能說明：環境特色圖示選項與前後台共用解析。
import 'package:flutter/material.dart';

const environmentFeatureIcons = <Map<String, Object>>[
  {'key': 'home', 'label': '住宿空間', 'icon': Icons.home_rounded},
  {'key': 'clean', 'label': '清潔消毒', 'icon': Icons.cleaning_services_rounded},
  {'key': 'air', 'label': '空調', 'icon': Icons.ac_unit_rounded},
  {'key': 'camera', 'label': '監視', 'icon': Icons.videocam_rounded},
  {'key': 'hospital', 'label': '醫療', 'icon': Icons.local_hospital_rounded},
  {'key': 'water', 'label': '飲水', 'icon': Icons.water_drop_rounded},
  {'key': 'sun', 'label': '日照', 'icon': Icons.wb_sunny_rounded},
  {'key': 'clean_hand', 'label': '定期消毒', 'icon': Icons.clean_hands_rounded},
  {'key': 'pets', 'label': '寵物照護', 'icon': Icons.pets_rounded},
  {'key': 'toys', 'label': '遊戲活動', 'icon': Icons.toys_rounded},
  {'key': 'bed', 'label': '舒適休憩', 'icon': Icons.bed_rounded},
  {'key': 'room', 'label': '獨立房間', 'icon': Icons.meeting_room_rounded},
  {'key': 'climb', 'label': '攀爬探索', 'icon': Icons.terrain_rounded},
  {'key': 'meal', 'label': '飲食照護', 'icon': Icons.restaurant_rounded},
  {'key': 'quiet', 'label': '安靜空間', 'icon': Icons.volume_off_rounded},
  {'key': 'ventilation', 'label': '通風換氣', 'icon': Icons.air_rounded},
  {'key': 'temperature', 'label': '溫度管理', 'icon': Icons.thermostat_rounded},
  {'key': 'safety', 'label': '安全防護', 'icon': Icons.shield_rounded},
  {'key': 'care', 'label': '細心陪伴', 'icon': Icons.favorite_rounded},
  {'key': 'report', 'label': '照護紀錄', 'icon': Icons.assignment_rounded},
  {'key': 'photo', 'label': '照片分享', 'icon': Icons.photo_camera_rounded},
  {'key': 'garden', 'label': '自然綠意', 'icon': Icons.eco_rounded},
];

IconData environmentFeatureIcon(String key) {
  for (final item in environmentFeatureIcons) {
    if (item['key'] == key) return item['icon'] as IconData;
  }
  return Icons.pets_rounded;
}
