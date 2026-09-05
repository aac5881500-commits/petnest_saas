// 檔案名稱：lib/features/shop/widgets/environment/environment_care_item.dart
// 功能說明：環境介紹安心照護小卡
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
    this.titleSize = 13,
    this.subtitleSize = 11,
    this.iconSize = 23,
    this.padding = 10,
    this.avatarRadius = 21,
    this.radius = 18,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final HomeThemeModel theme;
  final double titleSize;
  final double subtitleSize;
  final double iconSize;
  final double padding;
  final double avatarRadius;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: theme.cardBorderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: theme.primaryColor.withValues(alpha: 0.12),
            child: Icon(icon, color: theme.primaryColor, size: iconSize),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: theme.textColor,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: subtitleSize,
                height: 1.3,
                color: theme.textColor.withValues(alpha: 0.68),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
