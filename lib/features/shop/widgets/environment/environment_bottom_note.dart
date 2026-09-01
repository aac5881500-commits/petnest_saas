// lib/features/shop/widgets/environment/environment_bottom_note.dart
// 🐾 環境介紹底部提醒卡
// 顯示住宿安排提醒文字

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class EnvironmentBottomNote extends StatelessWidget {
  const EnvironmentBottomNote({
    super.key,
    required this.text,
    this.theme = HomeThemeModel.classicDefault,
    this.fontSize = 14,
    this.padding = 18,
    this.horizontalMargin = 16,
  });

  final String text;
  final HomeThemeModel theme;
  final double fontSize;
  final double padding;
  final double horizontalMargin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.favorite_rounded, color: theme.primaryColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: theme.textColor.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
