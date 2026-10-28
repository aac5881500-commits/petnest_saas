// 檔案名稱：lib/features/shop/pages/shop_code_redirect_page.dart
// 功能說明：店家短網址轉址頁

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';

class ShopCodeRedirectPage extends StatefulWidget {
  const ShopCodeRedirectPage({super.key, required this.shopCode});

  final String shopCode;

  @override
  State<ShopCodeRedirectPage> createState() => _ShopCodeRedirectPageState();
}

class _ShopCodeRedirectPageState extends State<ShopCodeRedirectPage> {
  late final Future<Map<String, dynamic>?> _shop = _loadAndRememberShop();
  String get shopCode => widget.shopCode;

  Future<Map<String, dynamic>?> _loadAndRememberShop() async {
    final shop = await ShopService.instance.getShopByCode(shopCode);

    if (shop == null) return null;

    final shopId = shop['shopId']?.toString() ?? shopCode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_customer_shop_id', shopId);
    await prefs.setString('last_customer_shop_code', shopCode);

    return shop;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _shop,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final shop = snapshot.data;

        if (shop == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('找不到店家')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error is FirebaseFunctionsException
                      ? ((snapshot.error as FirebaseFunctionsException)
                                .message ??
                            '無法查詢店家')
                      : snapshot.hasError
                      ? '無法連線，請稍後重新掃描或輸入搜尋碼'
                      : '搜尋碼不存在或已失效',
                ),
              ),
            ),
          );
        }

        final shopId = shop['shopId']?.toString() ?? shopCode;

        return ShopPublicPage(shopId: shopId);
      },
    );
  }
}
