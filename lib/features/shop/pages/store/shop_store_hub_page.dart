// lib/features/shop/pages/store/shop_store_hub_page.dart
// 🛒 店家賣場後台

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_category_page.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_order_list_page.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_product_list_page.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_promotion_list_page.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_settings_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_admin_summary_bar.dart';

class ShopStoreHubPage extends StatelessWidget {
  const ShopStoreHubPage({super.key, required this.shopId, this.memberData});

  final String shopId;
  final Map<String, dynamic>? memberData;

  bool _can(String key) {
    return ShopService.instance.hasPermission(memberData, key);
  }

  @override
  Widget build(BuildContext context) {
    final bool canProducts = _can(ShopPermissionKeys.manageStoreProducts);
    final bool canOrders =
        _can(ShopPermissionKeys.viewStoreOrders) ||
        _can(ShopPermissionKeys.manageStoreOrders);
    final bool canSettings = _can(ShopPermissionKeys.manageStoreSettings);

    return DefaultTabController(
      length: 5,
      child: Column(
        children: <Widget>[
          StoreAdminSummaryBar(shopId: shopId),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: '商品'),
              Tab(text: '訂單'),
              Tab(text: '分類'),
              Tab(text: '促銷活動'),
              Tab(text: '設定'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                ShopStoreProductListPage(
                  shopId: shopId,
                  canManage: canProducts,
                ),
                ShopStoreOrderListPage(
                  shopId: shopId,
                  canManage: _can(ShopPermissionKeys.manageStoreOrders),
                  canView: canOrders,
                ),
                ShopStoreCategoryPage(shopId: shopId, canManage: canProducts),
                ShopStorePromotionListPage(
                  shopId: shopId,
                  canManage: canProducts,
                ),
                ShopStoreSettingsPage(shopId: shopId, canManage: canSettings),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
