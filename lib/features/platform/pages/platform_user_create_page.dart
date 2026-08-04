// lib/features/platform/pages/platform_user_create_page.dart
// ➕ 新增平台人員頁
// 功能：由根管理員新增開發管理員或平台員工，
// 並設定帳號啟用狀態與初始平台權限。

import 'package:flutter/material.dart';

import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/constants/platform_root_admin.dart';
import '../../../core/services/platform_admin_service.dart';

class PlatformUserCreatePage extends StatefulWidget {
  const PlatformUserCreatePage({super.key});

  @override
  State<PlatformUserCreatePage> createState() => _PlatformUserCreatePageState();
}

class _PlatformUserCreatePageState extends State<PlatformUserCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final _uidController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String _role = PlatformAdminRoles.platformStaff;
  bool _enabled = true;
  bool _saving = false;

  final Set<String> _selectedPermissions = <String>{};

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _uidController.text.trim();

    if (PlatformRootAdmin.isRoot(uid)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此 UID 已是永久根管理員，不需要再次新增')));
      return;
    }

    setState(() => _saving = true);

    try {
      await PlatformAdminService.instance.createAdmin(
        uid: uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _role,
        enabled: _enabled,
        permissions: _selectedPermissions.toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('平台人員已新增')));

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('新增失敗：$error')));
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
      appBar: AppBar(title: const Text('新增平台人員')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAccountCard(),
            const SizedBox(height: 16),
            _buildRoleCard(),
            const SizedBox(height: 16),
            _buildPermissionCard(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: Text(_saving ? '建立中' : '建立平台人員'),
            ),
            const SizedBox(height: 24),
          ],
        ),
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
              '帳號資料',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('請先到 Firebase Authentication 找到該帳號的 UID。'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _uidController,
              decoration: const InputDecoration(
                labelText: 'Firebase UID',
                hintText: '貼上 Authentication 使用者 UID',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return '請輸入 Firebase UID';
                }

                if (text.length < 10) {
                  return 'UID 格式看起來不正確';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '姓名或稱呼',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return '請輸入姓名或稱呼';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '登入 Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return '請輸入 Email';
                }

                if (!text.contains('@')) {
                  return 'Email 格式不正確';
                }

                return null;
              },
            ),
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
              '角色與狀態',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
              onChanged: (value) {
                if (value == null) return;

                setState(() => _role = value);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              title: const Text('建立後立即啟用'),
              subtitle: Text(_enabled ? '建立後可以立即使用已分配權限' : '建立後先保持停用狀態'),
              onChanged: (value) {
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
                '初始權限',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('只開啟此人員目前工作需要的權限，之後仍可修改。'),
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
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                subtitle: description.isEmpty ? null : Text(description),
                onChanged: (value) {
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
