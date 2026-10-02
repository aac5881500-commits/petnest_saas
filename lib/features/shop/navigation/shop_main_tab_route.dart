import 'package:flutter/material.dart';

/// 底部導覽的主要分頁 route。只佔店家首頁上面的一層，不另開 Navigator。
class ShopMainTabRoute {
  const ShopMainTabRoute._();

  static const String prefix = 'shop-main-tab/';

  static String nameFor(String itemId) => '$prefix$itemId';

  static bool isTab(Route<dynamic> route) {
    final String name = route.settings.name ?? '';
    return name.startsWith(prefix);
  }

  static void popToShopHome(NavigatorState navigator) {
    navigator.popUntil((Route<dynamic> route) => !isTab(route));
  }
}
