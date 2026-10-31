import 'package:petnest_saas/core/services/inspection_owner_context.dart';
// 檔案名稱：lib/features/shop/widgets/shop_dashboard_navigation.dart
// 功能說明：後台內容區導航、同層切換與共用離開檢查，不變更資料儲存流程。
import 'package:flutter/material.dart';

class ShopDashboardNavigation extends NavigatorObserver with ChangeNotifier {
  ShopDashboardNavigation({this.moduleId});
  final String? moduleId;
  final navigatorKey = GlobalKey<NavigatorState>();
  final List<Route<dynamic>> _routes = [];
  final Set<Route<dynamic>> _retiring = {};
  final Map<ModalRoute<dynamic>, Set<Future<bool> Function()>> _guards = {};
  bool _switching = false;
  List<Route<dynamic>> get _details => navigatorKey.currentState == null
      ? []
      : _routes
            .where(
              (route) =>
                  route is PageRoute &&
                  route.isActive &&
                  !_retiring.contains(route) &&
                  route.settings.name != '/',
            )
            .toList();
  bool get hasDetail => _details.isNotEmpty;
  String? get selected {
    final named = _details.where((route) => route.settings.name != null);
    return named.isEmpty ? null : named.first.settings.name;
  }

  void bind(ModalRoute<dynamic> route, Future<bool> Function() guard) =>
      (_guards[route] ??= {}).add(guard);
  void unbind(ModalRoute<dynamic> route, Future<bool> Function() guard) {
    _guards[route]?.remove(guard);
    if (_guards[route]?.isEmpty == true) _guards.remove(route);
  }

  void _changed() {
    // Observer callbacks can occur during Navigator's build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  bool _disposed = false;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _retiring.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _retiring.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) _routes[index] = newRoute;
    _changed();
  }

  Future<bool> _confirmLeaveDetails() async {
    final routes = _routes
        .skip(1)
        .where((route) => !_retiring.contains(route))
        .toList()
        .reversed
        .toList();
    for (final route in routes) {
      final guards = _guards[route]?.toList();
      if (guards != null && guards.isNotEmpty) {
        for (final guard in guards) {
          if (!await guard()) return false;
        }
      } else if (route.popDisposition == RoutePopDisposition.doNotPop) {
        // Unknown secondary-page guards remain authoritative.
        await navigatorKey.currentState?.maybePop();
        return false;
      }
      if (_disposed || !_routes.contains(route)) return false;
    }
    return true;
  }

  /// Validate active editors before explicitly leaving the shop dashboard.
  Future<bool> confirmLeave() async =>
      !_disposed && await _confirmLeaveDetails();

  Future<void> switchTo({
    String? id,
    WidgetBuilder? page,
    VoidCallback? afterLeave,
    bool Function()? stillCurrent,
  }) async {
    if (_switching || (id != null && selected == id)) return;
    _switching = true;
    try {
      if (!await _confirmLeaveDetails() ||
          _disposed ||
          stillCurrent?.call() == false) {
        return;
      }
      afterLeave?.call();
      if (page != null) {
        if (id != null) InspectionOwnerContext.onView?.call(id);
        // The basic-info module may have been offscreen. Let its Navigator
        // mount before opening a destination, without mounting other pages.
        if (navigatorKey.currentState == null) {
          await WidgetsBinding.instance.endOfFrame;
        }
        if (_disposed ||
            navigatorKey.currentState == null ||
            stillCurrent?.call() == false) {
          return;
        }
        // Keep the old page covered until its replacement is visible; never
        // pop to the overview and wait a frame between same-level pages.
        final root = _routes.first;
        _retiring.addAll(_routes.skip(1));
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: id),
            builder: page,
          ),
          (route) => route == root,
        );
      } else {
        final routes = _routes
            .skip(1)
            .where((route) => !_retiring.contains(route))
            .toList()
            .reversed
            .toList();
        for (final route in routes) {
          if (_routes.last != route) return;
          navigatorKey.currentState!.pop();
        }
      }
    } finally {
      _switching = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void detach() {
    _routes.clear();
    _retiring.clear();
    _guards.clear();
  }
}

class ShopDashboardNavigationScope extends InheritedWidget {
  const ShopDashboardNavigationScope({
    super.key,
    required this.navigation,
    required this.desktop,
    required this.openEntry,
    required super.child,
  });
  final ShopDashboardNavigation navigation;
  final bool desktop;
  final Future<void> Function(String) openEntry;
  static ShopDashboardNavigationScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ShopDashboardNavigationScope>();
  @override
  bool updateShouldNotify(ShopDashboardNavigationScope oldWidget) => true;
}

class ShopDashboardContentNavigator extends StatefulWidget {
  const ShopDashboardContentNavigator({
    super.key,
    required this.navigation,
    required this.child,
  });
  final ShopDashboardNavigation navigation;
  final Widget child;
  @override
  State<ShopDashboardContentNavigator> createState() =>
      _ShopDashboardContentNavigatorState();
}

class _ShopDashboardContentNavigatorState
    extends State<ShopDashboardContentNavigator>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final ValueNotifier<Widget> _root = ValueNotifier(widget.child);
  @override
  void didUpdateWidget(covariant ShopDashboardContentNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _root.value = widget.child;
  }

  @override
  void dispose() {
    widget.navigation.detach();
    _root.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final parentScope = ShopDashboardNavigationScope.maybeOf(context);
    return ShopDashboardNavigationScope(
      navigation: widget.navigation,
      desktop: parentScope?.desktop ?? false,
      openEntry: parentScope?.openEntry ?? (_) async {},
      child: NavigatorPopHandler<Object?>(
        onPopWithResult: (result) =>
            widget.navigation.navigatorKey.currentState?.maybePop(result),
        child: Navigator(
          key: widget.navigation.navigatorKey,
          observers: [widget.navigation],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/'),
            builder: (_) => ValueListenableBuilder<Widget>(
              valueListenable: _root,
              builder: (_, child, _) => child,
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDashboardDiscard(
  BuildContext context, {
  required bool dirty,
  required bool busy,
}) async {
  if (busy) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('處理中，請稍候再離開')));
    return false;
  }
  if (!dirty) return true;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('尚未儲存'),
          content: const Text('離開後，尚未儲存的變更將會放棄。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('繼續編輯'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放棄變更並離開'),
            ),
          ],
        ),
      ) ==
      true;
}

/// 每個編輯頁提供自己的草稿與忙碌狀態；原有離開提示可覆寫確認方法。
mixin ShopDashboardLeaveAware<T extends StatefulWidget> on State<T> {
  ShopDashboardNavigation? _navigation;
  ModalRoute<dynamic>? _route;
  bool get dashboardHasUnsavedChanges;
  bool get dashboardIsBusy;
  Future<bool> dashboardConfirmLeave() => InspectionOwnerContext.active
      ? Future.value(true)
      : confirmDashboardDiscard(
          context,
          dirty: dashboardHasUnsavedChanges,
          busy: dashboardIsBusy,
        );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigation = ShopDashboardNavigationScope.maybeOf(
      context,
    )?.navigation;
    final route = ModalRoute.of(context);
    if (_route != null) _navigation?.unbind(_route!, dashboardConfirmLeave);
    _navigation = navigation;
    _route = route;
    if (route != null) navigation?.bind(route, dashboardConfirmLeave);
  }

  Widget dashboardGuard(Widget child) => PopScope(
    // Read the live draft on every back attempt, including text fields whose
    // parent does not rebuild for each keystroke.
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && await dashboardConfirmLeave() && mounted) {
        Navigator.of(context).pop(result);
      }
    },
    child: child,
  );
  @override
  void dispose() {
    if (_route != null) _navigation?.unbind(_route!, dashboardConfirmLeave);
    super.dispose();
  }
}
