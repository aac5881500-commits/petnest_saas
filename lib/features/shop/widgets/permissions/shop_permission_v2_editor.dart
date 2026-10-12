// 檔案名稱：lib/features/shop/widgets/permissions/shop_permission_v2_editor.dart
// 功能說明：權限草稿編輯。只改畫面狀態，按下儲存才由外層寫入。
// 本階段不提供一鍵模板。角色切換由外層決定，這裡不會重設勾選。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_permission_catalog.dart';

enum ShopPermissionFilter { all, enabled, disabled }

class ShopPermissionV2Editor extends StatefulWidget {
  const ShopPermissionV2Editor({
    super.key,
    required this.role,
    required this.permissions,
    required this.canEdit,
    required this.canPickManager,
    required this.onRoleChanged,
    required this.onToggle,
    required this.onToggleCategory,
    this.managerSlotMessage,
    this.lockedKeys = const <String>{},
    this.showRoleSelector = true,
  });

  final String role;
  final Map<String, bool> permissions;
  final bool canEdit;
  final bool canPickManager;
  final ValueChanged<String> onRoleChanged;
  final void Function(String key, bool value) onToggle;
  final void Function(ShopPermissionCategory category, bool value)
  onToggleCategory;
  final String? managerSlotMessage;
  final Set<String> lockedKeys;
  final bool showRoleSelector;

  @override
  State<ShopPermissionV2Editor> createState() => _ShopPermissionV2EditorState();
}

class _ShopPermissionV2EditorState extends State<ShopPermissionV2Editor> {
  final TextEditingController _searchController = TextEditingController();
  ShopPermissionFilter _filter = ShopPermissionFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _locked(String key) => widget.lockedKeys.contains(key);

  List<ShopPermissionItem> _visibleItems(ShopPermissionCategory category) {
    final String query = _searchController.text.trim();
    return category.items.where((ShopPermissionItem item) {
      final bool enabled = widget.permissions[item.key] == true;
      if (_filter == ShopPermissionFilter.enabled && !enabled) return false;
      if (_filter == ShopPermissionFilter.disabled && enabled) return false;
      if (query.isEmpty) return true;
      return item.title.contains(query) || item.description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double innerWidth = constraints.maxWidth - 32;
        final bool wide = innerWidth >= 860;
        final List<Widget> categories = ShopPermissionCatalog.categories.map((
          ShopPermissionCategory category,
        ) {
          final List<ShopPermissionItem> visible = _visibleItems(category);
          if (visible.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.only(bottom: 12, right: wide ? 12 : 0),
            child: SizedBox(
              width: wide ? (innerWidth - 12) / 2 : innerWidth,
              child: _categoryCard(category, visible),
            ),
          );
        }).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            if (widget.showRoleSelector) ...<Widget>[
              _roleCard(),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '搜尋權限',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('全部'),
                  selected: _filter == ShopPermissionFilter.all,
                  onSelected: (_) =>
                      setState(() => _filter = ShopPermissionFilter.all),
                ),
                ChoiceChip(
                  label: const Text('只看已開啟'),
                  selected: _filter == ShopPermissionFilter.enabled,
                  onSelected: (_) =>
                      setState(() => _filter = ShopPermissionFilter.enabled),
                ),
                ChoiceChip(
                  label: const Text('只看未開啟'),
                  selected: _filter == ShopPermissionFilter.disabled,
                  onSelected: (_) =>
                      setState(() => _filter = ShopPermissionFilter.disabled),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (wide) Wrap(children: categories) else ...categories,
            _ownerOnlyCard(),
          ],
        );
      },
    );
  }

  Widget _roleCard() {
    final bool managerBlocked =
        widget.managerSlotMessage != null && widget.role != ShopRoles.manager;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('角色', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('角色只代表身分。變更角色不會自動打開或重設權限。'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: ShopRoles.manager,
                  label: const Text('店長'),
                  enabled: widget.canPickManager && !managerBlocked,
                ),
                const ButtonSegment<String>(
                  value: ShopRoles.staff,
                  label: Text('員工'),
                ),
              ],
              selected: <String>{
                widget.role == ShopRoles.manager
                    ? ShopRoles.manager
                    : ShopRoles.staff,
              },
              onSelectionChanged: widget.canEdit
                  ? (Set<String> value) => widget.onRoleChanged(value.first)
                  : null,
            ),
            if (managerBlocked) ...<Widget>[
              const SizedBox(height: 8),
              Text(widget.managerSlotMessage!),
            ],
            const SizedBox(height: 8),
            Text(
              '已啟用 ${ShopPermissionCatalog.enabledCount(widget.permissions)} 項',
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryCard(
    ShopPermissionCategory category,
    List<ShopPermissionItem> visible,
  ) {
    final int enabled = ShopPermissionCatalog.enabledCountIn(
      category,
      widget.permissions,
    );
    final bool allOn = category.items.every(
      (ShopPermissionItem item) => widget.permissions[item.key] == true,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    category.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('$enabled/${category.items.length}'),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.canEdit
                    ? () => widget.onToggleCategory(category, !allOn)
                    : null,
                child: Text(allOn ? '本組全關' : '本組全開'),
              ),
            ),
            ...visible.map(_permissionTile),
          ],
        ),
      ),
    );
  }

  Widget _permissionTile(ShopPermissionItem item) {
    final bool locked = _locked(item.key);
    final bool enabled = widget.permissions[item.key] == true;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.title),
      subtitle: Text(
        locked
            ? '${item.description} 超出你能授予的範圍。'
            : item.highRisk
            ? '${item.description} 高風險，預設關閉。'
            : item.description,
      ),
      value: enabled,
      onChanged: widget.canEdit && !locked
          ? (bool value) => widget.onToggle(item.key, value)
          : null,
    );
  }

  Widget _ownerOnlyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('僅店主', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('以下不能授權給店長或員工，切換角色也不會取得。'),
            const SizedBox(height: 8),
            ...ShopPermissionCatalog.ownerCapabilities.map(
              (String item) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                enabled: false,
                leading: const Icon(Icons.lock_outline),
                title: Text(item),
                subtitle: const Text('僅店主'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
