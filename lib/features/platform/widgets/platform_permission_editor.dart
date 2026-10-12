// 檔案名稱：lib/features/platform/widgets/platform_permission_editor.dart
// 功能說明：依分類顯示平台權限，並標示敏感與僅最高管理員的項目。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/platform_permission_keys.dart';
import 'package:petnest_saas/core/services/platform_permission_catalog.dart';

enum PlatformPermissionFilter { all, enabled, disabled }

class PlatformPermissionEditor extends StatefulWidget {
  const PlatformPermissionEditor({
    super.key,
    required this.selected,
    required this.onChanged,
    this.grantableKeys,
    this.locked = false,
  });

  final Set<String> selected;
  final void Function(String key, bool enabled) onChanged;
  final Set<String>? grantableKeys;
  final bool locked;

  @override
  State<PlatformPermissionEditor> createState() =>
      _PlatformPermissionEditorState();
}

class _PlatformPermissionEditorState extends State<PlatformPermissionEditor> {
  final TextEditingController _searchController = TextEditingController();
  PlatformPermissionFilter _filter = PlatformPermissionFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _canGrant(String key) {
    if (widget.locked || PlatformPermissionCatalog.isSuperOnly(key)) {
      return false;
    }
    final Set<String>? grantable = widget.grantableKeys;
    if (grantable == null) return true;
    return grantable.contains(key);
  }

  String _lockReason(String key) {
    if (PlatformPermissionCatalog.isSuperOnly(key)) {
      return PlatformPermissionCatalog.lockReason(key);
    }
    if (widget.locked) return '這個帳號不能在此修改。';
    return '超出你能授予的範圍。';
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: '搜尋權限',
            hintText: '輸入功能名稱',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('全部'),
              selected: _filter == PlatformPermissionFilter.all,
              onSelected: (_) {
                setState(() => _filter = PlatformPermissionFilter.all);
              },
            ),
            FilterChip(
              label: const Text('只看已開啟'),
              selected: _filter == PlatformPermissionFilter.enabled,
              onSelected: (_) {
                setState(() => _filter = PlatformPermissionFilter.enabled);
              },
            ),
            FilterChip(
              label: const Text('只看未開啟'),
              selected: _filter == PlatformPermissionFilter.disabled,
              onSelected: (_) {
                setState(() => _filter = PlatformPermissionFilter.disabled);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final PlatformPermissionGroup group
            in PlatformPermissionCatalog.groups)
          _GroupCard(
            group: group,
            query: query,
            filter: _filter,
            selected: widget.selected,
            canGrant: _canGrant,
            lockReason: _lockReason,
            onChanged: widget.onChanged,
          ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.query,
    required this.filter,
    required this.selected,
    required this.canGrant,
    required this.lockReason,
    required this.onChanged,
  });

  final PlatformPermissionGroup group;
  final String query;
  final PlatformPermissionFilter filter;
  final Set<String> selected;
  final bool Function(String key) canGrant;
  final String Function(String key) lockReason;
  final void Function(String key, bool enabled) onChanged;

  @override
  Widget build(BuildContext context) {
    final List<String> visible = group.keys.where((String key) {
      final bool enabled = selected.contains(key);
      if (filter == PlatformPermissionFilter.enabled && !enabled) return false;
      if (filter == PlatformPermissionFilter.disabled && enabled) return false;
      if (query.isEmpty) return true;
      final String haystack =
          '${PlatformPermissionKeys.label(key)} ${PlatformPermissionCatalog.explain(key)}';
      return haystack.toLowerCase().contains(query.toLowerCase());
    }).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final int enabledCount = PlatformPermissionCatalog.enabledCountIn(
      group,
      selected,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text('已開啟 $enabledCount'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final String key in visible)
              _PermissionTile(
                permission: key,
                selected: selected.contains(key),
                enabled: canGrant(key),
                reason: canGrant(key) ? '' : lockReason(key),
                onChanged: (bool value) => onChanged(key, value),
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.permission,
    required this.selected,
    required this.enabled,
    required this.reason,
    required this.onChanged,
  });

  final String permission;
  final bool selected;
  final bool enabled;
  final String reason;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool sensitive = PlatformPermissionKeys.isSensitive(permission);
    final bool superOnly = PlatformPermissionCatalog.isSuperOnly(permission);
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      value: selected,
      title: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(PlatformPermissionKeys.label(permission)),
          if (sensitive)
            const _Badge(label: '敏感權限', color: Colors.orange),
          if (superOnly)
            const _Badge(label: '僅最高管理員', color: Colors.red),
        ],
      ),
      subtitle: Text(
        reason.isEmpty
            ? PlatformPermissionCatalog.explain(permission)
            : '${PlatformPermissionCatalog.explain(permission)}\n$reason',
      ),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color.shade800),
      ),
    );
  }
}
