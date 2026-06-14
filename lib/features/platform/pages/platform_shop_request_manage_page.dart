// lib/features/platform/pages/platform_shop_request_manage_page.dart
// 📨 店家申請中心
// 功能：平台審核店家資料修改、認證、前台公開等申請

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformShopRequestManagePage extends StatelessWidget {
  const PlatformShopRequestManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('店家申請中心')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shop_change_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('目前尚無待審核申請'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final shopName = data['shopName']?.toString() ?? '未知店家';
              final requestType = data['requestType']?.toString() ?? '';
              final newValue = data['newValue']?.toString() ?? '';
              final reason = data['reason']?.toString() ?? '';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('申請類型：$requestType'),
                      Text('新資料：$newValue'),
                      Text('原因：$reason'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('shop_change_requests')
                                    .doc(doc.id)
                                    .update({
                                      'status': 'rejected',
                                      'reviewedAt':
                                          FieldValue.serverTimestamp(),
                                    });
                              },
                              child: const Text('拒絕'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
