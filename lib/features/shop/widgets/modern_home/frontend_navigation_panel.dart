import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';

class FrontendNavigationPanel extends StatelessWidget {
  const FrontendNavigationPanel({
    super.key,
    required this.config,
    required this.shopState,
    required this.onChanged,
  });

  final FrontendNavigationConfig config;
  final FrontendNavShopState shopState;
  final ValueChanged<FrontendNavigationConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StyleCard(
                title: '側邊選單',
                description: '使用左上角選單按鈕展開完整功能。',
                selected: !config.isBottom,
                icon: Icons.menu_rounded,
                onTap: () => onChanged(
                  config.copyWith(style: FrontendNavigationConfig.styleDrawer),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StyleCard(
                title: '底部選單',
                description: '常用功能固定顯示於手機底部，首頁固定置中。',
                selected: config.isBottom,
                icon: Icons.dock_rounded,
                onTap: () => onChanged(
                  config.copyWith(style: FrontendNavigationConfig.styleBottom),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (config.isBottom)
          _BottomSlotEditor(
            config: config,
            shopState: shopState,
            onChanged: onChanged,
          )
        else
          _DrawerOrderEditor(
            config: config,
            shopState: shopState,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                size: 22,
                color: selected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              _StyleSketch(bottom: icon == Icons.dock_rounded, selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleSketch extends StatelessWidget {
  const _StyleSketch({required this.bottom, required this.selected});

  final bool bottom;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color mark = selected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8);
    if (!bottom) {
      return Row(
        children: <Widget>[
          Container(width: 10, height: 22, color: mark),
          const SizedBox(width: 4),
          Expanded(child: Container(height: 22, color: const Color(0xFFE2E8F0))),
        ],
      );
    }
    return Row(
      children: <Widget>[
        for (int i = 0; i < 5; i++)
          Expanded(
            child: Container(
              height: i == 2 ? 18 : 12,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i == 2 ? mark : mark.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}

class _DrawerOrderEditor extends StatelessWidget {
  const _DrawerOrderEditor({
    required this.config,
    required this.shopState,
    required this.onChanged,
  });

  final FrontendNavigationConfig config;
  final FrontendNavShopState shopState;
  final ValueChanged<FrontendNavigationConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<FrontendNavigationItem> items = <FrontendNavigationItem>[];
    for (final String id in config.drawerItemOrder) {
      final FrontendNavigationItem? item = FrontendNavigationRegistry.find(id);
      if (item != null && item.ownerSelectable) {
        items.add(item);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          '側邊選單項目',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          '拖曳把手調整一般功能順序。返回平台、回店家後台與登出固定在底部。',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorder: (int oldIndex, int newIndex) {
            onChanged(
              config.copyWith(
                drawerItemOrder: FrontendNavigationConfig.reorder(
                  config.drawerItemOrder,
                  oldIndex,
                  newIndex,
                ),
              ),
            );
          },
          itemBuilder: (BuildContext context, int index) {
            final FrontendNavigationItem item = items[index];
            final bool enabled = !config.drawerHiddenItemIds.contains(item.id);
            final String? reason = shopState.disabledReason(item);
            return ListTile(
              key: ValueKey<String>('drawer_${item.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.icon, size: 20),
              title: Text(item.label),
              subtitle: reason == null
                  ? null
                  : Text(reason, style: const TextStyle(color: Color(0xFFB45309))),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (item.id != FrontendNavigationRegistry.homeId)
                    Switch(
                      value: enabled && reason == null,
                      onChanged: reason == null
                          ? (bool value) {
                              final List<String> hidden = List<String>.from(
                                config.drawerHiddenItemIds,
                              );
                              if (value) {
                                hidden.remove(item.id);
                              } else if (!hidden.contains(item.id)) {
                                hidden.add(item.id);
                              }
                              onChanged(
                                config.copyWith(drawerHiddenItemIds: hidden),
                              );
                            }
                          : null,
                    )
                  else
                    const Text(
                      '固定顯示',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.drag_handle, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BottomSlotEditor extends StatelessWidget {
  const _BottomSlotEditor({
    required this.config,
    required this.shopState,
    required this.onChanged,
  });

  final FrontendNavigationConfig config;
  final FrontendNavShopState shopState;
  final ValueChanged<FrontendNavigationConfig> onChanged;

  static const List<String> _labels = <String>[
    '左側 1',
    '左側 2',
    '首頁',
    '右側 1',
    '右側 2',
  ];

  @override
  Widget build(BuildContext context) {
    final List<String?> ids = <String?>[
      config.left1,
      config.left2,
      FrontendNavigationRegistry.homeId,
      config.right1,
      config.right2,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          '底部選單',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          '中間固定為首頁。左右四格可點選更換，也可互相拖曳交換。',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < 5; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _DraggableSlot(
                      index: i,
                      label: _labels[i],
                      item: FrontendNavigationRegistry.find(ids[i] ?? ''),
                      locked: i == 2,
                      onTap: i == 2 ? null : () => _pick(context, i, ids),
                      onAccept: (int from) => _swap(from, i),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '底欄外型',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _ChoiceRow(
          options: const <_Choice>[
            _Choice(
              value: FrontendNavigationConfig.appearanceAttached,
              title: '原版貼底',
              subtitle: '貼齊底部',
            ),
            _Choice(
              value: FrontendNavigationConfig.appearanceFloatingPill,
              title: '懸浮膠囊',
              subtitle: '左右留白',
            ),
            _Choice(
              value: FrontendNavigationConfig.appearanceFloatingMinimal,
              title: '極簡懸浮',
              subtitle: '較矮、少裝飾',
            ),
          ],
          selected: config.bottomAppearance,
          onSelected: (String value) {
            onChanged(config.copyWith(bottomAppearance: value));
          },
        ),
        const SizedBox(height: 14),
        const Text(
          '透明程度',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _ChoiceRow(
          options: const <_Choice>[
            _Choice(
              value: FrontendNavigationConfig.surfaceOpaque,
              title: '不透明',
              subtitle: '實心底',
            ),
            _Choice(
              value: FrontendNavigationConfig.surfaceTranslucent,
              title: '半透明',
              subtitle: '可看到後方',
            ),
            _Choice(
              value: FrontendNavigationConfig.surfaceTransparent,
              title: '全透明',
              subtitle: '保留圖示',
            ),
          ],
          selected: config.bottomSurface,
          onSelected: (String value) {
            onChanged(config.copyWith(bottomSurface: value));
          },
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, int slot, List<String?> ids) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final Set<String> used = <String>{
          for (final String? id in ids)
            if (id != null && id != ids[slot]) id,
        };
        return SafeArea(
          child: ListView(
            children: <Widget>[
              ListTile(
                title: const Text('留空'),
                onTap: () => Navigator.pop(sheetContext, ''),
              ),
              for (final FrontendNavigationItem item
                  in FrontendNavigationRegistry.selectableItems)
                if (item.id != FrontendNavigationRegistry.homeId)
                  ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    subtitle: _subtitle(item, used),
                    enabled: shopState.isEnabled(item) && !used.contains(item.id),
                    onTap: () => Navigator.pop(sheetContext, item.id),
                  ),
            ],
          ),
        );
      },
    );
    if (picked == null) {
      return;
    }
    final String? value = picked.isEmpty ? null : picked;
    switch (slot) {
      case 0:
        onChanged(config.copyWith(left1: value, clearLeft1: value == null));
      case 1:
        onChanged(config.copyWith(left2: value, clearLeft2: value == null));
      case 3:
        onChanged(config.copyWith(right1: value, clearRight1: value == null));
      case 4:
        onChanged(config.copyWith(right2: value, clearRight2: value == null));
    }
  }

  void _swap(int from, int to) {
    if (from == to || from == 2 || to == 2) {
      return;
    }
    final List<String?> ids = <String?>[
      config.left1,
      config.left2,
      FrontendNavigationRegistry.homeId,
      config.right1,
      config.right2,
    ];
    final String? moving = ids[from];
    ids[from] = ids[to];
    ids[to] = moving;
    onChanged(
      config.copyWith(
        left1: ids[0],
        left2: ids[1],
        right1: ids[3],
        right2: ids[4],
        clearLeft1: ids[0] == null,
        clearLeft2: ids[1] == null,
        clearRight1: ids[3] == null,
        clearRight2: ids[4] == null,
      ),
    );
  }

  Widget? _subtitle(FrontendNavigationItem item, Set<String> used) {
    if (!shopState.isEnabled(item)) {
      return const Text('尚未啟用');
    }
    if (used.contains(item.id)) {
      return const Text('已使用');
    }
    return null;
  }
}

class _DraggableSlot extends StatelessWidget {
  const _DraggableSlot({
    required this.index,
    required this.label,
    required this.item,
    required this.locked,
    required this.onTap,
    required this.onAccept,
  });

  final int index;
  final String label;
  final FrontendNavigationItem? item;
  final bool locked;
  final VoidCallback? onTap;
  final ValueChanged<int> onAccept;

  @override
  Widget build(BuildContext context) {
    final Widget card = _SlotCard(
      label: label,
      item: item,
      locked: locked,
      onTap: onTap,
    );
    if (locked) {
      return card;
    }
    return DragTarget<int>(
      onWillAcceptWithDetails: (DragTargetDetails<int> details) {
        return details.data != 2 && details.data != index;
      },
      onAcceptWithDetails: (DragTargetDetails<int> details) {
        onAccept(details.data);
      },
      builder: (BuildContext context, List<int?> candidate, List<dynamic> rejected) {
        return Draggable<int>(
          data: index,
          feedback: SizedBox(width: 72, child: Material(child: card)),
          childWhenDragging: Opacity(opacity: 0.35, child: card),
          child: card,
        );
      },
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.label,
    required this.item,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final FrontendNavigationItem? item;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: locked ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: locked ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                item?.icon ?? Icons.add,
                size: locked ? 22 : 18,
                color: locked ? const Color(0xFF2563EB) : const Color(0xFF334155),
              ),
              const SizedBox(height: 4),
              Text(
                item?.shortLabel ?? '未選',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice {
  const _Choice({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final String value;
  final String title;
  final String subtitle;
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<_Choice> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < options.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _MiniPreviewCard(
              choice: options[i],
              selected: options[i].value == selected,
              onTap: () => onSelected(options[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniPreviewCard extends StatelessWidget {
  const _MiniPreviewCard({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final _Choice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool floating =
        choice.value == FrontendNavigationConfig.appearanceFloatingPill ||
        choice.value == FrontendNavigationConfig.appearanceFloatingMinimal;
    final bool minimal =
        choice.value == FrontendNavigationConfig.appearanceFloatingMinimal;
    final double alpha = switch (choice.value) {
      FrontendNavigationConfig.surfaceTranslucent => 0.55,
      FrontendNavigationConfig.surfaceTransparent => 0.12,
      _ => 1,
    };
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 78,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: minimal ? 10 : 14,
                    margin: EdgeInsets.symmetric(horizontal: floating ? 6 : 0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: alpha),
                      borderRadius: BorderRadius.circular(floating ? 8 : 2),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                choice.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              Text(
                choice.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

