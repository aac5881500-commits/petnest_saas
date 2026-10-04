import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/editable_home_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_flow.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_geometry_reporter.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';

/// 外觀設定左側的首頁編排畫布。排序只透過回呼改草稿，不寫入 Firestore。
class HomeLayoutCanvas extends StatefulWidget {
  const HomeLayoutCanvas({
    super.key,
    required this.background,
    required this.sectionIds,
    required this.sectionOrder,
    required this.spanOf,
    required this.pinFooter,
    required this.shopInfo,
    required this.bottomInset,
    required this.selectedSectionId,
    required this.onSelectSection,
    required this.onSectionOrderChanged,
    required this.focusSectionId,
    required this.focusSectionToken,
    required this.buildSection,
  });

  final Color background;
  final List<String> sectionIds;
  final List<String> sectionOrder;
  final HomeSectionSpan Function(String sectionId) spanOf;
  final bool pinFooter;
  final Widget? shopInfo;
  final double bottomInset;
  final String? selectedSectionId;
  final ValueChanged<String>? onSelectSection;
  final ValueChanged<List<String>>? onSectionOrderChanged;
  final String? focusSectionId;
  final int focusSectionToken;
  final Widget Function(String sectionId) buildSection;

  @override
  State<HomeLayoutCanvas> createState() => _HomeLayoutCanvasState();
}

class _HomeLayoutCanvasState extends State<HomeLayoutCanvas> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _flowStackKey = GlobalKey();
  final Map<String, Rect> _geometry = <String, Rect>{};
  Map<String, Rect>? _dragGeometry;
  MultiDragGestureRecognizer? _recognizer;
  String? _dragSectionId;
  Offset? _dragOrigin;
  Offset? _dragGlobal;
  Offset _grab = Offset.zero;
  Size _dragSize = Size.zero;
  bool _finishingDrag = false;

  @override
  void initState() {
    super.initState();
    _scheduleSectionFocus();
  }

  @override
  void didUpdateWidget(HomeLayoutCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusSectionToken != oldWidget.focusSectionToken ||
        widget.focusSectionId != oldWidget.focusSectionId) {
      _scheduleSectionFocus();
    }
  }

  @override
  void dispose() {
    _recognizer?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _rememberGeometry(String sectionId, Rect global) {
    final Rect content = _toContentRect(global);
    final Rect? previous = _geometry[sectionId];
    if (previous != null &&
        (previous.top - content.top).abs() < 0.5 &&
        (previous.left - content.left).abs() < 0.5 &&
        (previous.width - content.width).abs() < 0.5 &&
        (previous.height - content.height).abs() < 0.5) {
      return;
    }
    _geometry[sectionId] = content;
  }

  RenderBox? _viewportBox() {
    if (!_scrollController.hasClients) {
      return null;
    }
    final RenderObject? object = _scrollController
        .position
        .context
        .storageContext
        .findRenderObject();
    if (object is RenderBox && object.attached && object.hasSize) {
      return object;
    }
    return null;
  }

  Rect _toContentRect(Rect global) {
    final RenderBox? viewport = _viewportBox();
    if (viewport == null) {
      return global;
    }
    final Offset origin = viewport.localToGlobal(Offset.zero);
    final double pixels = _scrollController.offset;
    return Rect.fromLTWH(
      global.left - origin.dx,
      pixels + (global.top - origin.dy),
      global.width,
      global.height,
    );
  }

  Offset _globalTopLeft(Rect content) {
    final RenderBox? viewport = _viewportBox();
    final Offset origin = viewport?.localToGlobal(Offset.zero) ?? Offset.zero;
    final double pixels = _scrollController.hasClients
        ? _scrollController.offset
        : 0;
    return Offset(origin.dx + content.left, origin.dy + content.top - pixels);
  }

  double _pointerContentX(Offset global) {
    final RenderBox? viewport = _viewportBox();
    final double left = viewport?.localToGlobal(Offset.zero).dx ?? 0;
    return global.dx - left;
  }

  double _pointerContentY(Offset global) {
    final RenderBox? viewport = _viewportBox();
    final double top = viewport?.localToGlobal(Offset.zero).dy ?? 0;
    final double pixels = _scrollController.hasClients
        ? _scrollController.offset
        : 0;
    return pixels + (global.dy - top);
  }

  void _scheduleSectionFocus() {
    final String? sectionId = widget.focusSectionId;
    if (sectionId == null || sectionId.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _revealSection(sectionId);
      });
    });
  }

  void _revealSection(String sectionId) {
    if (!_scrollController.hasClients) {
      return;
    }
    final Rect? rect = _geometry[sectionId];
    if (rect == null) {
      return;
    }
    final double target = (rect.top - 24).clamp(
      0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Widget _fixedSection(String sectionId) {
    return HomeSectionGeometryReporter(
      key: ValueKey<String>('home-section-$sectionId'),
      sectionId: sectionId,
      onChanged: _rememberGeometry,
      child: EditableHomeSection(
        sectionId: sectionId,
        selected: widget.selectedSectionId == sectionId,
        onSelect: () => widget.onSelectSection?.call(sectionId),
        child: widget.buildSection(sectionId),
      ),
    );
  }

  Widget _orderedSection(String sectionId) {
    final bool dragging = _dragSectionId == sectionId;
    return HomeSectionGeometryReporter(
      key: ValueKey<String>('home-section-$sectionId'),
      sectionId: sectionId,
      onChanged: _rememberGeometry,
      child: Opacity(
        opacity: dragging ? 0.35 : 1,
        child: EditableHomeSection(
          sectionId: sectionId,
          selected: widget.selectedSectionId == sectionId,
          onSelect: () => widget.onSelectSection?.call(sectionId),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              widget.buildSection(sectionId),
              if (sectionId == 'banners' ||
                  sectionId == 'rooms' ||
                  sectionId == 'facilities' ||
                  sectionId == 'about' ||
                  sectionId == 'announcements' ||
                  sectionId == 'policy' ||
                  sectionId == 'faq' ||
                  sectionId == 'reviews' ||
                  sectionId == 'quickBooking')
                _sectionDragHandle(
                  sectionId: sectionId,
                  tooltip: switch (sectionId) {
                    'rooms' => '拖曳整個房型介紹區塊',
                    'facilities' => '拖曳整個環境展示區塊',
                    'about' => '拖曳整個關於我們區塊',
                    'announcements' => '拖曳整個最新消息區塊',
                    'policy' => '拖曳整個入住須知區塊',
                    'faq' => '拖曳整個常見問題區塊',
                    'reviews' => '拖曳整個顧客評價區塊',
                    'quickBooking' => '拖曳整個快速預約區塊',
                    _ => '拖曳整個海報區塊',
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionDragHandle({
    required String sectionId,
    required String tooltip,
  }) {
    final bool touch =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.android;
    return Positioned(
      top: 4,
      right: 4,
      child: Tooltip(
        message: tooltip,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (PointerDownEvent event) {
            _startSectionDrag(sectionId, event, delayed: touch);
          },
          child: Material(
            key: Key('home-section-drag-$sectionId'),
            color: Colors.white.withValues(alpha: 0.94),
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 20,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startSectionDrag(
    String sectionId,
    PointerDownEvent event, {
    required bool delayed,
  }) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryButton) {
      return;
    }
    _recognizer?.dispose();
    final MultiDragGestureRecognizer recognizer = delayed
        ? DelayedMultiDragGestureRecognizer()
        : ImmediateMultiDragGestureRecognizer();
    recognizer.gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    recognizer.onStart = (Offset position) {
      final Map<String, Rect> snapshot = Map<String, Rect>.from(_geometry);
      final Rect? rect = snapshot[sectionId];
      final Offset topLeft = rect == null ? position : _globalTopLeft(rect);
      if (!mounted) {
        return null;
      }
      setState(() {
        _dragSectionId = sectionId;
        _dragOrigin = position;
        _dragGlobal = position;
        _dragGeometry = snapshot;
        _grab = position - topLeft;
        _dragSize = rect?.size ?? const Size(160, 72);
      });
      return _SectionPointerDrag(
        onUpdate: _onDragUpdate,
        onEnd: () => _finishDrag(sectionId, _dragGlobal ?? position),
        onCancel: () =>
            _finishDrag(sectionId, _dragGlobal ?? position, apply: false),
      );
    };
    _recognizer = recognizer..addPointer(event);
  }

  void _onDragUpdate(Offset global) {
    if (!mounted || _dragSectionId == null) {
      return;
    }
    _maybeAutoScroll(global);
    setState(() => _dragGlobal = global);
  }

  void _maybeAutoScroll(Offset global) {
    final RenderBox? viewport = _viewportBox();
    if (viewport == null || !_scrollController.hasClients) {
      return;
    }
    final double top = viewport.localToGlobal(Offset.zero).dy;
    final double bottom = top + viewport.size.height;
    const double edge = 48;
    const double step = 12;
    final ScrollPosition position = _scrollController.position;
    if (global.dy < top + edge) {
      position.jumpTo(
        (position.pixels - step).clamp(0, position.maxScrollExtent),
      );
    } else if (global.dy > bottom - edge) {
      position.jumpTo(
        (position.pixels + step).clamp(0, position.maxScrollExtent),
      );
    }
  }

  void _finishDrag(String sectionId, Offset global, {bool apply = true}) {
    if (_finishingDrag || _dragSectionId != sectionId) {
      return;
    }
    _finishingDrag = true;
    final Offset? origin = _dragOrigin;
    final Map<String, Rect> snapshot = Map<String, Rect>.from(
      _dragGeometry ?? _geometry,
    );
    final int oldIndex = widget.sectionIds.indexOf(sectionId);
    final bool moved =
        apply && origin != null && (global - origin).distance >= 20;
    final int slot = moved
        ? _insertSlot(global, sectionId, snapshot)
        : oldIndex;
    _dragSectionId = null;
    _dragGlobal = null;
    _dragOrigin = null;
    _dragGeometry = null;
    _dragSize = Size.zero;
    if (apply && moved && oldIndex >= 0 && slot != oldIndex) {
      final int newIndex = slot > oldIndex ? slot + 1 : slot;
      final List<String> next = HomeSectionOrder.reorderVisible(
        saved: widget.sectionOrder,
        visible: widget.sectionIds,
        oldIndex: oldIndex,
        newIndex: newIndex,
      );
      if (!_sameOrder(next, widget.sectionOrder)) {
        widget.onSectionOrderChanged?.call(next);
      }
    }
    if (apply) {
      widget.onSelectSection?.call(sectionId);
    }
    _finishingDrag = false;
    if (mounted) {
      setState(() {});
    }
  }

  /// [slot] 是拿掉被拖曳區塊之後的插入位置，座標來自拖曳開始時的快照。
  int _insertSlot(Offset global, String movingId, Map<String, Rect> snapshot) {
    final double x = _pointerContentX(global);
    final double y = _pointerContentY(global);
    final List<String> rest = List<String>.from(widget.sectionIds)
      ..remove(movingId);
    for (int index = 0; index < rest.length; index++) {
      final Rect? rect = snapshot[rest[index]];
      if (rect == null) {
        continue;
      }
      final bool overlapsY = y >= rect.top && y <= rect.bottom;
      if (overlapsY) {
        if (x <= rect.left + rect.width / 2) {
          return index;
        }
        continue;
      }
      if (y < rect.top + rect.height / 2) {
        return index;
      }
    }
    return rest.length;
  }

  Widget _dragFeedback() {
    final Offset? global = _dragGlobal;
    final RenderObject? stackObject = _flowStackKey.currentContext
        ?.findRenderObject();
    if (global == null ||
        stackObject is! RenderBox ||
        !stackObject.hasSize ||
        _dragSize.isEmpty) {
      return const SizedBox.shrink();
    }
    final Offset local = stackObject.globalToLocal(global - _grab);
    return Positioned(
      left: local.dx,
      top: local.dy,
      width: _dragSize.width,
      height: _dragSize.height,
      child: const IgnorePointer(
        child: Material(
          elevation: 8,
          color: Color(0xEBFFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(12)),
          child: SizedBox.expand(),
        ),
      ),
    );
  }

  bool _sameOrder(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.background,
      child: Column(
        children: <Widget>[
          _fixedSection('header'),
          Expanded(
            child: Stack(
              key: _flowStackKey,
              clipBehavior: Clip.none,
              children: <Widget>[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return ListView(
                      controller: _scrollController,
                      primary: false,
                      physics: _dragSectionId == null
                          ? const ClampingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        12,
                        5,
                        12,
                        widget.bottomInset,
                      ),
                      children: <Widget>[
                        ...buildHomeSectionRows(
                          sectionIds: widget.sectionIds,
                          spanOf: widget.spanOf,
                          gap: constraints.maxWidth < 760 ? 8 : 10,
                          itemBuilder: _orderedSection,
                        ),
                        if (widget.shopInfo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: widget.shopInfo,
                          ),
                      ],
                    );
                  },
                ),
                if (_dragSectionId != null) _dragFeedback(),
              ],
            ),
          ),
          if (widget.pinFooter) _fixedSection('footer'),
        ],
      ),
    );
  }
}

class _SectionPointerDrag extends Drag {
  _SectionPointerDrag({
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
  bool _opened = false;

  @override
  void update(DragUpdateDetails details) {
    // 多重拖曳的第一筆 update 把起點放在 globalPosition，位移放在 delta。
    final Offset next = _opened
        ? details.globalPosition
        : details.globalPosition + details.delta;
    _opened = true;
    onUpdate(next);
  }

  @override
  void end(DragEndDetails details) {
    onEnd();
  }

  @override
  void cancel() {
    onCancel();
  }
}
