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
  });

  final String text;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite_rounded, color: theme.primaryColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: theme.textColor.withOpacity(0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
