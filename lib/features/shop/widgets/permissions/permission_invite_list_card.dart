// lib/features/shop/widgets/permissions/permission_invite_list_card.dart
// ✉️ 權限設定 - 待綁定邀請列表卡片

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class PermissionInviteListCard extends StatelessWidget {
  const PermissionInviteListCard({
    super.key,
    required this.shopId,
    required this.currentUserRole,
    required this.isOwner,
    required this.roleLabelBuilder,
  });

  final String shopId;
  final String? currentUserRole;
  final bool isOwner;
  final String Function(String role) roleLabelBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ShopService.instance.streamShopMemberInvites(shopId),
      builder: (context, snapshot) {
        final invites = snapshot.data ?? [];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '待綁定邀請',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                if (invites.isEmpty) const ListTile(title: Text('目前沒有待綁定邀請')),
                ...invites.map((invite) {
                  final role = invite['role']?.toString() ?? '-';

                  return ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: Text(invite['email']?.toString() ?? '-'),
                    subtitle: Text('角色：${roleLabelBuilder(role)}'),
                    trailing: isOwner
                        ? IconButton(
                            onPressed: () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;

                              await ShopService.instance.removeMemberInvite(
                                inviteDocId: invite['id'],
                                shopId: shopId,
                                operatorUid: user.uid,
                                operatorRole:
                                    currentUserRole ?? ShopRoles.owner,
                              );
                            },
                            icon: const Icon(Icons.delete_outline),
                          )
                        : null,
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
