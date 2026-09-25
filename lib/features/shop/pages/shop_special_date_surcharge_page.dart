// 檔案名稱：lib/features/shop/pages/shop_special_date_surcharge_page.dart
// 功能說明：舊特殊日期加價列表路由，改導向優惠設定管理介面。

import 'package:flutter/material.dart';
import 'shop_discount_setting_page.dart';

class ShopSpecialDateSurchargePage extends StatelessWidget {
  const ShopSpecialDateSurchargePage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return ShopDiscountSettingPage(shopId: shopId);
  }
}
