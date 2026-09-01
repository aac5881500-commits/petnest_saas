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
    this.fontSize = 18,
    this.iconSize = 21,
    this.horizontalPadding = 18,
  });

  final IconData icon;
  final String title;
  final HomeThemeModel theme;
  final double fontSize;
  final double iconSize;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: <Widget>[
          Icon(icon, size: iconSize, color: theme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: theme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
