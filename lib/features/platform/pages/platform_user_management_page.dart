// lib/features/platform/pages/platform_user_management_page.dart
// 👥 平台人員管理頁
// 功能：顯示平台最高管理員、開發管理員與平台員工清單，
// 並標示帳號狀態、角色及已分配權限數量。

import 'package:flutter/material.dart';
import 'platform_user_create_page.dart';
import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/constants/platform_root_admin.dart';
import '../../../core/models/platform_admin_model.dart';
import '../../../core/services/platform_admin_service.dart';
import 'platform_user_permission_page.dart';
import 'platform_user_create_page.dart';

class PlatformUserManagementPage extends StatelessWidget {
  const PlatformUserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('平台人員與權限')),
      body: StreamBuilder<List<PlatformAdminModel>>(
        stream: PlatformAdminService.instance.streamAdmins(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(message: '讀取平台人員失敗：${snapshot.error}');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final admins = snapshot.data ?? <PlatformAdminModel>[];

          if (admins.isEmpty) {
            return const _EmptyView();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: admins.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _PlatformUserCard(admin: admins[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlatformUserCreatePage()),
          );
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('新增平台人員'),
      ),
    );
  }
}

class _PlatformUserCard extends StatelessWidget {
  const _PlatformUserCard({required this.admin});

  final PlatformAdminModel admin;

  @override
  Widget build(BuildContext context) {
    final isRootAdmin = PlatformRootAdmin.isRoot(admin.uid);
    final roleLabel = PlatformAdminRoles.label(admin.role);

    final permissionCount =
        admin.permissions.contains(PlatformPermissionKeys.all)
        ? PlatformPermissionKeys.assignableValues.length
        : admin.permissions.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (isRootAdmin) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('根管理員為永久最高權限，不能從平台後台修改')),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlatformUserPermissionPage(admin: admin),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserAvatar(isRootAdmin: isRootAdmin, enabled: admin.enabled),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            admin.name.trim().isEmpty
                                ? roleLabel
                                : admin.name.trim(),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _StatusChip(enabled: admin.enabled),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      admin.email.trim().isEmpty
                          ? '尚未設定 Email'
                          : admin.email.trim(),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: isRootAdmin
                              ? Icons.workspace_premium
                              : Icons.badge_outlined,
                          label: roleLabel,
                        ),
                        _InfoChip(
                          icon: Icons.key_outlined,
                          label: isRootAdmin
                              ? '全部最高權限'
                              : '$permissionCount 項權限',
                        ),
                        if (isRootAdmin)
                          const _InfoChip(
                            icon: Icons.lock_outline,
                            label: '不可修改',
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'UID：${admin.uid}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isRootAdmin ? Icons.lock_outline : Icons.chevron_right_rounded,
                color: isRootAdmin ? Colors.orange : Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.isRootAdmin, required this.enabled});

  final bool isRootAdmin;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = !enabled
        ? Colors.grey.shade200
        : isRootAdmin
        ? Colors.amber.shade100
        : Colors.blue.shade50;

    final foregroundColor = !enabled
        ? Colors.grey
        : isRootAdmin
        ? Colors.orange.shade800
        : Colors.blue;

    return CircleAvatar(
      radius: 25,
      backgroundColor: backgroundColor,
      child: Icon(
        isRootAdmin
            ? Icons.workspace_premium
            : Icons.admin_panel_settings_outlined,
        color: foregroundColor,
        size: 28,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: enabled ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Text(
        enabled ? '已啟用' : '已停用',
        style: TextStyle(
          color: enabled ? Colors.green.shade700 : Colors.red.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('目前沒有平台人員資料', textAlign: TextAlign.center),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
