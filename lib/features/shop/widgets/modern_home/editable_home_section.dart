// 檔案名稱：lib/features/shop/widgets/modern_home/editable_home_section.dart
// 功能說明：首頁編排畫布上的單一區塊。目前支援點選；排序把手只在調整順序時出現。

import 'package:flutter/material.dart';

class EditableHomeSection extends StatelessWidget {
  const EditableHomeSection({
    super.key,
    required this.sectionId,
    required this.child,
    this.enabled = true,
    this.selected = false,
    this.onSelect,
    this.onMove,
    this.showDragHandle = false,
  });

  final String sectionId;
  final Widget child;
  final bool enabled;
  final bool selected;
  final VoidCallback? onSelect;

  /// 未來區塊排序用。這次不接拖曳，避免做出不能儲存的假排序。
  final void Function(int delta)? onMove;

  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onSelect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: <Widget>[
            child,
            if (showDragHandle)
              Positioned(top: 4, right: 4, child: _DragHandle(onMove: onMove)),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({this.onMove});

  final void Function(int delta)? onMove;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: onMove == null ? '調整順序' : '拖曳整個區塊',
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.drag_indicator, size: 16, color: Color(0xFF475569)),
        ),
      ),
    );
  }
}
