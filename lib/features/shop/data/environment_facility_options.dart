// 檔案名稱：lib/features/shop/data/environment_facility_options.dart
// 功能說明：環境設備固定選項資料庫

import 'package:flutter/material.dart';

final List<Map<String, dynamic>> environmentFacilityOptions = [
  {
    'key': 'air_cleaner',
    'title': '空氣清淨機',
    'description': '維持空氣清新',
    'icon': Icons.air_rounded,
  },
  {
    'key': 'uv_clean',
    'title': '紫外線消毒',
    'description': '定期紫外線清潔',
    'icon': Icons.wb_sunny_outlined,
  },
  {
    'key': 'camera_24h',
    'title': '24H 監視器',
    'description': '設有監視設備',
    'icon': Icons.videocam_rounded,
  },
  {
    'key': 'hospital',
    'title': '緊急送醫',
    'description': '緊急狀況可協助聯繫就醫',
    'icon': Icons.local_hospital_rounded,
  },
  {
    'key': 'water',
    'title': '飲水設備',
    'description': '提供乾淨飲水',
    'icon': Icons.water_drop_rounded,
  },
  {
    'key': 'sunlight',
    'title': '日照空間',
    'description': '舒適採光環境',
    'icon': Icons.wb_sunny_rounded,
  },
  {
    'key': 'disinfect',
    'title': '定期消毒',
    'description': '維持環境衛生',
    'icon': Icons.clean_hands_rounded,
  },
  {
    'key': 'play_area',
    'title': '遊戲空間',
    'description': '每日放風活動',
    'icon': Icons.toys_rounded,
  },
  {
    'key': 'cat_tree',
    'title': '貓跳台',
    'description': '提供活動空間',
    'icon': Icons.pets_rounded,
  },
  {
    'key': 'scratch_board',
    'title': '貓抓板',
    'description': '舒壓放鬆',
    'icon': Icons.star_border_rounded,
  },
  {
    'key': 'line_report',
    'title': 'LINE 回報',
    'description': '透過 LINE 聯繫回報',
    'icon': Icons.chat_bubble_rounded,
  },
  {
    'key': 'feeding',
    'title': '餵藥服務',
    'description': '協助定時餵藥',
    'icon': Icons.medication_rounded,
  },
  {
    'key': 'climate_control',
    'title': '溫濕度管理',
    'description': '留意住宿環境溫濕度',
    'icon': Icons.thermostat,
    'category': 'environment',
  },
  {
    'key': 'ventilation',
    'title': '通風設備',
    'description': '提供環境通風設備',
    'icon': Icons.air,
    'category': 'environment',
  },
  {
    'key': 'private_space',
    'title': '獨立住宿空間',
    'description': '提供分開的住宿空間',
    'icon': Icons.home,
    'category': 'environment',
  },
  {
    'key': 'separate_supplies',
    'title': '用品分開使用',
    'description': '分開安排貓咪使用的用品',
    'icon': Icons.inventory_2_outlined,
    'category': 'safety',
  },
  {
    'key': 'access_control',
    'title': '門禁管理',
    'description': '管理住宿區域進出',
    'icon': Icons.lock_outline,
    'category': 'safety',
  },
  {
    'key': 'emergency_contact',
    'title': '緊急聯絡流程',
    'description': '備有緊急狀況聯絡方式',
    'icon': Icons.contact_phone_outlined,
    'category': 'safety',
  },
  {
    'key': 'meal_portions',
    'title': '分餐餵食',
    'description': '依溝通內容安排分餐',
    'icon': Icons.restaurant,
    'category': 'care',
  },
  {
    'key': 'water_change',
    'title': '飲水更換',
    'description': '安排飲水更換',
    'icon': Icons.water_drop_outlined,
    'category': 'care',
  },
  {
    'key': 'litter_cleaning',
    'title': '貓砂清潔',
    'description': '安排貓砂與砂盆清潔',
    'icon': Icons.cleaning_services_outlined,
    'category': 'care',
  },
  {
    'key': 'companionship',
    'title': '活動陪伴',
    'description': '依貓咪狀況安排互動',
    'icon': Icons.pets,
    'category': 'care',
  },
  {
    'key': 'photo_report',
    'title': '照片回報',
    'description': '提供照護照片供飼主查看',
    'icon': Icons.photo_outlined,
    'category': 'service',
  },
  {
    'key': 'own_supplies',
    'title': '自備用品',
    'description': '可事先溝通自備用品安排',
    'icon': Icons.shopping_bag_outlined,
    'category': 'service',
  },
  {
    'key': 'special_requests',
    'title': '特殊需求溝通',
    'description': '入住前可討論個別照護需求',
    'icon': Icons.forum_outlined,
    'category': 'service',
  },
];

String environmentFacilityCategory(Map<String, dynamic> item) {
  if (item['category'] is String) return item['category'] as String;
  switch (item['key']) {
    case 'uv_clean':
    case 'camera_24h':
    case 'disinfect':
      return 'safety';
    case 'hospital':
    case 'line_report':
    case 'feeding':
      return 'service';
    default:
      return 'environment';
  }
}
