// 檔案名稱：lib/features/admin/widgets/admin_selected_member_card.dart
// 功能說明：手動新增訂單時顯示目前選中的會員資料
// ✅ 後台已選會員卡片

import 'package:flutter/material.dart';

class AdminSelectedMemberCard extends StatelessWidget {
  const AdminSelectedMemberCard({super.key, required this.member});

  final Map<String, dynamic> member;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name']?.toString().isNotEmpty == true
                      ? member['name'].toString()
                      : '未填姓名',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text('電話：${member['phone'] ?? '未填'}'),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }
}
