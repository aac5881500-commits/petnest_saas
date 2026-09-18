// 檔案名稱：lib/features/shop/widgets/shop_dashboard_embedded_scope.dart
// 功能說明：後台左側嵌入前台時，讓「回後台」關閉面板而不是再開一個 Dashboard。

import 'package:flutter/material.dart';

class ShopDashboardEmbeddedScope extends InheritedWidget {
  const ShopDashboardEmbeddedScope({
    super.key,
    required this.onExitEmbedded,
    required super.child,
  });

  final VoidCallback? onExitEmbedded;

  static ShopDashboardEmbeddedScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ShopDashboardEmbeddedScope>();
  }

  /// 若位於左側嵌入前台，關閉 Drawer 並關閉面板。回傳 true 表示已處理。
  static bool tryExitToDashboard(BuildContext context) {
    final ShopDashboardEmbeddedScope? scope = maybeOf(context);
    if (scope == null) {
      return false;
    }
    final VoidCallback? onExit = scope.onExitEmbedded;
    Navigator.pop(context);
    onExit?.call();
    return true;
  }

  @override
  bool updateShouldNotify(covariant ShopDashboardEmbeddedScope oldWidget) {
    return onExitEmbedded != oldWidget.onExitEmbedded;
  }
}
