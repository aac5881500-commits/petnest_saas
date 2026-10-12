// 檔案名稱：lib/features/shop/widgets/permissions/permission_member_list_card.dart
// 功能說明：權限頁的成員列表。資料由外層的既有成員串流傳入，這裡不再另外查詢。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_member_permission_service.dart';
import 'package:petnest_saas/core/services/shop_permission_catalog.dart';

class PermissionMemberListCard extends StatelessWidget {
  const PermissionMemberListCard({
    super.key,
    required this.members,
    required this.selectedId,
    required this.onTapMember,
  });

  final List<Map<String, dynamic>> members;
  final String? selectedId;
  final void Function(Map<String, dynamic> member) onTapMember;

  static String displayName(Map<String, dynamic> member) {
    for (final String key in <String>['name', 'displayName', 'staffName']) {
      final String value = member[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '未設定名稱';
  }

  static String statusLabel(String status) {
    switch (status) {
      case '':
      case 'active':
        return '使用中';
      case 'disabled':
      case 'inactive':
        return '已停用';
      case 'pending':
        return '待接受';
      default:
        return status;
    }
  }

  static int enabledPermissionCount(Map<String, dynamic> member) {
    final String role = member['role']?.toString() ?? '';
    if (role == ShopRoles.owner) return -1;
    final Map<String, bool> normalized = ShopMemberPermissionService.instance
        .normalizePermissions(member['permissions'], role: role);
    return ShopPermissionCatalog.enabledCount(normalized);
  }

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Card(child: ListTile(title: Text('目前沒有其他成員')));
    }
    final List<Map<String, dynamic>> ordered =
        List<Map<String, dynamic>>.from(members)
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
            return _rank(
              a['role']?.toString(),
            ).compareTo(_rank(b['role']?.toString()));
          });
    return Column(
      children: ordered.map((Map<String, dynamic> member) {
        final String role = member['role']?.toString() ?? ShopRoles.staff;
        final String email = member['email']?.toString() ?? '';
        final String status = member['status']?.toString() ?? 'active';
        final int count = enabledPermissionCount(member);
        final bool selected = member['id']?.toString() == selectedId;
        return Card(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
          child: ListTile(
            title: Text(displayName(member)),
            subtitle: Text(
              '$email\n${ShopRoles.label(role)}｜${statusLabel(status)}｜${count < 0 ? '全部權限' : '已啟用 $count 項'}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTapMember(member),
          ),
        );
      }).toList(),
    );
  }

  static int _rank(String? role) {
    switch (role) {
      case ShopRoles.owner:
        return 0;
      case ShopRoles.manager:
        return 1;
      default:
        return 2;
    }
  }
}
