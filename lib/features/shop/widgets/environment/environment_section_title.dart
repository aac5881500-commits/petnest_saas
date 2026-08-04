// lib/features/shop/widgets/environment/environment_section_title.dart
// 🐾 環境介紹區塊標題
// 顯示 icon + 標題

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class EnvironmentSectionTitle extends StatelessWidget {
  const EnvironmentSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.theme = HomeThemeModel.classicDefault,
  });

  final IconData icon;
  final String title;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Icon(icon, size: 21, color: theme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: theme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
