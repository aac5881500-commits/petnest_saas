// lib/features/platform/pages/platform_user_permission_page.dart
// 🔐 平台人員角色與權限編輯頁
// 功能：調整開發管理員與平台員工的姓名、Email、角色、
// 啟用狀態及個別權限。
// 根管理員為永久最高權限，不允許透過此頁修改。

import 'package:flutter/material.dart';

import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/constants/platform_root_admin.dart';
import '../../../core/models/platform_admin_model.dart';
import '../../../core/services/platform_admin_service.dart';

class PlatformUserPermissionPage extends StatefulWidget {
  const PlatformUserPermissionPage({super.key, required this.admin});

  final PlatformAdminModel admin;

  @override
  State<PlatformUserPermissionPage> createState() =>
      _PlatformUserPermissionPageState();
}

class _PlatformUserPermissionPageState
    extends State<PlatformUserPermissionPage> {
  late String _role;
  late bool _enabled;
  late Set<String> _selectedPermissions;

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  bool _saving = false;

  bool get _isRootAdmin {
    return PlatformRootAdmin.isRoot(widget.admin.uid);
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.admin.name);

    _emailController = TextEditingController(text: widget.admin.email);

    _role = widget.admin.role == PlatformAdminRoles.developerAdmin
        ? PlatformAdminRoles.developerAdmin
        : PlatformAdminRoles.platformStaff;

    _enabled = widget.admin.enabled;

    _selectedPermissions = widget.admin.permissions
        .where(PlatformPermissionKeys.assignableValues.contains)
        .toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (_isRootAdmin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('根管理員為永久最高權限，不能修改')));
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    try {
      await PlatformAdminService.instance.updateBasicInfo(
        uid: widget.admin.uid,
        name: _nameController.text,
        email: _emailController.text,
      );

      await PlatformAdminService.instance.updateRoleAndPermissions(
        uid: widget.admin.uid,
        role: _role,
        permissions: _selectedPermissions.toList(),
      );

      if (_enabled != widget.admin.enabled) {
        await PlatformAdminService.instance.updateEnabled(
          uid: widget.admin.uid,
          enabled: _enabled,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('平台人員資料與權限已儲存')));

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _updatePermission(String permission, bool enabled) {
    setState(() {
      if (enabled) {
        _selectedPermissions.add(permission);
      } else {
        _selectedPermissions.remove(permission);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('角色與權限設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAccountCard(),
          const SizedBox(height: 16),
          _buildRoleCard(),
          const SizedBox(height: 16),
          _buildPermissionCard(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving || _isRootAdmin ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '儲存中' : '儲存平台人員資料'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '平台人員資料',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameController,
              enabled: !_isRootAdmin && !_saving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '姓名或稱呼',
                hintText: '請輸入平台人員姓名',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _emailController,
              enabled: !_isRootAdmin && !_saving,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '登入 Email',
                hintText: '請輸入平台人員 Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            SelectableText(
              'UID：${widget.admin.uid}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),

            if (_isRootAdmin) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('這是永久根管理員，姓名、Email、角色、啟用狀態與最高權限不能從平台後台修改。'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '帳號角色',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: '平台角色',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PlatformAdminRoles.developerAdmin,
                  child: Text('開發管理員'),
                ),
                DropdownMenuItem(
                  value: PlatformAdminRoles.platformStaff,
                  child: Text('平台員工'),
                ),
              ],
              onChanged: _isRootAdmin || _saving
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() => _role = value);
                    },
            ),

            const SizedBox(height: 12),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              title: const Text('啟用平台帳號'),
              subtitle: Text(_enabled ? '目前可以使用已分配的平台權限' : '停用後無法使用任何平台權限'),
              onChanged: _isRootAdmin || _saving
                  ? null
                  : (value) {
                      setState(() => _enabled = value);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                '個別權限',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('只開啟此人員工作上需要使用的功能。'),
            ),
            const Divider(),

            ...PlatformPermissionKeys.assignableValues.map((permission) {
              final selected = _selectedPermissions.contains(permission);

              final description = PlatformPermissionKeys.description(
                permission,
              );

              final sensitive = PlatformPermissionKeys.isSensitive(permission);

              return SwitchListTile(
                value: selected,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(PlatformPermissionKeys.label(permission)),
                    ),
                    if (sensitive)
                      Tooltip(
                        message: '敏感權限',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: Colors.orange.shade700,
                        ),
                      ),
                  ],
                ),
                subtitle: description.isEmpty ? null : Text(description),
                onChanged: _isRootAdmin || _saving
                    ? null
                    : (value) {
                        _updatePermission(permission, value);
                      },
              );
            }),
          ],
        ),
      ),
    );
  }
}
