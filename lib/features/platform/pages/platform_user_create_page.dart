// lib/features/platform/pages/platform_user_create_page.dart
// ➕ 新增平台人員頁
// 功能：由具備平台人員管理權限的管理員，新增開發管理員或平台員工，
// 並設定帳號啟用狀態與初始平台權限。
// 即使直接開啟此頁，也會先驗證 managePlatformAdmins 權限。

import 'package:flutter/material.dart';

import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/services/platform_admin_service.dart';

class PlatformUserCreatePage extends StatefulWidget {
  const PlatformUserCreatePage({super.key});

  @override
  State<PlatformUserCreatePage> createState() => _PlatformUserCreatePageState();
}

class _PlatformUserCreatePageState extends State<PlatformUserCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String _role = PlatformAdminRoles.platformStaff;
  bool _enabled = true;
  bool _saving = false;

  final Set<String> _selectedPermissions = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    try {
      await PlatformAdminService.instance.createAdminByEmail(
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
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
    return FutureBuilder<bool>(
      future: PlatformAdminService.instance.hasPermission(
        PlatformPermissionKeys.managePlatformAdmins,
      ),
      builder: (context, permissionSnapshot) {
        if (permissionSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (permissionSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('新增平台人員')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '讀取平台權限失敗：${permissionSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final canManageAdmins = permissionSnapshot.data ?? false;

        if (!canManageAdmins) {
          return Scaffold(
            appBar: AppBar(title: const Text('新增平台人員')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 56, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      '你沒有新增平台人員的權限',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '請由根管理員或其他授權人員分配「管理平台員工與權限」。',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

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
      },
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
            const Text('請輸入員工註冊 PetNest 時使用的 Email，系統會自動查找對應帳號。'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '姓名或稱呼',
                hintText: '請輸入平台人員姓名',
                prefixIcon: Icon(Icons.person_outline),
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
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '登入 Email',
                hintText: '請輸入員工的 PetNest 登入 Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return '請輸入 Email';
                }

                final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                if (!emailPattern.hasMatch(text)) {
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
              onChanged: _saving
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
              title: const Text('建立後立即啟用'),
              subtitle: Text(_enabled ? '建立後可以立即使用已分配權限' : '建立後先保持停用狀態'),
              onChanged: _saving
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
                onChanged: _saving
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
