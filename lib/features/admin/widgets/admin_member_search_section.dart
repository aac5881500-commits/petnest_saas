// 檔案名稱：lib/features/admin/widgets/admin_member_search_section.dart
// 功能說明：搜尋店家會員，支援姓名與電話部分比對
// 🔍 後台會員搜尋區塊
// 並排除已合併會員，供手動新增訂單選擇會員使用。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
    final normalizedKeyword = keyword.trim().toLowerCase();

    if (normalizedKeyword.isEmpty) {
      return const Text('請先輸入姓名或電話搜尋會員', style: TextStyle(color: Colors.grey));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
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

        final docs = snapshot.data!.docs
            .where((doc) {
              final data = doc.data();

              final name = (data['name'] ?? '').toString().trim().toLowerCase();

              final phone = _normalizePhone((data['phone'] ?? '').toString());

              final normalizedPhoneKeyword = _normalizePhone(normalizedKeyword);

              final isMerged =
                  data['status'] == 'merged' || data['isMerged'] == true;

              if (isMerged) {
                return false;
              }

              final matchesName = name.contains(normalizedKeyword);

              final matchesPhone =
                  normalizedPhoneKeyword.isNotEmpty &&
                  phone.contains(normalizedPhoneKeyword);

              return matchesName || matchesPhone;
            })
            .take(20)
            .toList();

        if (docs.isEmpty) {
          return const Text(
            '查無會員，下一步會加入快速建立會員',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();

            final name = (data['name'] ?? '').toString().trim();

            final phone = (data['phone'] ?? '').toString().trim();

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(
                  name.isNotEmpty ? name : '未填姓名',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(phone.isNotEmpty ? '電話：$phone' : '電話：未填'),
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

  /// 移除電話中的空白、橫線、括號及其他非數字內容，
  /// 讓不同電話格式也能正常搜尋。
  static String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
