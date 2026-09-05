// 檔案名稱：lib/features/shop/widgets/permissions/permission_member_list_card.dart
// 功能說明：權限設定 - 目前成員列表卡片

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class PermissionMemberListCard extends StatelessWidget {
  const PermissionMemberListCard({
    super.key,
    required this.shopId,
    required this.roleLabelBuilder,
    required this.onTapMember,
  });

  final String shopId;
  final String Function(String role) roleLabelBuilder;
  final void Function(Map<String, dynamic> member) onTapMember;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ShopService.instance.streamShopMembers(shopId),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '目前成員',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 8),

                if (members.isEmpty) const ListTile(title: Text('目前沒有其他成員')),

                ...members.map((member) {
                  final role = member['role']?.toString() ?? '-';

                  final email = member['email']?.toString() ?? '-';

                  final permissions = ShopService.instance.normalizePermissions(
                    member['permissions'],
                    role: role,
                  );

                  final enabledCount = permissions.values
                      .where((e) => e)
                      .length;

                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(email),
                    subtitle: Text(
                      '角色：${roleLabelBuilder(role)}｜啟用權限：$enabledCount',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      onTapMember(member);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
