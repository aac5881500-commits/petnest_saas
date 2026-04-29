//lib/features/shop/pages/shop_permission_settings_page.dart
//實際操作權限的畫面

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopPermissionSettingsPage extends StatefulWidget {
  const ShopPermissionSettingsPage({
    super.key,
    required this.shopId,
    required this.currentUserRole,
  });

  final String shopId;
  final String? currentUserRole;

  @override
  State<ShopPermissionSettingsPage> createState() =>
      _ShopPermissionSettingsPageState();
}

class _ShopPermissionSettingsPageState
    extends State<ShopPermissionSettingsPage> {
  final _emailController = TextEditingController();

  String _selectedRole = ShopRoles.staff;
  bool _saving = false;

  late Map<String, bool> _permissions;

  bool get _isOwner => widget.currentUserRole == ShopRoles.owner;

  @override
  void initState() {
    super.initState();
    _permissions = ShopService.instance.staffDefaultPermissions();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _permissionLabel(String key) {
    switch (key) {
      case ShopPermissionKeys.manageMembers:
        return '管理權限設定';
      case ShopPermissionKeys.editBasicInfo:
        return '修改店家基本資料';
      case ShopPermissionKeys.editBusinessInfo:
        return '修改營業資訊';
      case ShopPermissionKeys.editMedia:
        return '修改 Logo / 封面';
      case ShopPermissionKeys.manageBookings:
        return '管理預約功能';
      case ShopPermissionKeys.viewReports:
        return '查看表格統計';
      case ShopPermissionKeys.viewActionLogs:
        return '查看動作記錄';
      default:
        return key;
    }
  }

  void _applyRoleTemplate(String role) {
    setState(() {
      _selectedRole = role;
      _permissions = Map<String, bool>.from(
        ShopService.instance.defaultPermissionsByRole(role),
      );
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入 Email')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ShopService.instance.upsertMemberPermissionByEmail(
        shopId: widget.shopId,
        email: email,
        role: _selectedRole,
        permissions: _permissions,
        operatorUid: user.uid,
        operatorRole: widget.currentUserRole ?? ShopRoles.owner,
      );

      _emailController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('權限設定已儲存')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  Widget _buildRoleSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: '角色',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: ShopRoles.manager,
                  child: Text('主管'),
                ),
                DropdownMenuItem(
                  value: ShopRoles.staff,
                  child: Text('員工'),
                ),
              ],
              onChanged: !_isOwner
                  ? null
                  : (value) {
                      if (value == null) return;
                      _applyRoleTemplate(value);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              enabled: _isOwner,
              decoration: const InputDecoration(
                labelText: '員工 Email',
                hintText: 'example@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '功能開關',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            ...ShopPermissionKeys.all.map((key) {
              return SwitchListTile(
                value: _permissions[key] ?? false,
                onChanged: !_isOwner
                    ? null
                    : (value) {
                        setState(() {
                          _permissions[key] = value;
                        });
                      },
                title: Text(_permissionLabel(key)),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (!_isOwner || _saving) ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isOwner ? '儲存權限設定' : '目前只有老闆可修改'),
      ),
    );
  }

  Widget _buildMemberList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ShopService.instance.streamShopMembers(widget.shopId),
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
                if (members.isEmpty)
                  const ListTile(
                    title: Text('目前沒有其他成員'),
                  ),
                ...members.map((member) {
                  final role = member['role']?.toString() ?? '-';
                  final email = member['email']?.toString() ?? '-';
                  final permissions = ShopService.instance.normalizePermissions(
                    member['permissions'],
                    role: role,
                  );
                  final enabledCount =
                      permissions.values.where((e) => e).length;

                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(email),
                    subtitle: Text('角色：$role｜啟用權限：$enabledCount'),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInviteList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ShopService.instance.streamShopMemberInvites(widget.shopId),
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
                if (invites.isEmpty)
                  const ListTile(
                    title: Text('目前沒有待綁定邀請'),
                  ),
                ...invites.map((invite) {
                  return ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: Text(invite['email']?.toString() ?? '-'),
                    subtitle: Text('角色：${invite['role'] ?? '-'}'),
                    trailing: _isOwner
                        ? IconButton(
                            onPressed: () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;

                              await ShopService.instance.removeMemberInvite(
                                inviteDocId: invite['id'],
                                shopId: widget.shopId,
                                operatorUid: user.uid,
                                operatorRole:
                                    widget.currentUserRole ?? ShopRoles.owner,
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

  Widget _buildActionLogs() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ActionLogService.instance.streamShopLogs(widget.shopId),
      builder: (context, snapshot) {
        final logs = (snapshot.data ?? []).take(20).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '動作記錄',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                if (logs.isEmpty)
                  const ListTile(
                    title: Text('目前沒有動作記錄'),
                  ),
                ...logs.map((log) {
                  final action = log['action']?.toString() ?? '-';
                  final targetType = log['targetType']?.toString() ?? '-';
                  final operatorRole = log['operatorRole']?.toString() ?? '-';

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text(action),
                    subtitle: Text('目標：$targetType｜操作者角色：$operatorRole'),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('權限設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '老闆可用 Email 指定主管或員工。\n'
              '對方先註冊 / 登入，只要 Email 有被指定，就會自動看到該店後台入口。',
            ),
          ),
          const SizedBox(height: 16),
          _buildRoleSelector(),
          const SizedBox(height: 12),
          _buildPermissionCard(),
          const SizedBox(height: 12),
          _buildSaveButton(),
          const SizedBox(height: 20),
          _buildMemberList(),
          const SizedBox(height: 12),
          _buildInviteList(),
          const SizedBox(height: 12),
          _buildActionLogs(),
        ],
      ),
    );
  }
}
