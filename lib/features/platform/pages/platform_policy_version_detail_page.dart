// lib/features/platform/pages/platform_policy_version_detail_page.dart
// 📖 平台條款歷史版本詳細頁
// 功能：查看某一版平台條款的完整內容

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PlatformPolicyVersionDetailPage extends StatelessWidget {
  const PlatformPolicyVersionDetailPage({
    super.key,
    required this.titleText,
    required this.data,
  });

  final String titleText;
  final Map<String, dynamic> data;

  String _formatDate(dynamic value) {
    if (value == null) return '尚未記錄';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '尚未記錄';

    String two(int n) => n.toString().padLeft(2, '0');

    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final version = data['version'] ?? 1;
    final title = data['title']?.toString() ?? titleText;
    final content = data['content']?.toString() ?? '';
    final updatedAt = data['updatedAt'];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text('v$version 條款內容'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '版本：v$version',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '更新時間：${_formatDate(updatedAt)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Text(
              content.isEmpty ? '此版本沒有內容' : content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}