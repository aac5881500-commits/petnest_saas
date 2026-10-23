import 'package:petnest_saas/features/shop/widgets/shop_feature_tour.dart';
// 檔案名稱：lib/features/shop/pages/shop_payment_setting_page.dart
// 功能說明：使用 Tab 切換訂金設定、優惠設定與點數設定
// 💳 收款與優惠設定頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'shop_point_setting_page.dart';
import 'shop_deposit_setting_page.dart';
import 'shop_discount_setting_page.dart';

class ShopPaymentSettingPage extends StatelessWidget {
  const ShopPaymentSettingPage({
    super.key,
    required this.shopId,
    this.tabPages,
    this.showTaskCenterButton = true,
  }) : assert(tabPages == null || tabPages.length == 3);

  final String shopId;

  /// Optional local preview/test content; normal navigation uses the real pages.
  final List<Widget>? tabPages;
  final bool showTaskCenterButton;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (tabContext) => ShopTourPage(
          id: 'ShopPaymentSettingPage',
          shopId: shopId,
          onPoint: (point) async {
            DefaultTabController.of(tabContext).index = shopTourPanel(
              'ShopPaymentSettingPage',
              point,
            );
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('營運設定'),
              actions: showTaskCenterButton
                  ? <Widget>[ShopTaskCenterButton(shopId: shopId)]
                  : const [],
              bottom: const TabBar(
                tabs: <Widget>[
                  Tab(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    text: '收款設定',
                  ),
                  Tab(icon: Icon(Icons.local_offer_outlined), text: '優惠設定'),
                  Tab(icon: Icon(Icons.stars_outlined), text: '點數設定'),
                ],
              ),
            ),
            body: TabBarView(
              children:
                  tabPages ??
                  <Widget>[
                    ShopDepositSettingPage(shopId: shopId, embedded: true),
                    ShopDiscountSettingPage(shopId: shopId, embedded: true),
                    ShopPointSettingPage(shopId: shopId, embedded: true),
                  ],
            ),
          ),
        ),
      ),
    );
  }
}
