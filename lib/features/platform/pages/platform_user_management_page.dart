// 檔案名稱：lib/features/platform/pages/platform_user_management_page.dart
// 功能說明：平台人員名單、搜尋篩選與桌機側欄；編輯改到獨立頁面。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/constants/platform_root_admin.dart';
import '../../../core/models/platform_admin_model.dart';
import '../../../core/services/platform_admin_service.dart';
import '../../../core/services/platform_permission_catalog.dart';
import 'platform_user_create_page.dart';
import 'platform_user_permission_page.dart';

class PlatformUserManagementPage extends StatelessWidget {
  const PlatformUserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PlatformAdminService.instance.hasPermission(
        PlatformPermissionKeys.managePlatformAdmins,
      ),
      builder: (context, permissionSnapshot) {
        if (permissionSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (permissionSnapshot.hasError || permissionSnapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('平台人員與權限')),
            body: const Center(child: Text('你沒有管理平台人員的權限')),
          );
        }
        return const _PlatformUserDirectory();
      },
    );
  }
}

class _PlatformUserDirectory extends StatefulWidget {
  const _PlatformUserDirectory();

  @override
  State<_PlatformUserDirectory> createState() => _PlatformUserDirectoryState();
}

class _PlatformUserDirectoryState extends State<_PlatformUserDirectory> {
  final TextEditingController _searchController = TextEditingController();
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  String? _selectedUid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PlatformAdminModel> _visible(List<PlatformAdminModel> admins) {
    final String query = _searchController.text.trim().toLowerCase();
    return admins.where((PlatformAdminModel admin) {
      if (_roleFilter != 'all' && admin.role != _roleFilter) return false;
      if (_statusFilter == 'enabled' && !admin.enabled) return false;
      if (_statusFilter == 'disabled' && admin.enabled) return false;
      if (query.isEmpty) return true;
      return admin.name.toLowerCase().contains(query) ||
          admin.email.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _open(PlatformAdminModel admin, {int tab = 0}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlatformUserPermissionPage(admin: admin, initialTab: tab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('平台人員與權限')),
      body: StreamBuilder<List<PlatformAdminModel>>(
        stream: PlatformAdminService.instance.streamAdmins(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('讀取平台人員失敗：${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<PlatformAdminModel> admins =
              snapshot.data ?? <PlatformAdminModel>[];
          final List<PlatformAdminModel> visible = _visible(admins);
          PlatformAdminModel? selected;
          for (final PlatformAdminModel admin in admins) {
            if (admin.uid == _selectedUid) selected = admin;
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth >= 960;
              final Widget directory = Column(
                children: [
                  _StatsBar(admins: admins),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: '搜尋姓名或 Email',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            DropdownButton<String>(
                              value: _roleFilter,
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('全部角色')),
                                DropdownMenuItem(value: PlatformAdminRoles.superAdmin, child: Text('最高管理員')),
                                DropdownMenuItem(value: PlatformAdminRoles.platformAdmin, child: Text('平台管理員')),
                                DropdownMenuItem(value: PlatformAdminRoles.developerAdmin, child: Text('開發管理員')),
                                DropdownMenuItem(value: PlatformAdminRoles.platformStaff, child: Text('平台員工')),
                              ],
                              onChanged: (String? value) {
                                if (value == null) return;
                                setState(() => _roleFilter = value);
                              },
                            ),
                            DropdownButton<String>(
                              value: _statusFilter,
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('全部狀態')),
                                DropdownMenuItem(value: 'enabled', child: Text('啟用')),
                                DropdownMenuItem(value: 'disabled', child: Text('停用')),
                              ],
                              onChanged: (String? value) {
                                if (value == null) return;
                                setState(() => _statusFilter = value);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(child: Text('沒有符合條件的平台人員'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final PlatformAdminModel admin = visible[index];
                              return _UserTile(
                                admin: admin,
                                selected: admin.uid == _selectedUid,
                                onTap: () {
                                  if (wide) {
                                    setState(() => _selectedUid = admin.uid);
                                  } else {
                                    _open(admin);
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
              if (!wide) return directory;
              return Row(
                children: [
                  Expanded(child: directory),
                  SizedBox(
                    width: 360,
                    child: _DetailPanel(
                      admin: selected,
                      onEdit: (int tab) {
                        if (selected == null) return;
                        _open(selected, tab: tab);
                      },
                    ),
                  ),
                ],
              );
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

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.admins});

  final List<PlatformAdminModel> admins;

  @override
  Widget build(BuildContext context) {
    final int enabled = admins.where((admin) => admin.enabled).length;
    final Map<String, int> roles = <String, int>{};
    for (final PlatformAdminModel admin in admins) {
      final String label = PlatformAdminRoles.label(admin.role);
      roles[label] = (roles[label] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Stat(label: '平台人員', value: '${admins.length}'),
          _Stat(label: '啟用', value: '$enabled'),
          _Stat(label: '停用', value: '${admins.length - enabled}'),
          for (final MapEntry<String, int> entry in roles.entries)
            _Stat(label: entry.key, value: '${entry.value}'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label $value'),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.admin,
    required this.selected,
    required this.onTap,
  });

  final PlatformAdminModel admin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool root = PlatformRootAdmin.isRoot(admin.uid);
    final int count = root || admin.role == PlatformAdminRoles.superAdmin
        ? PlatformPermissionKeys.assignableValues.length
        : PlatformPermissionCatalog.enabledCount(admin.permissions);
    final String? lastLogin = _formatTime(admin.lastLoginAt);
    return Card(
      color: selected ? Colors.blue.shade50 : null,
      child: ListTile(
        minVerticalPadding: 12,
        title: Text(admin.name.trim().isEmpty ? '未命名' : admin.name.trim()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(admin.email.trim().isEmpty ? '尚未設定 Email' : admin.email.trim()),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(PlatformAdminRoles.label(admin.role)),
                Text(admin.enabled ? '已啟用' : '已停用'),
                Text(root ? '全部權限' : '$count 項權限'),
                if (lastLogin != null) Text('最後登入 $lastLogin'),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.admin, required this.onEdit});

  final PlatformAdminModel? admin;
  final void Function(int tab) onEdit;

  @override
  Widget build(BuildContext context) {
    final PlatformAdminModel? person = admin;
    if (person == null) {
      return const Center(child: Text('選擇一位平台人員後，可在這裡查看與編輯。'));
    }
    return Material(
      elevation: 1,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            person.name.trim().isEmpty ? '未命名' : person.name.trim(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(person.email),
          const SizedBox(height: 8),
          Text(PlatformAdminRoles.label(person.role)),
          Text(person.enabled ? '已啟用' : '已停用'),
          if (person.lastLoginAt != null)
            Text('最後登入 ${_formatTime(person.lastLoginAt)}'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => onEdit(0),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: const Text('編輯資料'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => onEdit(2),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: const Text('編輯權限'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => onEdit(1),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: const Text('調整啟用狀態'),
          ),
        ],
      ),
    );
  }
}

String? _formatTime(Timestamp? value) {
  if (value == null) return null;
  final DateTime time = value.toDate().toLocal();
  final String month = time.month.toString().padLeft(2, '0');
  final String day = time.day.toString().padLeft(2, '0');
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
