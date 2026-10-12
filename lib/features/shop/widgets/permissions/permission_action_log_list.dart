// 檔案名稱：lib/features/shop/widgets/permissions/permission_action_log_list.dart
// 功能說明：把既有 action_logs 顯示成可展開的權限異動摘要。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_permission_catalog.dart';

class PermissionActionLogList extends StatelessWidget {
  const PermissionActionLogList({
    super.key,
    required this.logs,
    this.memberId,
    this.title = '操作紀錄',
  });

  final List<Map<String, dynamic>> logs;
  final String? memberId;
  final String title;

  static const List<String> watchedActions = <String>[
    'create_invite',
    'invite_accepted',
    'update_member_permission',
    'update_permission',
    'remove_member_invite',
    'remove_member',
  ];

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> visible = logs.where((
      Map<String, dynamic> log,
    ) {
      final String action = log['action']?.toString() ?? '';
      if (!watchedActions.contains(action)) return false;
      if (memberId == null || memberId!.isEmpty) return true;
      return log['targetId']?.toString() == memberId;
    }).toList();

    if (visible.isEmpty) {
      return Card(
        child: ListTile(title: Text(title), subtitle: const Text('目前沒有權限異動')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ...visible.map((Map<String, dynamic> log) {
          final String action = log['action']?.toString() ?? '';
          final Timestamp? createdAt = log['createdAt'] is Timestamp
              ? log['createdAt'] as Timestamp
              : null;
          final String timeText = createdAt == null
              ? '--/-- --:--'
              : DateFormat('MM/dd HH:mm').format(createdAt.toDate());
          final Map<String, dynamic> payload = log['payload'] is Map
              ? Map<String, dynamic>.from(log['payload'] as Map)
              : <String, dynamic>{};
          final ShopPermissionLogText text =
              ShopPermissionCatalog.describeActionLog(
                action: action,
                operatorRole: log['operatorRole']?.toString() ?? '',
                timeText: timeText,
                payload: payload,
              );
          final String operatorEmail = log['operatorEmail']?.toString() ?? '';
          final String operatorRole = ShopRoles.label(
            log['operatorRole']?.toString() ?? '',
          );
          return Card(
            child: ExpansionTile(
              title: Text(text.headline),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (operatorEmail.isNotEmpty)
                        Text('操作者：$operatorEmail｜$operatorRole'),
                      Text(
                        createdAt == null
                            ? '時間未記錄'
                            : '時間：${DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toDate())}',
                      ),
                      ...text.details.map(
                        (String line) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(line),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
