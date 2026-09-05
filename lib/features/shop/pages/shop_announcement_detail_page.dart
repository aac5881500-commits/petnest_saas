// 檔案名稱：lib/features/shop/pages/shop_announcement_detail_page.dart
// 功能說明：顯示單篇公告完整標題、類型、置頂狀態、內容與發布時間
// 📢 前台公告詳細頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class ShopAnnouncementDetailPage extends StatelessWidget {
  const ShopAnnouncementDetailPage({
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
    final typeName = _labelByType(type);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '公告詳情',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TagChip(
                icon: typeIcon,
                label: typeName,
                backgroundColor: theme.primaryColor.withValues(alpha: 0.12),
                foregroundColor: theme.primaryColor,
              ),

              if (isPinned)
                _TagChip(
                  icon: Icons.workspace_premium,
                  label: '置頂公告',
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: theme.textColor,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: theme.textColor.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                _formatTime(createdAt),
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textColor.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.cardBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 18,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '公告內容',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  content.isEmpty ? '無公告內容' : content,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.8,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
          ),
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

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: foregroundColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
