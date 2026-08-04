// lib/features/shop/widgets/environment/environment_care_item.dart
// 🐾 環境介紹安心照護小卡
// 顯示照護設備：Icon、標題、簡短說明

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class EnvironmentCareItem extends StatelessWidget {
  const EnvironmentCareItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.theme = HomeThemeModel.classicDefault,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.cardBorderColor),
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
            backgroundColor: theme.primaryColor.withOpacity(0.12),
            child: Icon(icon, color: theme.primaryColor, size: 23),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: theme.textColor.withOpacity(0.68),
            ),
          ),
        ],
      ),
    );
  }
}
