// 檔案名稱：lib/features/admin/pages/admin_member_link_request_page.dart
// 功能說明：集中查看待處理的會員合併申請，並可跳到會員詳細頁處理
// 🔗 後台會員合併管理頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_detail_page.dart';

class AdminMemberLinkRequestPage extends StatelessWidget {
  const AdminMemberLinkRequestPage({super.key, required this.shopId});

  final String shopId;

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '-';

    final dt = value.toDate();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員合併管理')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('member_link_requests')
            .where('shopId', isEqualTo: shopId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const Center(child: Text('目前沒有待確認的綁定申請'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final doc = requests[index];
              final data = doc.data() as Map<String, dynamic>;

              final targetUserId = data['targetUserId']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade50,
                    child: const Icon(Icons.link, color: Colors.purple),
                  ),
                  title: Text(
                    data['targetName']?.toString().isNotEmpty == true
                        ? data['targetName'].toString()
                        : '未填姓名',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '手機：${data['targetPhone'] ?? '未填'}\n'
                      '登入帳號：${data['authEmail'] ?? '未填'}\n'
                      '申請時間：${_formatTime(data['createdAt'])}',
                    ),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: targetUserId.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminMemberDetailPage(
                                userId: targetUserId,
                                shopId: shopId,
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
