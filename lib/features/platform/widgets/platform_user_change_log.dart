// 檔案名稱：lib/features/platform/widgets/platform_user_change_log.dart
// 功能說明：把平台人員權限異動顯示成可展開的中文摘要。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/platform_permission_keys.dart';
import 'package:petnest_saas/core/services/platform_permission_catalog.dart';

class PlatformUserChangeLog extends StatelessWidget {
  const PlatformUserChangeLog({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream = FirebaseFirestore
        .instance
        .collection('action_logs')
        .where('targetType', isEqualTo: 'platform_user')
        .where('targetId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('操作紀錄暫時無法顯示。儲存本身仍會寫入紀錄；若持續空白，請先部署平台人員紀錄索引。'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('目前沒有這位人員的權限異動紀錄。'),
          );
        }
        return Column(
          children: [
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs)
              _LogTile(data: doc.data()),
          ],
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> payload = data['payload'] is Map
        ? Map<String, dynamic>.from(data['payload'] as Map)
        : <String, dynamic>{};
    final List<String> added = _strings(payload['addedPermissions']);
    final List<String> removed = _strings(payload['removedPermissions']);
    final String previousRole = '${payload['previousRole'] ?? ''}';
    final String nextRole = '${payload['nextRole'] ?? ''}';
    final bool previousEnabled = payload['previousEnabled'] == true;
    final bool nextEnabled = payload['nextEnabled'] == true;
    final bool enabledChanged = previousEnabled != nextEnabled;
    final String headline = PlatformPermissionCatalog.changeHeadline(
      operatorRole: '${data['operatorRole'] ?? ''}',
      addedCount: added.length,
      removedCount: removed.length,
      enabledChanged: enabledChanged,
      nextEnabled: nextEnabled,
    );
    final String detail = PlatformPermissionCatalog.changeDetail(
      addedCount: added.length,
      removedCount: removed.length,
      enabledChanged: enabledChanged,
      nextEnabled: nextEnabled,
      roleChanged: previousRole.isNotEmpty && previousRole != nextRole,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(_timeLabel(data['createdAt'])),
        subtitle: Text('$headline\n$detail'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (previousRole != nextRole)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '角色：${PlatformAdminRoles.label(previousRole)} → ${PlatformAdminRoles.label(nextRole)}',
              ),
            ),
          if (enabledChanged)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('啟用狀態：${previousEnabled ? '已啟用' : '已停用'} → ${nextEnabled ? '已啟用' : '已停用'}'),
            ),
          if (added.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('新增：${added.map(PlatformPermissionKeys.label).join('、')}'),
            ),
          if (removed.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('移除：${removed.map(PlatformPermissionKeys.label).join('、')}'),
            ),
        ],
      ),
    );
  }
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
}

String _timeLabel(Object? value) {
  if (value is! Timestamp) return '時間待同步';
  final DateTime time = value.toDate().toLocal();
  final String month = time.month.toString().padLeft(2, '0');
  final String day = time.day.toString().padLeft(2, '0');
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
