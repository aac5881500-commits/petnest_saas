import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';

/// 舊頁面也即時停用購買按鈕；伺服器仍會在建單交易再次驗證。
class StorePurchaseGate extends StatefulWidget {
  const StorePurchaseGate({
    super.key,
    required this.shopId,
    required this.builder,
  });
  final String shopId;
  final Widget Function(BuildContext, bool) builder;
  @override
  State<StorePurchaseGate> createState() => _StorePurchaseGateState();
}

class _StorePurchaseGateState extends State<StorePurchaseGate> {
  late final _shop = ShopService.instance.streamShop(widget.shopId);
  late final _settings = StoreSettingsService.instance.streamSettings(
    widget.shopId,
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>?>(
    stream: _shop,
    builder: (context, shop) => StreamBuilder<Map<String, dynamic>>(
      stream: _settings,
      builder: (context, settings) => widget.builder(
        context,
        !shop.hasError &&
            !settings.hasError &&
            StorefrontAccess.canAcceptOrders(
              shop: shop.data,
              settings: settings.data,
            ),
      ),
    ),
  );
}
