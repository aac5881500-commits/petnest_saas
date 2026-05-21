// lib/features/shop/pages/policy_version_history_page.dart
// 📜 入住條款歷史版本頁
//
// 用途：
// - 查看店家每次儲存並升級版本後留下的條款紀錄
// - 之後可點進去查看該版本完整內容

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/features/shop/pages/policy_version_detail_page.dart';

class PolicyVersionHistoryPage extends StatelessWidget {
  const PolicyVersionHistoryPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '-';

    return DateFormat('yyyy-MM-dd HH:mm').format(value.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('條款歷史版本'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('policy_versions')
            .orderBy('version', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('目前沒有歷史版本'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final version = data['version'] ?? '-';
              final updatedAt = _formatTime(data['updatedAt']);
              final updatedByEmail =
                  data['updatedByEmail']?.toString() ?? '-';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    'v$version',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '更新時間：$updatedAt\n更新者：$updatedByEmail',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                 onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PolicyVersionDetailPage(
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