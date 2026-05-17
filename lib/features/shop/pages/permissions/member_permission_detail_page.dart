// lib/features/shop/pages/permissions/member_permission_detail_page.dart
// 👤 成員權限編輯頁
//
// 用途：
// - 從權限設定頁的「目前成員」點進來
// - 查看指定成員角色與已開啟權限
// - 可直接修改該成員權限並儲存

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';

class MemberPermissionDetailPage extends StatefulWidget {
  const MemberPermissionDetailPage({
    super.key,
    required this.shopId,
    required this.memberDocId,
    required this.email,
    required this.role,
    required this.roleLabel,
    required this.permissions,
    required this.currentUserRole,
    required this.permissionLabelBuilder,
  });

  final String shopId;
  final String memberDocId;
  final String email;
  final String role;
  final String roleLabel;
  final Map<String, bool> permissions;
  final String? currentUserRole;
  final String Function(String key) permissionLabelBuilder;

  @override
  State<MemberPermissionDetailPage> createState() =>
      _MemberPermissionDetailPageState();
}

class _MemberPermissionDetailPageState
    extends State<MemberPermissionDetailPage> {
  late Map<String, bool> _permissions;
  bool _saving = false;
  bool get _isOwnerMember => widget.role == ShopRoles.owner;

bool get _canEdit => !_isOwnerMember;

  @override
  void initState() {
    super.initState();

    _permissions = Map<String, bool>.from(
      widget.permissions,
    );
  }

Future<void> _deleteMember() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('刪除成員'),
        content: Text('確定要刪除 ${widget.email} 嗎？\n刪除後對方將無法進入此店家後台。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      );
    },
  );

  if (confirm != true) return;

  try {
    await ShopService.instance.removeMember(
      memberDocId: widget.memberDocId,
      shopId: widget.shopId,
      operatorUid: user.uid,
      operatorRole: widget.currentUserRole ?? 'owner',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('成員已刪除')),
    );

    Navigator.pop(context);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('刪除失敗：$e')),
    );
  }
}

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
    });

    try {
      await ShopService.instance.updateMemberPermission(
        memberDocId: widget.memberDocId,
        shopId: widget.shopId,
        role: widget.role,
        permissions: _permissions,
        operatorUid: user.uid,
        operatorRole: widget.currentUserRole ?? 'owner',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('權限更新成功')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗：$e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionKeys = ShopPermissionKeys.all;

    return Scaffold(
      appBar: AppBar(
  title: const Text('成員權限'),
  actions: [
    if (!_isOwnerMember)
      IconButton(
        onPressed: _deleteMember,
        icon: const Icon(Icons.delete_outline),
      ),
  ],
),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(widget.email),
              subtitle: Text('角色：${widget.roleLabel}'),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '權限開關',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  ...permissionKeys.map((key) {
  final value = _isOwnerMember
      ? true
      : (_permissions[key] ?? false);

  return SwitchListTile(
    value: value,
    title: Text(
      widget.permissionLabelBuilder(key),
    ),
    onChanged: _canEdit
        ? (value) {
            setState(() {
              _permissions[key] = value;
            });
          }
        : null,
  );
}),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_saving || !_canEdit) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? '儲存中...' : '儲存權限'),
            ),
          ),
        ],
      ),
    );
  }
}