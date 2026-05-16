// lib/features/shop/widgets/environment/environment_feature_card.dart
// 🐾 環境介紹特色卡
// 顯示環境特色：Icon、標題、描述、照片

import 'package:flutter/material.dart';

class EnvironmentFeatureCard extends StatelessWidget {
  const EnvironmentFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.imageBuilder,
  });

  final IconData icon;
  final String title;
  final String description;
  final String imageUrl;

  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  }) imageBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E0CC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
  child: Padding(
padding: const EdgeInsets.only(left: 10, right: 8),              
child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(
          icon,
          color: const Color(0xFFB87535),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3A2A1A),
            ),
          ),
        ),
      ],
    ),

    const SizedBox(height: 8),

    Padding(
  padding: const EdgeInsets.only(left: 30),
  child: Text(
    description,
    style: const TextStyle(
      fontSize: 12.5,
      height: 1.5,
      color: Color(0xFF6F5A43),
    ),
  ),
),
  ],
),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageBuilder(
              imageUrl: imageUrl,
              width: 122,
              height: 102,
            ),
          ),
        ],
      ),
    );
  }
}