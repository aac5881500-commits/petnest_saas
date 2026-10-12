// 檔案名稱：lib/features/shop/pages/shop_member_invite_page.dart
// 功能說明：新增成員邀請。與既有成員編輯分開，沿用 Email 邀請，不建立 UID。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_permission_catalog.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/shop_permission_v2_editor.dart';

class ShopMemberInvitePage extends StatefulWidget {
  const ShopMemberInvitePage({
    super.key,
    required this.shopId,
    required this.operatorRole,
    required this.operatorPermissions,
    required this.canPickManager,
    this.managerSlotMessage,
  });

  final String shopId;
  final String operatorRole;
  final Map<String, bool> operatorPermissions;
  final bool canPickManager;
  final String? managerSlotMessage;

  @override
  State<ShopMemberInvitePage> createState() => _ShopMemberInvitePageState();
}

class _ShopMemberInvitePageState extends State<ShopMemberInvitePage> {
  final TextEditingController _emailController = TextEditingController();
  final Map<String, bool> _permissions = ShopPermissionCatalog.emptyGrantable();
  String _role = ShopRoles.staff;
  bool _saving = false;
  bool _allowPop = false;

  bool get _dirty =>
      _emailController.text.trim().isNotEmpty ||
      _role != ShopRoles.staff ||
      _permissions.values.any((bool value) => value);

  Set<String> get _lockedKeys {
    if (widget.operatorRole == ShopRoles.owner) return const <String>{};
    return ShopPermissionCatalog.items
        .where((ShopPermissionItem item) {
          return widget.operatorPermissions[item.key] != true ||
              item.key == ShopPermissionKeys.manageStaff;
        })
        .map((ShopPermissionItem item) => item.key)
        .toSet();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (!_dirty) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('尚未送出邀請'),
          content: const Text('離開後這次輸入不會保留。'),
          actions: <Widget>[
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
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _send() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入有效的 Email')));
      return;
    }
    if (_role == ShopRoles.manager && widget.managerSlotMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.managerSlotMessage!)));
      return;
    }
    final Map<String, bool> permissions = widget.operatorRole == ShopRoles.owner
        ? _permissions
        : ShopPermissionCatalog.clampForOperator(
            operatorRole: widget.operatorRole,
            operatorPermissions: widget.operatorPermissions,
            requested: _permissions,
          );
    final List<ShopPermissionChange> changes = ShopPermissionCatalog.diff(
      ShopPermissionCatalog.emptyGrantable(),
      permissions,
    );
    final bool? agreed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final String opened = changes
            .where((ShopPermissionChange change) => change.enabled)
            .map((ShopPermissionChange change) => change.title)
            .join('、');
        return AlertDialog(
          title: const Text('送出邀請'),
          content: Text(
            'Email：$email\n'
            '角色：${ShopRoles.label(_role)}\n'
            '開啟：${opened.isEmpty ? '無' : opened}\n\n'
            '對方接受後才會建立成員，現在不會建立帳號。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('送出'),
            ),
          ],
        );
      },
    );
    if (agreed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ShopService.instance.upsertMemberPermissionByEmail(
        shopId: widget.shopId,
        email: email,
        role: _role,
        permissions: permissions,
        operatorUid: user.uid,
        operatorRole: widget.operatorRole,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('邀請失敗：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('邀請成員'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _leave,
          ),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@gmail.com',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ShopPermissionV2Editor(
                role: _role,
                permissions: _permissions,
                canEdit: !_saving,
                canPickManager: widget.canPickManager,
                managerSlotMessage: widget.managerSlotMessage,
                lockedKeys: _lockedKeys,
                onRoleChanged: (String role) {
                  if (role == ShopRoles.manager &&
                      widget.managerSlotMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(widget.managerSlotMessage!)),
                    );
                    return;
                  }
                  setState(() => _role = role);
                },
                onToggle: (String key, bool value) {
                  setState(() => _permissions[key] = value);
                },
                onToggleCategory:
                    (ShopPermissionCategory category, bool value) {
                      setState(() {
                        for (final ShopPermissionItem item in category.items) {
                          if (_lockedKeys.contains(item.key)) continue;
                          _permissions[item.key] = value;
                        }
                      });
                    },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : _send,
                    child: Text(_saving ? '送出中...' : '送出邀請'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
