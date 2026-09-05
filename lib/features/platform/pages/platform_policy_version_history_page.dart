// 檔案名稱：lib/features/platform/pages/platform_policy_version_history_page.dart
// 功能說明：查看平台會員條款或創店主條款的歷史版本紀錄
// 📚 平台條款歷史版本頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/platform/pages/platform_policy_version_detail_page.dart';

class PlatformPolicyVersionHistoryPage extends StatelessWidget {
  const PlatformPolicyVersionHistoryPage({
    super.key,
    required this.policyKey,
    required this.titleText,
  });

  final String policyKey;
  final String titleText;

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
    final versionsRef = FirebaseFirestore.instance
        .collection('platform_policies')
        .doc(policyKey)
        .collection('versions')
        .orderBy('version', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: Text('$titleText 歷史版本')),
      body: StreamBuilder<QuerySnapshot>(
        stream: versionsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('目前沒有歷史版本紀錄'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final version = data['version'] ?? 1;
              final title = data['title']?.toString() ?? titleText;
              final updatedAt = data['updatedAt'];

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEAF3FF),
                    child: Text(
                      'v$version',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('更新時間：${_formatDate(updatedAt)}'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlatformPolicyVersionDetailPage(
                          titleText: titleText,
                          data: data,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
