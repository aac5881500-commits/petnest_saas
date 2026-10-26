import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart';
part 'shop_feature_tour_content.dart';

class ShopTourTopic {
  const ShopTourTopic(this.id, this.name, this.icon, this.points);
  final String id, name;
  final IconData icon;
  final List<(String, String)> points;
}

/// A one-shot handoff, emitted only by the confirmed opening success action.
class ShopFeatureTourRequest {
  static final pending = ValueNotifier<(String, String)?>(null);
  static void start(String uid, String shopId) => pending.value = (uid, shopId);
}

class ShopFeatureTourController extends ChangeNotifier {
  ShopFeatureTourController({required this.uid, required this.shopId});
  final String uid, shopId;
  String get storageKey => 'shopFeatureTour:v1:$uid:$shopId';
  final Set<String> understood = {};
  final Map<String, String> skipped = {};
  List<String> visible = [];
  Map<String, bool> available = {};
  String? current;
  int point = 0;
  bool paused = true,
      completed = false,
      loaded = false,
      inPage = false,
      busy = false;
  bool _disposed = false, _queued = false;
  int _session = 0;
  Future<void> _writes = Future.value();
  final Map<String, Set<_ShopTourAnchorState>> _anchors = {};
  Future<bool> Function()? returnToMenu;
  Future<bool> Function()? selectCat;
  Future<bool> Function(String)? recoverPage;
  bool Function(String)? isPageVisible;
  Future<bool> Function()? canStart;
  bool get active => loaded && !paused && !completed && current != null;
  ShopTourTopic? get topic =>
      shopTourTopics.where((t) => t.id == current).firstOrNull;
  List<String> get participating =>
      visible.where((id) => available[id] == true).toList();
  String get targetId => inPage ? '$current.$point' : 'entry:$current';
  _ShopTourAnchorState? get _target =>
      _anchors[targetId]?.where((a) => a.usable(this)).firstOrNull;
  int get pointCount => topic?.points.length ?? 1;
  int get session => _session;
  String? preparationError;
  bool get hasTargetError => _target?.widget.error != null;

  Future<void> recover() async {
    if (!active || busy) return;
    final id = current!, token = ++_session;
    busy = true;
    preparationError = null;
    changed();
    try {
      final ok = recoverPage != null
          ? await recoverPage!(id)
          : await selectCat?.call() == true;
      if (_disposed || token != _session || !active) return;
      if (!ok) preparationError = '尚未返回介紹頁；請確認未儲存變更或重試。';
    } catch (_) {
      if (!_disposed && token == _session) preparationError = '返回介紹頁失敗，請重試。';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> load() async {
    try {
      final text = (await SharedPreferences.getInstance()).getString(
        storageKey,
      );
      if (_disposed) return;
      if (text != null) {
        final data = jsonDecode(text) as Map<String, dynamic>;
        understood.addAll(List<String>.from(data['understood'] ?? []));
        skipped.addAll(Map<String, String>.from(data['skipped'] ?? {}));
        current = data['current'] as String?;
        final oldPoint = (data['point'] as int? ?? 0).clamp(0, 2);
        point = data['contentVersion'] == 2
            ? (data['point'] as int? ?? 0)
            : (_legacyPoints[current]?[oldPoint] ?? oldPoint);
        point = point.clamp(0, pointCount - 1);
        completed = data['completed'] == true;
      }
    } catch (_) {
      /* An unavailable local preference never changes business data. */
    }
    if (_disposed) return;
    loaded = true;
    // Reloading a device never auto-starts an interrupted tour.
    paused = true;
    changed();
  }

  Future<void> persist() {
    final text = jsonEncode({
      'understood': understood.toList(),
      'contentVersion': 2,
      'skipped': skipped,
      'current': current,
      'point': point,
      'paused': paused,
      'completed': completed,
    });
    _writes = _writes
        .then((_) async {
          await (await SharedPreferences.getInstance()).setString(
            storageKey,
            text,
          );
        })
        .catchError((Object _) {});
    return _writes;
  }

  void configure(Map<String, bool> entries) {
    visible = shopTourTopics
        .where((t) => entries.containsKey(t.id))
        .map((t) => t.id)
        .toList();
    available = Map.of(entries);
    for (final topic in shopTourTopics) {
      if (!entries.containsKey(topic.id)) {
        skipped[topic.id] = '目前使用者沒有此入口權限';
      } else if (entries[topic.id] != true) {
        skipped[topic.id] = '目前方案或必要資料尚未開放此入口';
      } else {
        skipped.remove(topic.id);
      }
    }
    if (active && !visible.contains(current)) {
      pause();
    }
  }

  Future<void> start({bool restart = false}) async {
    if (_disposed || !loaded || busy) return;
    final session = ++_session;
    preparationError = null;
    busy = true;
    changed();
    try {
      if (canStart != null && await canStart!() != true) return;
      if (_disposed || session != _session) return;
      if (await selectCat?.call() != true || _disposed || session != _session) {
        return;
      }
      if (restart) {
        understood.clear();
        current = null;
        point = 0;
      }
      if (restart ||
          !visible.contains(current) ||
          understood.contains(current)) {
        current = visible.where((id) => !understood.contains(id)).firstOrNull;
        point = 0;
      }
      completed = current == null;
      paused = false;
      inPage = false;
      await persist();
      changed();
    } finally {
      busy = false;
      changed();
    }
  }

  void pause() {
    if (_disposed) return;
    _session++;
    paused = true;
    unawaited(persist());
    changed();
  }

  void changed() {
    if (_queued || _disposed) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void pageMounted(String id) {
    if (active && id == current && !inPage) {
      inPage = true;
      changed();
    }
  }

  Future<void> next({bool back = false}) async {
    if (_disposed || !active || busy) return;
    if (back && inPage && point > 0) {
      _session++;
      preparationError = null;
      point--;
      await persist();
      changed();
      return;
    }
    if (preparationError != null) return;
    if (!inPage && available[current] == true) {
      return; // Must enter the real page.
    }
    if (inPage &&
        (_target == null ||
            !_target!.widget.ready ||
            _target!.widget.error != null)) {
      return;
    }
    if (inPage && point < pointCount - 1) {
      _session++;
      preparationError = null;
      point++;
      await persist();
      changed();
      return;
    }
    busy = true;
    changed();
    final finishedId = current!;
    final wasInPage = inPage;
    final session = _session;
    try {
      // Leave checks finish before a page is recorded as understood.
      if (await returnToMenu?.call() != true ||
          _disposed ||
          !active ||
          session != _session ||
          current != finishedId) {
        return;
      }
      if (wasInPage) understood.add(finishedId);
      final next = visible
          .skipWhile((id) => id != current)
          .skip(1)
          .where((id) => !understood.contains(id))
          .firstOrNull;
      current = next;
      point = 0;
      inPage = false;
      completed = next == null;
      await persist();
    } finally {
      busy = false;
      changed();
    }
  }

  @override
  void dispose() {
    _session++;
    _disposed = true;
    _anchors.clear();
    super.dispose();
  }
}

class ShopFeatureTourScope extends InheritedWidget {
  const ShopFeatureTourScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final ShopFeatureTourController controller;
  static ShopFeatureTourController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ShopFeatureTourScope>()
      ?.controller;
  @override
  bool updateShouldNotify(ShopFeatureTourScope oldWidget) =>
      oldWidget.controller != controller;
}

/// Stable anchors are attached to real controls, including loaded empty states.
class ShopTourAnchor extends StatefulWidget {
  const ShopTourAnchor({
    super.key,
    required this.ids,
    required this.child,
    this.ready = true,
    this.error,
  });
  final List<String> ids;
  final Widget child;
  final bool ready;
  final Object? error;
  @override
  State<ShopTourAnchor> createState() => _ShopTourAnchorState();
}

class _ShopTourAnchorState extends State<ShopTourAnchor> {
  ShopFeatureTourController? tour;
  bool _live = true;
  _ShopTourPageState? get page =>
      context.findAncestorStateOfType<_ShopTourPageState>();
  bool usable(ShopFeatureTourController t) =>
      mounted &&
      _live &&
      tour == t &&
      ModalRoute.of(context)?.isCurrent != false &&
      (t.isPageVisible?.call(t.current!) ?? true) &&
      (!t.inPage || page?.widget.id == t.current) &&
      (page?.widget.shopId == null || page?.widget.shopId == t.shopId) &&
      _tourVisible(context);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  void _register() {
    final next = ShopFeatureTourScope.maybeOf(context);
    if (tour != next) _unregister();
    tour = next;
    for (final id in widget.ids) {
      tour?._anchors.putIfAbsent(id, () => {}).add(this);
    }
    tour?.changed();
  }

  void _unregister() {
    for (final id in widget.ids) {
      tour?._anchors[id]?.remove(this);
    }
  }

  @override
  void deactivate() {
    _live = false;
    _unregister();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _live = true;
  }

  @override
  void didUpdateWidget(ShopTourAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final id in oldWidget.ids) {
      tour?._anchors[id]?.remove(this);
    }
    _register();
  }

  @override
  void dispose() {
    _unregister();
    tour?.changed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ShopTourPage extends StatefulWidget {
  const ShopTourPage({
    super.key,
    required this.id,
    required this.child,
    this.onPoint,
    this.ready = true,
    this.error,
    this.shopId,
  });
  final String? shopId;
  final String id;
  final Widget child;
  final Future<void> Function(int)? onPoint;
  final bool ready;
  final Object? error;
  @override
  State<ShopTourPage> createState() => _ShopTourPageState();
}

class _ShopTourPageState extends State<ShopTourPage> {
  ShopFeatureTourController? tour;
  (int, int)? _prepared;
  _ShopTourPageState? _parentPage;
  bool _live = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parentPage = context.findAncestorStateOfType<_ShopTourPageState>();
    final next = ShopFeatureTourScope.maybeOf(context);
    if (next != tour) {
      tour?.removeListener(_update);
      _prepared = null;
      tour = next;
      tour?.addListener(_update);
    }
    _update();
  }

  @override
  void didUpdateWidget(ShopTourPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.ready && widget.ready) _prepared = null;
    _update();
  }

  void _update() {
    if (!_live) return;
    final t = tour;
    if (t == null || !t.active) {
      _prepared = null;
      return;
    }
    if ((widget.shopId != null && t.shopId != widget.shopId) ||
        t.current != widget.id ||
        ModalRoute.of(context)?.isCurrent != true ||
        !(t.isPageVisible?.call(widget.id) ?? true) ||
        !_tourVisible(context)) {
      return;
    }
    t.pageMounted(widget.id);
    if (!widget.ready || widget.error != null) return;
    final preparing = (t.session, t.point);
    if (_prepared != preparing) {
      _prepared = preparing;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted ||
            !_live ||
            !t.active ||
            preparing != (t.session, t.point) ||
            t.current != widget.id ||
            !(t.isPageVisible?.call(widget.id) ?? true) ||
            !_tourVisible(context) ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        try {
          await widget.onPoint?.call(preparing.$2);
        } catch (_) {
          if (mounted && preparing == (t.session, t.point)) {
            t.preparationError = '介紹分頁尚未準備完成，請重新定位。';
          }
        }
        if (mounted && _live && t.active && preparing == (t.session, t.point)) {
          t.changed();
        }
      });
    }
  }

  @override
  void dispose() {
    tour?.removeListener(_update);
    final t = tour;
    if (_parentPage?.widget.id != widget.id &&
        t != null &&
        t.active &&
        t.current == widget.id &&
        !t.busy) {
      t.inPage = false;
      t.changed();
    }
    _prepared = null;
    super.dispose();
  }

  @override
  void deactivate() {
    _live = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _live = true;
    _prepared = null;
  }

  @override
  Widget build(BuildContext context) => !widget.ready || widget.error != null
      ? ShopTourAnchor(
          ids: [
            for (
              var i = 0;
              i <
                  (shopTourTopics
                          .where((t) => t.id == widget.id)
                          .firstOrNull
                          ?.points
                          .length ??
                      0);
              i++
            )
              '${widget.id}.$i',
          ],
          ready: widget.ready,
          error: widget.error,
          child: widget.child,
        )
      : widget.child;
}

class ShopFeatureTourEntry extends StatelessWidget {
  const ShopFeatureTourEntry({super.key});
  @override
  Widget build(BuildContext context) {
    final t = ShopFeatureTourScope.maybeOf(context);
    if (t == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: t,
      builder: (context, _) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.explore_outlined),
          onPressed: !t.loaded || t.busy
              ? null
              : () => t.start(restart: t.completed),
          label: Text(
            t.busy
                ? '正在確認導覽…'
                : t.completed
                ? '重新查看功能導覽'
                : '繼續認識後台',
          ),
        ),
      ),
    );
  }
}

// A kept-alive route/tab may still be mounted and report isCurrent. Reject
// offstage children, inactive IndexedStack children and horizontally hidden
// pages before attempting any scrolling. Vertical offscreen content is valid.
bool _tourVisible(BuildContext context) {
  RenderObject? child = context.findRenderObject();
  if (child is! RenderBox || !child.attached || !child.hasSize) return false;
  final target = child;
  for (
    RenderObject? parent = child.parent;
    parent != null;
    child = parent, parent = parent.parent
  ) {
    if (parent is RenderOffstage && parent.offstage) return false;
    if (parent is RenderIndexedStack &&
        (parent.index == null ||
            parent.getChildrenAsList().indexOf(child! as RenderBox) !=
                parent.index)) {
      return false;
    }
    if (parent is RenderAbstractViewport && parent is RenderBox) {
      final viewport = parent as RenderBox;
      if (!viewport.hasSize) return false;
      final rect =
          target.localToGlobal(Offset.zero, ancestor: parent) & target.size;
      if (rect.right <= 1 || rect.left >= viewport.size.width - 1) return false;
    }
  }
  return true;
}

ScrollableState? _tourScroll(BuildContext context) {
  ScrollableState? found;
  context.visitAncestorElements((element) {
    if (element.widget is ShopTourPage ||
        element.widget is ShopFeatureTourHost) {
      return false;
    }
    if (element is StatefulElement && element.state is ScrollableState) {
      final state = element.state as ScrollableState;
      if (axisDirectionToAxis(state.axisDirection) == Axis.vertical) {
        found = state;
        return false;
      }
    }
    return true;
  });
  return found;
}

/// One host covers the existing workspace. Read-only page targets never pass hits.
class ShopFeatureTourHost extends StatefulWidget {
  const ShopFeatureTourHost({
    super.key,
    required this.controller,
    required this.child,
  });
  final ShopFeatureTourController controller;
  final Widget child;
  @override
  State<ShopFeatureTourHost> createState() => _ShopFeatureTourHostState();
}

class _ShopFeatureTourHostState extends State<ShopFeatureTourHost>
    with WidgetsBindingObserver {
  final _surface = GlobalKey();
  final _coach = GlobalKey();
  final _scope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  Rect? _rect;
  String? _located;
  bool _measureQueued = false;
  String? _focusTarget;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    WidgetsBinding.instance.addObserver(this);
  }

  void _update() {
    if (mounted) {
      final t = widget.controller;
      if (t.active && _focusTarget != t.targetId) {
        _focusTarget = t.targetId;
        _rect = null;
        _located = null;
        FocusManager.instance.primaryFocus?.unfocus();
      }
      setState(() {});
      _measure();
    }
  }

  @override
  void didUpdateWidget(ShopFeatureTourHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_update);
      widget.controller.addListener(_update);
      _rect = null;
      _located = null;
      _focusTarget = null;
    }
  }

  @override
  void didChangeMetrics() {
    _located = null;
    _measure();
  }

  void _measure() {
    if (_measureQueued) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _measureQueued = false;
      if (!mounted) return;
      final t = widget.controller;
      final anchor = t._target;
      final session = t.session;
      final identity = '${t.targetId}:${identityHashCode(anchor)}';
      if (t.active &&
          anchor != null &&
          anchor.mounted &&
          _located != identity) {
        _located = identity;
        // Only scroll vertical content owned by this page/menu. Never traverse
        // an outer horizontal TabBarView (dashboard modules or service tabs).
        final target = anchor.context.findRenderObject();
        final scroll = _tourScroll(anchor.context);
        if (target != null && scroll != null) {
          scroll.position.ensureVisible(target, alignment: .15);
        }
        if (!mounted ||
            !t.active ||
            session != t.session ||
            identity != '${t.targetId}:${identityHashCode(t._target)}') {
          return;
        }
      }
      final target = anchor?.context.findRenderObject();
      final surface = _surface.currentContext?.findRenderObject();
      Rect? rect;
      if (t.active &&
          anchor != null &&
          anchor.usable(t) &&
          target is RenderBox &&
          target.attached &&
          target.hasSize &&
          surface is RenderBox &&
          surface.hasSize) {
        final original =
            surface.globalToLocal(target.localToGlobal(Offset.zero)) &
            target.size;
        final viewport = _tourScroll(
          anchor.context,
        )?.context.findRenderObject();
        final visible = viewport is RenderBox && viewport.hasSize
            ? (surface.globalToLocal(viewport.localToGlobal(Offset.zero)) &
                  viewport.size)
            : Offset.zero & surface.size;
        final clipped = original
            .intersect(visible)
            .intersect(Offset.zero & surface.size);
        if (clipped.width > 8 && clipped.height > 8) rect = clipped;
      }
      if (_rect != rect && mounted) setState(() => _rect = rect);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    WidgetsBinding.instance.removeObserver(this);
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.controller;
    final currentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final show = currentRoute && (t.active || (t.completed && !t.paused));
    _measure();
    return ShopFeatureTourScope(
      controller: t,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final desktop = bounds.maxWidth >= 1000;
          final cardHeight = math.min(
            t.inPage ? 300.0 : 250.0,
            bounds.maxHeight * .44,
          );
          final desktopCardHeight = math.min(
            t.inPage ? 360.0 : 300.0,
            bounds.maxHeight - 16,
          );
          final padding = !show
              ? EdgeInsets.zero
              : desktop
              ? const EdgeInsets.only(right: 370)
              : EdgeInsets.only(
                  bottom: cardHeight + MediaQuery.paddingOf(context).bottom,
                );
          final targetReady =
              t.preparationError == null &&
              t._target?.widget.ready == true &&
              t._target?.widget.error == null &&
              _rect != null;
          return FocusTraversalGroup(
            policy: _TourTraversalPolicy(t, _coach),
            child: FocusScope(
              node: _scope,
              child: NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _measure();
                  return false;
                },
                child: Stack(
                  key: _surface,
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: padding,
                      child: ExcludeFocus(
                        excluding: show && t.inPage,
                        child: widget.child,
                      ),
                    ),
                    if (show && t.active)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TourShade(
                            _rect,
                            allowTarget:
                                !t.inPage &&
                                t.available[t.current] == true &&
                                targetReady,
                          ),
                        ),
                      ),
                    if (show &&
                        t.active &&
                        !t.inPage &&
                        targetReady &&
                        t.available[t.current] == true)
                      Positioned(
                        left: _rect!.left.clamp(
                          8.0,
                          math.max(
                            8.0,
                            bounds.maxWidth - (desktop ? 370 : 0) - 172,
                          ),
                        ),
                        top:
                            (_rect!.top >= 46
                                    ? _rect!.top - 38
                                    : _rect!.bottom + 6)
                                .clamp(
                                  8.0,
                                  math.max(
                                    8.0,
                                    bounds.maxHeight -
                                        (desktop ? 48 : cardHeight + 48),
                                  ),
                                ),
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFBE62),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 19,
                                  color: Color(0xFF533400),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  '點這裡繼續',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF533400),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (show)
                      Positioned(
                        right: desktop ? 12 : 8,
                        left: desktop ? null : 8,
                        top: desktop
                            ? (_rect?.top ?? 8.0).clamp(
                                8.0,
                                math.max(
                                  8.0,
                                  bounds.maxHeight - desktopCardHeight - 8,
                                ),
                              )
                            : null,
                        bottom: desktop
                            ? null
                            : 8 + MediaQuery.paddingOf(context).bottom,
                        width: desktop ? 346 : null,
                        height: desktop ? desktopCardHeight : cardHeight - 8,
                        child: Card(
                          key: _coach,
                          elevation: 8,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!t.completed)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: t.busy ? null : t.pause,
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF64748B,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.pause_outlined,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        '暫停導覽',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (t.completed) ...[
                                          const Text(
                                            '後台功能導覽完成',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const Text(
                                            '你已認識主要設定入口，之後可以依實際營運需要，逐步補齊各項設定。',
                                          ),
                                        ] else if (t.topic != null) ...[
                                          Row(
                                            children: [
                                              Icon(t.topic!.icon),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  t.topic!.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            t.available[t.current] != true
                                                ? '方案／必要資料限制・已了解 ${t.participating.where(t.understood.contains).length}／${t.participating.length}'
                                                : '認識後台 ${t.participating.indexOf(t.current!) + 1}／${t.participating.length} ${t.inPage ? '・重點 ${t.point + 1}／${t.pointCount}' : ''}',
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            t.inPage
                                                ? t.topic!.points[t.point].$1
                                                : '點擊亮框的功能卡片繼續',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (t.inPage)
                                            for (final paragraph
                                                in t.topic!.points[t.point].$2
                                                    .split('\n\n'))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 10,
                                                ),
                                                child:
                                                    paragraph.startsWith('範例：')
                                                    ? Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              10,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .surfaceContainerHighest,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Text(paragraph),
                                                      )
                                                    : Text(
                                                        paragraph,
                                                        style: const TextStyle(
                                                          height: 1.5,
                                                        ),
                                                      ),
                                              )
                                          else
                                            Text(
                                              t.available[t.current] == true
                                                  ? '進入頁面後，一起認識設定用途。導覽不會儲存或啟用任何服務。'
                                                  : '此入口目前受方案或必要資料限制，先認識用途即可略過，不需要升級。',
                                            ),
                                          if (t.preparationError != null)
                                            Text(t.preparationError!),
                                          if (!targetReady)
                                            Text(
                                              t._target?.widget.error != null
                                                  ? '資料讀取失敗，請暫停導覽後重試本頁。'
                                                  : t._target?.widget.ready ==
                                                        false
                                                  ? '資料載入中；可暫停後繼續。'
                                                  : '目標尚未就緒或不在可見區域。可捲動定位，或暫停後重試本頁。',
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                if (!t.completed &&
                                    !t.inPage &&
                                    targetReady &&
                                    t.available[t.current] == true)
                                  Container(
                                    key: const Key('tour-real-entry-hint'),
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3DF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.touch_app_rounded,
                                          color: Color(0xFF9A5700),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '請點畫面中的「${t.topic!.name}」',
                                            style: const TextStyle(
                                              color: Color(0xFF754300),
                                              fontWeight: FontWeight.w700,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (t.completed)
                                  FilledButton(
                                    onPressed: t.pause,
                                    child: const Text('開始使用後台'),
                                  )
                                else
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (!targetReady ||
                                          t.preparationError != null)
                                        TextButton(
                                          onPressed: t.busy
                                              ? null
                                              : () async {
                                                  _located = null;
                                                  _rect = null;
                                                  await t.recover();
                                                  if (mounted) _measure();
                                                },
                                          child: Text(
                                            t.inPage
                                                ? '返回目前介紹頁／重新定位'
                                                : '返回貓咪旅店選單',
                                          ),
                                        ),
                                      if (t.inPage && t.point > 0)
                                        TextButton(
                                          onPressed: t.busy
                                              ? null
                                              : () => t.next(back: true),
                                          child: const Text('上一個重點'),
                                        ),
                                      if (t.inPage ||
                                          t.available[t.current] != true)
                                        FilledButton(
                                          onPressed: t.busy || !targetReady
                                              ? null
                                              : () => t.next(),
                                          child: Text(
                                            !t.inPage
                                                ? '了解限制，略過'
                                                : t.point < t.pointCount - 1
                                                ? '下一個重點'
                                                : '了解，前往下一頁',
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TourShade extends CustomPainter {
  _TourShade(this.rect, {required this.allowTarget});
  final Rect? rect;
  final bool allowTarget;
  @override
  void paint(Canvas canvas, Size size) {
    if (rect == null) return;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (rect != null) {
      path.addRRect(RRect.fromRectAndRadius(rect!, const Radius.circular(10)));
    }
    canvas.drawPath(path, Paint()..color = const Color(0x88000000));
    if (rect != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect!, const Radius.circular(10)),
        Paint()
          ..color = const Color(0xFFFFBE62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final tip = Offset(rect!.center.dx, rect!.top + 6);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx - 7, tip.dy + 9)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(tip.dx + 7, tip.dy + 9),
        Paint()
          ..color = const Color(0xFFFFBE62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool hitTest(Offset position) =>
      !(allowTarget && rect?.contains(position) == true);
  @override
  bool shouldRepaint(_TourShade oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.allowTarget != allowTarget;
}

class _TourTraversalPolicy extends WidgetOrderTraversalPolicy {
  _TourTraversalPolicy(this.tour, this.coach);
  final ShopFeatureTourController tour;
  final GlobalKey coach;
  bool _within(BuildContext? context, BuildContext? ancestor) {
    if (context == null || ancestor == null) return false;
    if (context == ancestor) return true;
    var found = false;
    context.visitAncestorElements((element) {
      found = element == ancestor;
      return !found;
    });
    return found;
  }

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) => super.sortDescendants(
    descendants.where(
      (node) =>
          !tour.active ||
          _within(node.context, coach.currentContext) ||
          (!tour.inPage && _within(node.context, tour._target?.context)),
    ),
    currentNode,
  );
}
