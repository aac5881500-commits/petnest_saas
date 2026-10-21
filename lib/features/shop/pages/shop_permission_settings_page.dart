import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
// 檔案名稱：lib/features/shop/pages/shop_permission_settings_page.dart
// 功能說明：權限與員工管理。分成員工、權限、操作紀錄，邀請與編輯分開。
// 保留：既有 shop_members、Email 邀請、權限鍵與儲存 API。
// 停用：角色切換時套用固定模板，以及三欄把紀錄塞在側邊的版面。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/shop_member_permission_service.dart';
import 'package:petnest_saas/core/services/shop_permission_catalog.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/shop_member_invite_page.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_action_log_list.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_invite_list_card.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_member_list_card.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/shop_permission_v2_editor.dart';

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

class _ShopPermissionSettingsPageState extends State<ShopPermissionSettingsPage>
    with
        SingleTickerProviderStateMixin,
        ShopDashboardLeaveAware<ShopPermissionSettingsPage> {
  @override
  bool get dashboardHasUnsavedChanges => _dirty;
  @override
  bool get dashboardIsBusy => _saving;
  @override
  Future<bool> dashboardConfirmLeave() async =>
      !_saving && await _discardIfNeeded('有尚未儲存的修改，確定離開？');

  late final TabController _tabController;

  String _selectedRole = ShopRoles.staff;
  String _baselineRole = ShopRoles.staff;
  String? _editingMemberId;
  Map<String, dynamic>? _editingMember;
  bool _saving = false;
  bool _storedOwnerOnly = false;
  bool _wide = false;
  bool _forcePop = false;

  late Map<String, bool> _permissions;
  late Map<String, bool> _baseline;

  bool get _isOwner => widget.currentUserRole == ShopRoles.owner;
  bool get _canEdit =>
      widget.currentUserRole == ShopRoles.owner ||
      widget.currentUserRole == ShopRoles.manager;
  bool get _dirty =>
      _editingMemberId != null &&
      (_selectedRole != _baselineRole ||
          !ShopPermissionCatalog.sameGrantable(_baseline, _permissions));
  bool get _editorCanEdit {
    final Map<String, dynamic>? member = _editingMember;
    if (!_canEdit || member == null) return false;
    if (member['role']?.toString() == ShopRoles.owner) return false;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (widget.currentUserRole == ShopRoles.manager &&
        member['uid']?.toString() == uid) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _permissions = ShopPermissionCatalog.emptyGrantable();
    _baseline = Map<String, bool>.from(_permissions);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, bool> _draftFrom(Map<String, dynamic> member) {
    final String role = member['role']?.toString() ?? ShopRoles.staff;
    final Map<String, bool> normalized = ShopMemberPermissionService.instance
        .normalizePermissions(member['permissions'], role: role);
    final Map<String, bool> draft = ShopPermissionCatalog.emptyGrantable();
    for (final ShopPermissionItem item in ShopPermissionCatalog.items) {
      draft[item.key] = normalized[item.key] == true;
    }
    return ShopPermissionCatalog.stripOwnerOnly(draft);
  }

  void _loadMember(Map<String, dynamic> member) {
    final String role = member['role']?.toString() == ShopRoles.manager
        ? ShopRoles.manager
        : ShopRoles.staff;
    final Map<String, bool> draft = _draftFrom(member);
    final dynamic raw = member['permissions'];
    setState(() {
      _editingMemberId = member['id']?.toString();
      _editingMember = member;
      _selectedRole = role;
      _baselineRole = role;
      _permissions = draft;
      _baseline = Map<String, bool>.from(draft);
      _storedOwnerOnly =
          raw is Map && raw[ShopPermissionKeys.managePaymentSettings] == true;
    });
  }

  Future<bool> _discardIfNeeded(String message) async {
    if (!_dirty) return true;
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('尚未儲存'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('繼續編輯'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放棄修改'),
            ),
          ],
        );
      },
    );
    return discard == true;
  }

  Future<void> _selectMember(Map<String, dynamic> member) async {
    if (member['role']?.toString() == ShopRoles.owner) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('老闆擁有全部權限，不能在這裡修改')));
      return;
    }
    if (member['id']?.toString() == _editingMemberId) {
      if (!_wide) _tabController.animateTo(1);
      return;
    }
    final bool discard = await _discardIfNeeded('要放棄這位成員尚未儲存的修改嗎？');
    if (!discard || !mounted) return;
    _loadMember(member);
    if (!_wide) _tabController.animateTo(1);
  }

  Future<void> _changeRole(
    String role,
    List<Map<String, dynamic>> members,
    List<Map<String, dynamic>> invites,
  ) async {
    if (!_editorCanEdit || role == _selectedRole) return;
    final String? slot = ShopPermissionCatalog.secondManagerBlock(
      nextRole: role,
      editingMemberId: _editingMemberId,
      members: members,
      invites: invites,
    );
    if (slot != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(slot)));
      return;
    }
    final List<ShopPermissionChange> lost =
        ShopPermissionCatalog.permissionsLostOnRole(
          nextRole: role,
          permissions: _permissions,
        );
    if (lost.isNotEmpty) {
      final bool? agreed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('變更角色'),
            content: Text(
              '改為${ShopRoles.label(role)}後，以下權限會關閉：\n'
              '${lost.map((ShopPermissionChange item) => item.title).join('、')}\n\n'
              '其餘權限維持現況，不會自動打開新權限。按下儲存後才寫入。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('套用到草稿'),
              ),
            ],
          );
        },
      );
      if (agreed != true || !mounted) return;
      setState(() {
        _selectedRole = role;
        for (final ShopPermissionChange change in lost) {
          _permissions[change.key] = false;
        }
      });
      return;
    }
    setState(() => _selectedRole = role);
  }

  Set<String> _lockedKeys(List<Map<String, dynamic>> members) {
    if (_isOwner) return const <String>{};
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    Map<String, bool> own = const <String, bool>{};
    for (final Map<String, dynamic> member in members) {
      if (member['uid']?.toString() == uid) {
        own = ShopMemberPermissionService.instance.normalizePermissions(
          member['permissions'],
          role: member['role']?.toString(),
        );
        break;
      }
    }
    return ShopPermissionCatalog.items
        .where((ShopPermissionItem item) {
          return own[item.key] != true ||
              item.key == ShopPermissionKeys.manageStaff;
        })
        .map((ShopPermissionItem item) => item.key)
        .toSet();
  }

  Map<String, bool> _operatorPermissions(List<Map<String, dynamic>> members) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    for (final Map<String, dynamic> member in members) {
      if (member['uid']?.toString() == uid) {
        return ShopMemberPermissionService.instance.normalizePermissions(
          member['permissions'],
          role: member['role']?.toString(),
        );
      }
    }
    return const <String, bool>{};
  }

  Future<void> _openInvite(
    List<Map<String, dynamic>> members,
    List<Map<String, dynamic>> invites,
  ) async {
    final String? slot = ShopPermissionCatalog.secondManagerBlock(
      nextRole: ShopRoles.manager,
      editingMemberId: null,
      members: members,
      invites: invites,
    );
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) {
          return ShopMemberInvitePage(
            shopId: widget.shopId,
            operatorRole: widget.currentUserRole ?? ShopRoles.owner,
            operatorPermissions: _operatorPermissions(members),
            canPickManager: _isOwner && slot == null,
            managerSlotMessage: slot,
          );
        },
      ),
    );
  }

  Future<void> _save(Set<String> lockedKeys) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? memberId = _editingMemberId;
    if (user == null || memberId == null || !_editorCanEdit) return;
    final Map<String, bool> effective = Map<String, bool>.from(_permissions);
    if (!_isOwner) {
      for (final ShopPermissionItem item in ShopPermissionCatalog.items) {
        final bool turnedOn =
            effective[item.key] == true && _baseline[item.key] != true;
        if (turnedOn && lockedKeys.contains(item.key)) {
          effective[item.key] = false;
        }
      }
    }
    final List<ShopPermissionChange> changes = ShopPermissionCatalog.diff(
      _baseline,
      effective,
    );
    final bool roleChanged = _selectedRole != _baselineRole;
    if (!roleChanged && changes.isEmpty && !_storedOwnerOnly) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('沒有需要儲存的修改')));
      return;
    }
    final bool? agreed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final String opened = changes
            .where((ShopPermissionChange change) => change.enabled)
            .map((ShopPermissionChange change) => change.title)
            .join('、');
        final String closed = changes
            .where((ShopPermissionChange change) => !change.enabled)
            .map((ShopPermissionChange change) => change.title)
            .join('、');
        return AlertDialog(
          title: const Text('確認儲存'),
          content: Text(
            '${roleChanged ? '角色：${ShopRoles.label(_baselineRole)} → ${ShopRoles.label(_selectedRole)}\n' : ''}'
            '新增：${opened.isEmpty ? '無' : opened}\n'
            '移除：${closed.isEmpty ? '無' : closed}'
            '${_storedOwnerOnly ? '\n金流與收款設定會關閉，這項僅店主可使用。' : ''}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
    if (agreed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ShopService.instance.updateMemberPermission(
        memberDocId: memberId,
        shopId: widget.shopId,
        role: _selectedRole,
        permissions: effective,
        operatorUid: user.uid,
        operatorRole: widget.currentUserRole ?? ShopRoles.owner,
        baseline: _baseline,
      );
      if (!mounted) return;
      setState(() {
        _permissions = Map<String, bool>.from(effective);
        _baseline = Map<String, bool>.from(effective);
        _baselineRole = _selectedRole;
        _storedOwnerOnly = false;
        if (_editingMember != null) {
          _editingMember = <String, dynamic>{
            ..._editingMember!,
            'role': _selectedRole,
          };
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存，成員列表已更新')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdits() {
    setState(() {
      _permissions = Map<String, bool>.from(_baseline);
      _selectedRole = _baselineRole;
    });
  }

  @override
  Widget build(BuildContext context) {
    _wide = MediaQuery.sizeOf(context).width >= 960;
    final bool phoneEditor =
        !_wide && _tabController.index == 1 && _editingMemberId != null;
    return PopScope(
      canPop: _forcePop || (!_dirty && !_saving),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        dashboardConfirmLeave().then((bool leave) {
          if (!leave || !mounted) return;
          setState(() => _forcePop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('權限與員工管理'),
          leading: phoneEditor
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _tabController.animateTo(0),
                )
              : null,
          actions: <Widget>[
            TextButton(
              onPressed: _dirty ? _cancelEdits : null,
              child: const Text('取消修改'),
            ),
            ShopTaskCenterButton(shopId: widget.shopId),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const <Widget>[
              Tab(text: '員工管理'),
              Tab(text: '權限設定'),
              Tab(text: '操作紀錄'),
            ],
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: ShopService.instance.streamShopMembers(widget.shopId),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<Map<String, dynamic>>> memberSnap,
              ) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ShopService.instance.streamShopMemberInvites(
                    widget.shopId,
                  ),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<Map<String, dynamic>>> inviteSnap,
                      ) {
                        final List<Map<String, dynamic>> members =
                            memberSnap.data ?? const <Map<String, dynamic>>[];
                        final List<Map<String, dynamic>> invites =
                            inviteSnap.data ?? const <Map<String, dynamic>>[];
                        _syncQuietMember(members);
                        return _body(members, invites);
                      },
                );
              },
        ),
      ),
    );
  }

  void _syncQuietMember(List<Map<String, dynamic>> members) {
    if (_dirty || _editingMemberId == null) return;
    Map<String, dynamic>? live;
    for (final Map<String, dynamic> member in members) {
      if (member['id']?.toString() == _editingMemberId) {
        live = member;
        break;
      }
    }
    if (live == null) return;
    final String role = live['role']?.toString() == ShopRoles.manager
        ? ShopRoles.manager
        : ShopRoles.staff;
    final Map<String, bool> draft = _draftFrom(live);
    if (role == _baselineRole &&
        ShopPermissionCatalog.sameGrantable(draft, _baseline)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dirty || _editingMemberId != live!['id']?.toString()) {
        return;
      }
      _loadMember(live);
    });
  }

  Widget _body(
    List<Map<String, dynamic>> members,
    List<Map<String, dynamic>> invites,
  ) {
    final int staffCount = members
        .where(
          (Map<String, dynamic> member) =>
              member['role']?.toString() == ShopRoles.staff,
        )
        .length;
    final int managerSlots =
        ShopPermissionCatalog.activeManagerCount(members) +
        invites
            .where(
              (Map<String, dynamic> invite) =>
                  invite['role']?.toString() == ShopRoles.manager,
            )
            .length;
    final Set<String> lockedKeys = _lockedKeys(members);
    final bool watchLogs =
        _tabController.index == 2 || _editingMemberId != null;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _stat('員工', '$staffCount'),
                _stat('店長', '$managerSlots/1'),
                _stat('待接受', '${invites.length}'),
              ],
            ),
          ),
        ),
        if (managerSlots > 1)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('目前超過一名店長。新的任命已暫停，不會自動撤換現有成員。'),
          ),
        if (_dirty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('有尚未儲存的修改'),
            ),
          ),
        Expanded(
          child: watchLogs
              ? StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ActionLogService.instance.streamShopLogs(
                    widget.shopId,
                  ),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<Map<String, dynamic>>> logSnap,
                      ) {
                        return _tabs(
                          members,
                          invites,
                          logSnap.data ?? const <Map<String, dynamic>>[],
                          lockedKeys,
                        );
                      },
                )
              : _tabs(
                  members,
                  invites,
                  const <Map<String, dynamic>>[],
                  lockedKeys,
                ),
        ),
        if (_editingMemberId != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _dirty && !_saving ? _cancelEdits : null,
                      child: const Text('取消修改'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: (!_editorCanEdit || _saving)
                          ? null
                          : () => _save(lockedKeys),
                      child: Text(_saving ? '儲存中...' : '儲存'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Chip(label: Text('$label $value'));
  }

  Widget _tabs(
    List<Map<String, dynamic>> members,
    List<Map<String, dynamic>> invites,
    List<Map<String, dynamic>> logs,
    Set<String> lockedKeys,
  ) {
    return TabBarView(
      controller: _tabController,
      children: <Widget>[
        _memberTab(members, invites, logs),
        _permissionTab(members, invites, lockedKeys),
        ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[PermissionActionLogList(logs: logs)],
        ),
      ],
    );
  }

  Widget _memberTab(
    List<Map<String, dynamic>> members,
    List<Map<String, dynamic>> invites,
    List<Map<String, dynamic>> logs,
  ) {
    final Widget list = ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _canEdit ? () => _openInvite(members, invites) : null,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('邀請成員'),
          ),
        ),
        const SizedBox(height: 12),
        PermissionMemberListCard(
          members: members,
          selectedId: _editingMemberId,
          onTapMember: _selectMember,
        ),
        const SizedBox(height: 12),
        PermissionInviteListCard(
          shopId: widget.shopId,
          invites: invites,
          currentUserRole: widget.currentUserRole,
          isOwner: _isOwner,
          roleLabelBuilder: ShopRoles.label,
        ),
      ],
    );
    if (!_wide || _editingMember == null) return list;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: list),
        SizedBox(width: 360, child: _memberPanel(logs)),
      ],
    );
  }

  Widget _memberPanel(List<Map<String, dynamic>> logs) {
    final Map<String, dynamic> member = _editingMember!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      children: <Widget>[
        Text(
          PermissionMemberListCard.displayName(member),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(member['email']?.toString() ?? ''),
        const SizedBox(height: 4),
        Text(
          '${ShopRoles.label(_selectedRole)}｜${PermissionMemberListCard.statusLabel(member['status']?.toString() ?? 'active')}｜已啟用 ${ShopPermissionCatalog.enabledCount(_permissions)} 項',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _tabController.animateTo(1),
          child: const Text('調整權限'),
        ),
        const SizedBox(height: 12),
        PermissionActionLogList(
          logs: logs,
          memberId: _editingMemberId,
          title: '這位成員的異動',
        ),
      ],
    );
  }

  Widget _permissionTab(
    List<Map<String, dynamic>> members,
    List<Map<String, dynamic>> invites,
    Set<String> lockedKeys,
  ) {
    if (_editingMemberId == null) {
      return const Center(child: Text('請先在員工管理選擇成員'));
    }
    final String? slot = ShopPermissionCatalog.secondManagerBlock(
      nextRole: ShopRoles.manager,
      editingMemberId: _editingMemberId,
      members: members,
      invites: invites,
    );
    return ShopPermissionV2Editor(
      role: _selectedRole,
      permissions: _permissions,
      canEdit: _editorCanEdit && !_saving,
      canPickManager: _isOwner,
      managerSlotMessage: slot,
      lockedKeys: _editorCanEdit
          ? lockedKeys
          : ShopPermissionCatalog.items
                .map((ShopPermissionItem item) => item.key)
                .toSet(),
      onRoleChanged: (String role) => _changeRole(role, members, invites),
      onToggle: (String key, bool value) {
        setState(() => _permissions[key] = value);
      },
      onToggleCategory: (ShopPermissionCategory category, bool value) {
        setState(() {
          for (final ShopPermissionItem item in category.items) {
            if (lockedKeys.contains(item.key)) continue;
            _permissions[item.key] = value;
          }
        });
      },
    );
  }
}
