import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/floating_action_bounds.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_bottom_navigation.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_modern_logo.dart';

/// 店主與員工專用的店家選單。位置依本機習慣保存，內嵌預覽不寫入。
class ShopMenuButton extends StatefulWidget {
  const ShopMenuButton({
    super.key,
    required this.shopId,
    required this.userId,
    required this.shopName,
    required this.logoUrl,
    required this.theme,
    required this.surface,
    required this.bottomBarHeight,
    required this.visible,
    required this.persistPosition,
    required this.allowNavigation,
    required this.onPlatform,
    required this.onAdmin,
    this.headerHeight = 0,
    this.peerRect,
    this.ownRect,
  });

  final String shopId;
  final String userId;
  final String shopName;
  final String logoUrl;
  final HomeThemeModel theme;
  final String surface;
  final double bottomBarHeight;
  final double headerHeight;
  final bool visible;
  final bool persistPosition;
  final bool allowNavigation;
  final VoidCallback onPlatform;
  final VoidCallback onAdmin;
  final ValueNotifier<Rect?>? peerRect;
  final ValueNotifier<Rect?>? ownRect;

  @override
  State<ShopMenuButton> createState() => _ShopMenuButtonState();
}

class _ShopMenuButtonState extends State<ShopMenuButton> {
  final GlobalKey _layerKey = GlobalKey(debugLabel: 'shop-menu-layer');
  double? _nx;
  double? _ny;
  double? _dragX;
  double? _dragY;
  Offset _grab = Offset.zero;
  double _travel = 0;
  bool _dragging = false;
  bool _didDrag = false;
  Rect? _published;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  @override
  void didUpdateWidget(ShopMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible) {
      _publish(null);
    }
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.userId != widget.userId ||
        oldWidget.persistPosition != widget.persistPosition) {
      _nx = null;
      _ny = null;
      _loadPosition();
    }
  }

  @override
  void dispose() {
    _publish(null);
    super.dispose();
  }

  Future<void> _loadPosition() async {
    if (!widget.persistPosition) {
      return;
    }
    final Offset? saved = await ShopMenuPositionStore.load(
      widget.shopId,
      widget.userId,
    );
    if (!mounted || saved == null) {
      return;
    }
    setState(() {
      _nx = saved.dx;
      _ny = saved.dy;
    });
  }

  void _publish(Rect? rect) {
    if (_published == rect) {
      return;
    }
    _published = rect;
    final ValueNotifier<Rect?>? own = widget.ownRect;
    if (own == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || own.value == rect) {
        return;
      }
      own.value = rect;
    });
  }

  Offset _position(FloatingActionBounds bounds) {
    if (_dragging && _dragX != null && _dragY != null) {
      return Offset(_dragX!, _dragY!);
    }
    if (_nx == null || _ny == null) {
      return Offset(bounds.minX, bounds.maxY);
    }
    return Offset(bounds.denormX(_nx!), bounds.denormY(_ny!));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) {
      _publish(null);
      return const SizedBox.shrink();
    }
    final double button = ModernBottomNavigation.menuButtonSize;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final FloatingActionBounds bounds = FloatingActionBounds.resolve(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          padding: MediaQuery.paddingOf(context),
          headerHeight: widget.headerHeight,
          showBottomBar: widget.bottomBarHeight > 0,
          bottomBarHeight: widget.bottomBarHeight,
          buttonSize: Size.square(button),
        );
        final Offset pos = _position(bounds);
        _publish(Rect.fromLTWH(pos.dx, pos.dy, button, button));
        return Stack(
          key: _layerKey,
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              left: pos.dx,
              top: pos.dy,
              width: button,
              height: button,
              child: _face(bounds, pos, button),
            ),
          ],
        );
      },
    );
  }

  Widget _face(FloatingActionBounds bounds, Offset pos, double button) {
    final bool glassy = widget.surface != FrontendNavigationConfig.surfaceOpaque;
    final Widget disc = Ink(
      width: button,
      height: button,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.theme.cardColor.withValues(
          alpha: switch (widget.surface) {
            FrontendNavigationConfig.surfaceTranslucent => 0.78,
            FrontendNavigationConfig.surfaceTransparent => 0.22,
            _ => 0.96,
          },
        ),
        border: Border.all(
          color: widget.theme.cardBorderColor.withValues(alpha: 0.9),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: ShopModernLogo(
          imageUrl: widget.logoUrl,
          size: 28,
          primaryColor: widget.theme.primaryColor,
          borderRadius: 8,
        ),
      ),
    );
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        final RenderBox? layer =
            _layerKey.currentContext?.findRenderObject() as RenderBox?;
        if (layer == null) {
          return;
        }
        final Offset local = layer.globalToLocal(event.position);
        _grab = local - pos;
        _travel = 0;
        _dragging = true;
        _didDrag = false;
        _dragX = pos.dx;
        _dragY = pos.dy;
      },
      onPointerMove: (PointerMoveEvent event) {
        final RenderBox? layer =
            _layerKey.currentContext?.findRenderObject() as RenderBox?;
        if (layer == null) {
          return;
        }
        _travel += event.delta.distance;
        if (_travel < FloatingActionBounds.dragSlop) {
          return;
        }
        final Offset local = layer.globalToLocal(event.position);
        final Offset next = bounds.clampPoint(local - _grab);
        setState(() {
          _didDrag = true;
          _dragX = next.dx;
          _dragY = next.dy;
        });
      },
      onPointerUp: (_) => _finishDrag(bounds, pos, button),
      onPointerCancel: (_) => _finishDrag(bounds, pos, button),
      child: Semantics(
        button: true,
        label: '店家選單',
        child: Tooltip(
          message: '店家選單',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                if (_didDrag) {
                  _didDrag = false;
                  return;
                }
                _openSheet(context);
              },
              child: ClipOval(
                child: glassy
                    ? BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: disc,
                      )
                    : disc,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _finishDrag(FloatingActionBounds bounds, Offset origin, double button) {
    final bool dragged = _travel >= FloatingActionBounds.dragSlop;
    final Offset current = Offset(_dragX ?? origin.dx, _dragY ?? origin.dy);
    final Offset placed = dragged
        ? bounds.placeOnRelease(
            current,
            Size.square(button),
            peer: widget.peerRect?.value,
            preferLeft: true,
          )
        : origin;
    setState(() {
      _dragging = false;
      _dragX = null;
      _dragY = null;
      _didDrag = dragged;
      if (dragged) {
        _nx = bounds.normX(placed.dx);
        _ny = bounds.normY(placed.dy);
      }
    });
    if (dragged && widget.persistPosition) {
      ShopMenuPositionStore.save(
        widget.shopId,
        widget.userId,
        bounds.normX(placed.dx),
        bounds.normY(placed.dy),
      );
    }
  }

  Future<void> _openSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: <Widget>[
                    ShopModernLogo(
                      imageUrl: widget.logoUrl,
                      size: 44,
                      primaryColor: widget.theme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '目前店家',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            widget.shopName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.allowNavigation)
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('回店家後台'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onAdmin();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.home_work_outlined),
                title: const Text('返回平台'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (!widget.allowNavigation) {
                    return;
                  }
                  widget.onPlatform();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
