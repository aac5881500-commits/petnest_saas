// 檔案名稱：lib/features/shop/widgets/shop_dashboard_embedded_scope.dart
// 功能說明：Dashboard 內嵌正式前台時，只鎖巢狀後台入口，不攔截下單或寫入。

import 'package:flutter/material.dart';

class ShopDashboardEmbeddedScope extends InheritedWidget {
  const ShopDashboardEmbeddedScope({
    super.key,
    required super.child,
    this.onExitEmbedded,
    this.embeddedInShopDashboard = true,
  });

  final VoidCallback? onExitEmbedded;
  final bool embeddedInShopDashboard;

  static ShopDashboardEmbeddedScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ShopDashboardEmbeddedScope>();
  }

  static bool isEmbeddedInShopDashboard(BuildContext context) {
    return maybeOf(context)?.embeddedInShopDashboard == true;
  }

  /// 若位於嵌入前台，只關閉 Drawer／預覽框，不改後台 Tab。回傳 true 表示已處理。
  static bool tryExitToDashboard(BuildContext context) {
    final ShopDashboardEmbeddedScope? scope = maybeOf(context);
    if (scope == null || !scope.embeddedInShopDashboard) {
      return false;
    }
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    scope.onExitEmbedded?.call();
    return true;
  }

  /// 內嵌前台必須能正式下單，此方法永遠不攔截寫入。
  static bool blockMutations(BuildContext context) {
    return false;
  }

  @override
  bool updateShouldNotify(covariant ShopDashboardEmbeddedScope oldWidget) {
    return onExitEmbedded != oldWidget.onExitEmbedded ||
        embeddedInShopDashboard != oldWidget.embeddedInShopDashboard;
  }
}
