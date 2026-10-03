// 檔案名稱：lib/core/navigation/shop_operations_workbench.dart
// 功能說明：從訂單詳細回到既有營運工作台，避免重複堆疊同一頁。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/room/pages/room_dashboard_page.dart';

const String shopOperationsWorkbenchRouteName = '/shop-operations-workbench';

Route<void> shopOperationsWorkbenchRoute(String shopId) {
  return MaterialPageRoute<void>(
    settings: const RouteSettings(name: shopOperationsWorkbenchRouteName),
    builder: (_) => RoomDashboardPage(shopId: shopId),
  );
}

/// 堆疊裡已有營運工作台就 pop 回去；否則再開既有工作台頁。
void openShopOperationsWorkbench(
  BuildContext context, {
  required String shopId,
}) {
  final NavigatorState navigator = Navigator.of(context);
  bool found = false;
  navigator.popUntil((Route<dynamic> route) {
    if (route.settings.name == shopOperationsWorkbenchRouteName) {
      found = true;
      return true;
    }
    return route.isFirst;
  });
  if (!found && shopId.trim().isNotEmpty) {
    navigator.push(shopOperationsWorkbenchRoute(shopId.trim()));
  }
}
