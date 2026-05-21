// lib/features/shop/pages/policy_version_detail_page.dart
// 📜 入住條款歷史版本詳細頁
//
// 用途：
// - 查看某一版入住條款完整內容
// - 爭議時可回查客戶當時同意的條款版本

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PolicyVersionDetailPage extends StatelessWidget {
  const PolicyVersionDetailPage({
    super.key,
    required this.data,
  });

  final Map<String, dynamic> data;

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toDate());
  }

  Widget _section({
    required String title,
    required String content,
  }) {
    if (content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _customSections(List items) {
    return List.generate(items.length, (index) {
      final text = items[index]?.toString() ?? '';
      return _section(
        title: '額外條款 ${index + 1}',
        content: text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final version = data['version'] ?? '-';
    final updatedAt = _formatTime(data['updatedAt']);
    final updatedByEmail = data['updatedByEmail']?.toString() ?? '-';

    final sections = Map<String, dynamic>.from(data['sections'] ?? {});
    final enabled = Map<String, dynamic>.from(data['enabled'] ?? {});

    final customPoliciesPage1 =
        (data['customPoliciesPage1'] ?? []) as List;
    final customPoliciesPage2 =
        (data['customPoliciesPage2'] ?? []) as List;

    String getText(String key) {
      if (enabled[key] == false) return '';
      return sections[key]?.toString() ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('條款版本 v$version'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.description),
              title: Text(
                'v$version',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '更新時間：$updatedAt\n更新者：$updatedByEmail',
              ),
            ),
          ),

          const Text(
            '📄 入住須知（前台第 1 頁）',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _section(
            title: '營業時間與環境參觀時間',
            content: getText('checkinTime'),
          ),
          _section(
            title: '入住與退房安排',
            content: getText('checkOutFlow'),
          ),
          _section(
            title: '貓咪入住基本條件',
            content: getText('basicCondition'),
          ),
          _section(
            title: '貓咪入住前飼主應告知資訊',
            content: getText('ownerNotice'),
          ),
          _section(
            title: '貓咪入住須知',
            content: getText('checkinNotice'),
          ),
          _section(
            title: '本店提供的基本設施',
            content: getText('facility'),
          ),
          _section(
            title: '特殊情況處理',
            content: getText('specialCase'),
          ),
          _section(
            title: '探索活動安排',
            content: getText('activity'),
          ),
          _section(
            title: '額外注意事項',
            content: getText('extraNotice'),
          ),

          ..._customSections(customPoliciesPage1),

          const SizedBox(height: 20),

          const Text(
            '📄 訂房與退款（前台第 2 頁）',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _section(
            title: '訂房取消政策',
            content: getText('cancelPolicy'),
          ),

          ..._customSections(customPoliciesPage2),
        ],
      ),
    );
  }
}