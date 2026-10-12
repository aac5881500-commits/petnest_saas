// 檔案名稱：lib/features/platform/pages/platform_user_permission_page.dart
// 功能說明：以草稿編輯平台人員帳號、角色、個別權限，確認後一次儲存。

import 'package:flutter/material.dart';

import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/constants/platform_root_admin.dart';
import '../../../core/models/platform_admin_model.dart';
import '../../../core/services/platform_admin_service.dart';
import '../../../core/services/platform_permission_catalog.dart';
import '../widgets/platform_permission_editor.dart';
import '../widgets/platform_user_change_log.dart';

class PlatformUserPermissionPage extends StatefulWidget {
  const PlatformUserPermissionPage({
    super.key,
    required this.admin,
    this.initialTab = 0,
  });

  final PlatformAdminModel admin;
  final int initialTab;

  @override
  State<PlatformUserPermissionPage> createState() =>
      _PlatformUserPermissionPageState();
}

class _PlatformUserPermissionPageState extends State<PlatformUserPermissionPage> {
  late String _role;
  late bool _enabled;
  late Set<String> _selectedPermissions;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  bool _saving = false;
  bool _operatorReady = false;
  Set<String>? _grantableKeys;
  bool _canGrantAll = false;
  late final Future<bool> _canManage = PlatformAdminService.instance
      .hasPermission(PlatformPermissionKeys.managePlatformAdmins);

  bool get _isRootTarget => PlatformRootAdmin.isRoot(widget.admin.uid);

  bool get _isSuperTarget =>
      widget.admin.role == PlatformAdminRoles.superAdmin;

  bool get _locked => _isRootTarget || _isSuperTarget;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.admin.name);
    _emailController = TextEditingController(text: widget.admin.email);
    _role = widget.admin.role;
    _enabled = widget.admin.enabled;
    _selectedPermissions = widget.admin.permissions
        .where(PlatformPermissionKeys.assignableValues.contains)
        .toSet();
    _nameController.addListener(_refresh);
    _emailController.addListener(_refresh);
    _loadOperator();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadOperator() async {
    try {
      final String? uid = PlatformAdminService.instance.currentUserId;
      final PlatformAdminModel? operator =
          await PlatformAdminService.instance.getCurrentAdmin();
      if (!mounted) return;
      final bool canGrantAll = PlatformRootAdmin.isRoot(uid) ||
          operator?.role == PlatformAdminRoles.superAdmin;
      setState(() {
        _operatorReady = true;
        _canGrantAll = canGrantAll;
        _grantableKeys = canGrantAll
            ? null
            : operator?.permissions
                .where(PlatformPermissionKeys.assignableValues.contains)
                .where(
                  (String key) => !PlatformPermissionCatalog.isSuperOnly(key),
                )
                .toSet();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _operatorReady = true;
        _canGrantAll = false;
        _grantableKeys = <String>{};
      });
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _emailController.removeListener(_refresh);
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Set<String> _editable(Set<String> source) {
    return source.where((String key) {
      if (!PlatformPermissionKeys.assignableValues.contains(key)) return false;
      if (PlatformPermissionCatalog.isSuperOnly(key)) return false;
      if (!_canGrantAll && !(_grantableKeys?.contains(key) ?? false)) {
        return false;
      }
      return true;
    }).toSet();
  }

  bool get _dirty {
    final Set<String> before = _editable(widget.admin.permissions.toSet());
    final Set<String> after = _editable(_selectedPermissions);
    return _nameController.text.trim() != widget.admin.name.trim() ||
        _emailController.text.trim().toLowerCase() !=
            widget.admin.email.trim().toLowerCase() ||
        _role != widget.admin.role ||
        _enabled != widget.admin.enabled ||
        before.length != after.length ||
        !before.containsAll(after);
  }

  Future<void> _save() async {
    if (_saving || _locked) return;
    FocusScope.of(context).unfocus();
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim().toLowerCase();
    final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (name.isEmpty) {
      _snack('請輸入姓名或稱呼');
      return;
    }
    if (!emailPattern.hasMatch(email)) {
      _snack('請輸入正確的 Email');
      return;
    }
    if (!PlatformAdminRoles.assignableRoles.contains(_role)) {
      _snack('請先選擇平台管理員、開發管理員或平台員工');
      return;
    }
    if (!_dirty) {
      _snack('沒有需要儲存的變更');
      return;
    }

    setState(() => _saving = true);
    final Set<String> before = _editable(widget.admin.permissions.toSet());
    final Set<String> after = _editable(_selectedPermissions);
    final List<String> added = PlatformPermissionCatalog.added(before, after);
    final List<String> removed = PlatformPermissionCatalog.removed(before, after);
    final bool risk = PlatformPermissionCatalog.needsRiskNotice(
      previousRole: widget.admin.role,
      nextRole: _role,
      previousEnabled: widget.admin.enabled,
      nextEnabled: _enabled,
      added: added,
      removed: removed,
    );
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('確認儲存平台人員'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('操作對象：$name'),
                Text(email),
                const SizedBox(height: 8),
                Text('原本角色：${PlatformAdminRoles.label(widget.admin.role)}'),
                Text('修改後角色：${PlatformAdminRoles.label(_role)}'),
                Text('啟用狀態：${widget.admin.enabled ? '已啟用' : '已停用'} → ${_enabled ? '已啟用' : '已停用'}'),
                const SizedBox(height: 8),
                Text('新增權限：${_permissionNames(added)}'),
                Text('移除權限：${_permissionNames(removed)}'),
                if (risk) ...[
                  const SizedBox(height: 12),
                  const Text('這次包含角色、高風險權限、停用管理帳號，或金流與系統安全權限變更。確認後才會一次寫入。'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回修改'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認儲存'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      await PlatformAdminService.instance.savePlatformUser(
        uid: widget.admin.uid,
        name: name,
        email: email,
        role: _role,
        enabled: _enabled,
        permissions: after.toList(),
      );
      if (!mounted) return;
      _snack('平台人員資料已儲存');
      Navigator.pop(context, true);
    } on StateError catch (error) {
      if (!mounted) return;
      _snack(error.message);
    } catch (error) {
      if (!mounted) return;
      _snack('儲存失敗，資料沒有變更。$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _permissionNames(List<String> keys) {
    if (keys.isEmpty) return '無';
    return keys.map(PlatformPermissionKeys.label).join('、');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmLeave() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('尚未儲存'),
          content: const Text('離開後，這次的角色、權限與啟用狀態變更不會寫入。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('繼續編輯'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('離開'),
            ),
          ],
        );
      },
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final int initialTab = widget.initialTab.clamp(0, 3);
    return FutureBuilder<bool>(
      future: _canManage,
      builder: (context, permissionSnapshot) {
        if (permissionSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (permissionSnapshot.hasError || permissionSnapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('平台人員')),
            body: const Center(child: Text('你沒有編輯平台人員的權限')),
          );
        }
        return DefaultTabController(
          length: 4,
          initialIndex: initialTab,
          child: PopScope(
            canPop: !_dirty && !_saving,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop || _saving) return;
              _confirmLeave();
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(widget.admin.name.trim().isEmpty
                    ? '平台人員'
                    : widget.admin.name.trim()),
                bottom: const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: '帳號資料'),
                    Tab(text: '角色設定'),
                    Tab(text: '個別權限'),
                    Tab(text: '操作紀錄'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _scroll(_accountTab()),
                  _scroll(_roleTab()),
                  _scroll(_permissionTab()),
                  _scroll(PlatformUserChangeLog(uid: widget.admin.uid)),
                ],
              ),
              bottomNavigationBar: _locked
                  ? null
                  : SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(_saving ? '儲存中' : '儲存變更'),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _scroll(Widget child) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [child, const SizedBox(height: 24)],
    );
  }

  Widget _accountTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          enabled: !_locked && !_saving,
          decoration: const InputDecoration(
            labelText: '姓名或稱呼',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          enabled: !_locked && !_saving,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SelectableText('UID：${widget.admin.uid}'),
        if (_locked) ...[
          const SizedBox(height: 12),
          const Text('最高管理員與永久根管理員不能從這個畫面修改。'),
        ],
      ],
    );
  }

  Widget _roleTab() {
    final List<String> roles = <String>[
      ...PlatformAdminRoles.assignableRoles,
      if (!PlatformAdminRoles.assignableRoles.contains(_role)) _role,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _role,
          decoration: const InputDecoration(
            labelText: '平台角色',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final String role in roles)
              DropdownMenuItem(
                value: role,
                enabled: PlatformAdminRoles.assignableRoles.contains(role),
                child: Text(PlatformAdminRoles.label(role)),
              ),
          ],
          onChanged: _locked || _saving
              ? null
              : (String? value) {
                  if (value == null) return;
                  if (!PlatformAdminRoles.assignableRoles.contains(value)) {
                    return;
                  }
                  setState(() => _role = value);
                },
        ),
        const SizedBox(height: 8),
        const Text('角色決定管理層級。實際功能仍以個別權限為準，不能超過你自己擁有的範圍。'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          title: const Text('啟用平台帳號'),
          subtitle: Text(_enabled ? '可以使用已授權的功能' : '停用後不能使用平台權限'),
          onChanged: _locked || _saving
              ? null
              : (bool value) => setState(() => _enabled = value),
        ),
      ],
    );
  }

  Widget _permissionTab() {
    if (!_operatorReady) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return PlatformPermissionEditor(
      selected: _selectedPermissions,
      grantableKeys: _grantableKeys,
      locked: _locked || _saving,
      onChanged: (String key, bool enabled) {
        setState(() {
          if (enabled) {
            _selectedPermissions.add(key);
          } else {
            _selectedPermissions.remove(key);
          }
        });
      },
    );
  }
}
