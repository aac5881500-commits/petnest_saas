// lib/features/shop/pages/shop_announcement_detail_page.dart
// 📢 前台公告詳細頁
// 功能：顯示單篇公告完整標題、類型、置頂狀態、內容與發布時間

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShopAnnouncementDetailPage extends StatelessWidget {
  const ShopAnnouncementDetailPage({super.key, required this.data});

  final Map<String, dynamic> data;

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
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFCF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('公告詳情'),
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
                backgroundColor: const Color(0xFFFFF1DD),
                foregroundColor: const Color(0xFFB86B18),
              ),

              if (isPinned)
                const _TagChip(
                  icon: Icons.workspace_premium,
                  label: '置頂公告',
                  backgroundColor: Color(0xFFFF9800),
                  foregroundColor: Colors.white,
                ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3A2A1A),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Color(0xFF9A7B55)),
              const SizedBox(width: 6),
              Text(
                _formatTime(createdAt),
                style: const TextStyle(fontSize: 13, color: Color(0xFF9A7B55)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0E0CC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 18,
                      color: Color(0xFFB86B18),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '公告內容',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB86B18),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  content.isEmpty ? '無公告內容' : content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.8,
                    color: Color(0xFF3A2A1A),
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
