// lib/features/shop/widgets/environment/environment_care_item.dart
// 🐾 環境介紹安心照護小卡
// 顯示照護設備：Icon、標題、簡短說明

import 'package:flutter/material.dart';

class EnvironmentCareItem extends StatelessWidget {
  const EnvironmentCareItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E0CC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFFFFF1DD),
            child: Icon(
              icon,
              color: const Color(0xFFB87535),
              size: 23,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3A2A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8A6A45),
            ),
          ),
        ],
      ),
    );
  }
}