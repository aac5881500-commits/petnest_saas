// lib/features/admin/widgets/admin_member_search_section.dart
// 🔍 後台會員搜尋區塊
// 功能：搜尋會員並顯示會員列表

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMemberSearchSection extends StatelessWidget {
  const AdminMemberSearchSection({
    super.key,
    required this.shopId,
    required this.keyword,
    required this.onSelectMember,
  });

  final String keyword;
  final String shopId;

  final void Function(String userId, Map<String, dynamic> data) onSelectMember;

  @override
  Widget build(BuildContext context) {
    if (keyword.isEmpty) {
      return const Text('請先輸入姓名或電話搜尋會員', style: TextStyle(color: Colors.grey));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .where('phone', isEqualTo: keyword)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            '搜尋會員失敗：${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final name = data['name']?.toString() ?? '';

          final phone = data['phone']?.toString() ?? '';

          final matched = name.contains(keyword) || phone.contains(keyword);

          final isMerged =
              data['status'] == 'merged' || data['isMerged'] == true;

          return matched && !isMerged;
        }).toList();

        if (docs.isEmpty) {
          return const Text(
            '查無會員，下一步會加入快速建立會員',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(
                  data['name']?.toString().isNotEmpty == true
                      ? data['name'].toString()
                      : '未填姓名',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('電話：${data['phone'] ?? '未填'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  onSelectMember(doc.id, data);
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
