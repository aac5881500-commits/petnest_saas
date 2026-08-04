// lib/features/shop/widgets/environment/environment_feature_card.dart
// 🐾 環境介紹特色卡
// 顯示環境特色：Icon、標題、描述、照片

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class EnvironmentFeatureCard extends StatelessWidget {
  const EnvironmentFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.imageBuilder,
    this.theme = HomeThemeModel.classicDefault,
    this.reverse = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String imageUrl;
  final bool reverse;
  final HomeThemeModel theme;
  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  })
  imageBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: reverse
            ? [
                SizedBox(
                  width: 148,
                  height: 118,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imageBuilder(
                      imageUrl: imageUrl,
                      width: 148,
                      height: 118,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildTextContent()),
              ]
            : [
                Expanded(child: _buildTextContent()),
                const SizedBox(width: 16),
                SizedBox(
                  width: 148,
                  height: 118,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imageBuilder(
                      imageUrl: imageUrl,
                      width: 148,
                      height: 118,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
      ),
    );
  }

  Widget _buildTextContent() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: theme.textColor,
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
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: theme.textColor.withOpacity(0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
