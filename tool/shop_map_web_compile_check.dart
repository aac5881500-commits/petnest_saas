// Compile-only map integration fixture; no key, billing or external map loading.
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_map_page.dart';

void main() => runApp(
  MaterialApp(
    home: PlatformShopMapPage(
      shops: Stream.value(const []),
      onOpenShop: (_) async {},
    ),
  ),
);
