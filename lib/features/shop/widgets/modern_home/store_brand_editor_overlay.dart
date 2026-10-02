import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_block.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';

/// 首頁最上方的識別列。高度跟內容走，下面的海報排在這一列之後。
class StoreBrandTopBar extends StatelessWidget {
  const StoreBrandTopBar({
    super.key,
    required this.style,
    required this.shopName,
    required this.subtitle,
    required this.logoUrl,
    required this.theme,
    required this.backgroundColor,
    this.leading,
    this.editable = false,
    this.onChanged,
  });

  final StoreBrandStyle style;
  final String shopName;
  final String subtitle;
  final String logoUrl;
  final HomeThemeModel theme;
  final Color backgroundColor;
  final Widget? leading;
  final bool editable;
  final ValueChanged<StoreBrandStyle>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(width: leading == null ? 12 : 48, child: leading),
            Expanded(
              child: StoreBrandLane(
                style: style,
                shopName: shopName,
                subtitle: subtitle,
                logoUrl: logoUrl,
                theme: theme,
                editable: editable,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

/// 只在識別列寬度內左右移動。正式前台不接收拖曳。
class StoreBrandLane extends StatelessWidget {
  const StoreBrandLane({
    super.key,
    required this.style,
    required this.shopName,
    required this.subtitle,
    required this.logoUrl,
    required this.theme,
    this.editable = false,
    this.onChanged,
  });

  final StoreBrandStyle style;
  final String shopName;
  final String subtitle;
  final String logoUrl;
  final HomeThemeModel theme;
  final bool editable;
  final ValueChanged<StoreBrandStyle>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (!editable) {
      return _BrandAlign(
        x: style.x,
        child: _block(),
      );
    }
    return _StoreBrandLaneEditor(
      style: style,
      onChanged: onChanged ?? (_) {},
      child: _block(),
    );
  }

  Widget _block() {
    return StoreBrandBlock(
      contextKind: StoreBrandDisplayContext.home,
      style: style,
      shopName: shopName,
      subtitle: subtitle,
      logoUrl: logoUrl,
      theme: theme,
    );
  }
}

class _BrandAlign extends StatelessWidget {
  const _BrandAlign({required this.x, required this.child});

  final double x;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(x.clamp(0, 1) * 2 - 1, 0),
      child: child,
    );
  }
}

class _StoreBrandLaneEditor extends StatefulWidget {
  const _StoreBrandLaneEditor({
    required this.style,
    required this.onChanged,
    required this.child,
  });

  final StoreBrandStyle style;
  final ValueChanged<StoreBrandStyle> onChanged;
  final Widget child;

  @override
  State<_StoreBrandLaneEditor> createState() => _StoreBrandLaneEditorState();
}

class _StoreBrandLaneEditorState extends State<_StoreBrandLaneEditor> {
  final GlobalKey _laneKey = GlobalKey(debugLabel: 'brandLane');
  final GlobalKey _blockKey = GlobalKey(debugLabel: 'brandLaneBlock');
  bool _dragging = false;
  double? _grabDx;
  double? _left;
  double? _settledX;

  @override
  void didUpdateWidget(_StoreBrandLaneEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double? settled = _settledX;
    if (settled != null && (widget.style.x - settled).abs() < 0.0001) {
      _settledX = null;
    }
  }

  double get _displayX => _settledX ?? widget.style.x;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double lane = constraints.maxWidth;
        if (!_dragging) {
          return SizedBox(
            key: _laneKey,
            width: lane,
            child: Align(
              alignment: Alignment(_displayX.clamp(0, 1) * 2 - 1, 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: lane),
                child: _target(dragging: false),
              ),
            ),
          );
        }
        final double left = _left ?? 0;
        return SizedBox(
          key: _laneKey,
          width: lane,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: left),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: lane),
                  child: _target(dragging: true),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _target({required bool dragging}) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent event) => _onDown(event.position),
      onPointerMove: (PointerMoveEvent event) => _onMove(event.position),
      onPointerUp: (_) => _commit(),
      onPointerCancel: (_) => _commit(),
      child: DecoratedBox(
        key: _blockKey,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: dragging ? const Color(0x66B86B18) : const Color(0x00000000),
            width: 1.5,
          ),
          color: dragging ? const Color(0x14B86B18) : const Color(0x00000000),
        ),
        child: widget.child,
      ),
    );
  }

  void _onDown(Offset globalPosition) {
    final RenderBox? lane = _box(_laneKey);
    final RenderBox? block = _box(_blockKey);
    if (lane == null || block == null) {
      return;
    }
    final double childLeft = lane
        .globalToLocal(block.localToGlobal(Offset.zero))
        .dx;
    final double local = lane.globalToLocal(globalPosition).dx;
    setState(() {
      _dragging = true;
      _left = childLeft;
      _grabDx = local - childLeft;
    });
  }

  void _onMove(Offset globalPosition) {
    final RenderBox? lane = _box(_laneKey);
    final RenderBox? block = _box(_blockKey);
    final double? grab = _grabDx;
    if (lane == null || block == null || grab == null || !_dragging) {
      return;
    }
    final double local = lane.globalToLocal(globalPosition).dx;
    final double travel = math.max(0, lane.size.width - block.size.width);
    setState(() {
      _left = (local - grab).clamp(0, travel).toDouble();
    });
  }

  void _commit() {
    final RenderBox? lane = _box(_laneKey);
    final RenderBox? block = _box(_blockKey);
    final double left = _left ?? 0;
    final double x = lane == null || block == null
        ? widget.style.x
        : StoreBrandGeometry.normalizeX(
            left: left,
            laneWidth: lane.size.width,
            contentWidth: block.size.width,
          );
    setState(() {
      _dragging = false;
      _grabDx = null;
      _left = null;
      _settledX = x;
    });
    if ((x - widget.style.x).abs() > 0.0001) {
      widget.onChanged(widget.style.copyWith(x: x));
    }
  }

  RenderBox? _box(GlobalKey key) {
    final RenderObject? object = key.currentContext?.findRenderObject();
    if (object is RenderBox && object.hasSize) {
      return object;
    }
    return null;
  }
}
