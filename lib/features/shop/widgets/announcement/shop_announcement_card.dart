// lib/features/shop/widgets/announcement/shop_announcement_card.dart
// 📢 店家公告卡片
// 功能：顯示前台公告標題、摘要、類型圖示、置頂狀態與時間

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class ShopAnnouncementCard extends StatelessWidget {
  const ShopAnnouncementCard({
    super.key,
    required this.data,
    this.theme = HomeThemeModel.classicDefault,
  });

  final Map<String, dynamic> data;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? '未命名公告';
    final content = data['content']?.toString() ?? '';
    final createdAt = data['createdAt'];
    final isPinned = data['isPinned'] == true;
    final type = data['type']?.toString() ?? 'normal';
    final typeIcon = _iconByType(type);
    final typeLabel = _labelByType(type);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, size: 22, color: theme.primaryColor),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPinned)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '置頂公告',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: theme.textColor,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  content.isEmpty ? '無公告內容' : content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: theme.textColor.withOpacity(0.75),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _formatTime(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColor.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: theme.primaryColor),
        ],
      ),
    );
  }

  IconData _iconByType(String type) {
    switch (type) {
      case 'important':
        return Icons.priority_high;
      case 'business_hours':
        return Icons.schedule;
      case 'promotion':
        return Icons.card_giftcard;
      case 'checkin_notice':
        return Icons.pets;
      case 'normal':
      default:
        return Icons.campaign;
    }
  }

  String _labelByType(String type) {
    switch (type) {
      case 'important':
        return '重要公告';
      case 'business_hours':
        return '營業異動';
      case 'promotion':
        return '優惠活動';
      case 'checkin_notice':
        return '入住提醒';
      case 'normal':
      default:
        return '一般公告';
    }
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '-';

    final dt = value.toDate();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
