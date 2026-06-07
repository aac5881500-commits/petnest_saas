// lib/features/shop/pages/shop_announcement_detail_page.dart
// 📢 前台公告詳細頁
// 功能：顯示單篇公告完整標題、內容與發布時間

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

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFCF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('公告詳情'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isPinned)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '置頂公告',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3A2A1A),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _formatTime(createdAt),
            style: const TextStyle(fontSize: 13, color: Color(0xFF9A7B55)),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0E0CC)),
            ),
            child: Text(
              content.isEmpty ? '無公告內容' : content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Color(0xFF3A2A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '-';

    final dt = value.toDate();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
