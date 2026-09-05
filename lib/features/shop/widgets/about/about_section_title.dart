// 檔案名稱：lib/features/shop/widgets/about/about_section_title.dart
// 功能說明：關於我們頁 共用區塊標題

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class AboutSectionTitle extends StatelessWidget {
  const AboutSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: theme.textColor,
          ),
        ),
      ],
    );
  }
}
