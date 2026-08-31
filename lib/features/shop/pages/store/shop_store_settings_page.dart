// lib/features/shop/pages/store/shop_store_settings_page.dart
// 🛒 賣場設定首頁：分區進入，不再一頁滑到底。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_settings_sections.dart';

class ShopStoreSettingsPage extends StatelessWidget {
  const ShopStoreSettingsPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        const Text(
          '商城設定',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '商城頁面的所有設定都在這裡。旅館首頁的「寵物賣場入口卡片」請到前台外觀設定。',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        _tile(
          context,
          icon: Icons.storefront_outlined,
          title: '商城基本設定',
          subtitle: '啟用、名稱、副標',
          page: StoreSettingsBasicPage(
            shopId: shopId,
            canManage: canManage,
          ),
        ),
        _tile(
          context,
          icon: Icons.home_outlined,
          title: '商城首頁',
          subtitle: '公告、區塊開關、區塊名稱',
          page: StoreSettingsHomePage(
            shopId: shopId,
            canManage: canManage,
          ),
        ),
        _tile(
          context,
          icon: Icons.image_outlined,
          title: '活動海報',
          subtitle: '輪播、新增與編輯海報',
          page: StoreSettingsBannersPage(
            shopId: shopId,
            canManage: canManage,
          ),
        ),
        _tile(
          context,
          icon: Icons.inventory_2_outlined,
          title: '商品顯示',
          subtitle: '缺貨、庫存剩餘、精選數量',
          page: StoreSettingsProductsPage(
            shopId: shopId,
            canManage: canManage,
          ),
        ),
        _tile(
          context,
          icon: Icons.palette_outlined,
          title: '商城外觀',
          subtitle: '背景、商品卡、強調色、按鈕色',
          page: StoreSettingsAppearancePage(
            shopId: shopId,
            canManage: canManage,
          ),
        ),
        _tile(
          context,
          icon: Icons.receipt_long_outlined,
          title: '訂單設定',
          subtitle: '接單、備註、取消規則',
          page: StoreSettingsOrdersPage(
            shopId: shopId,
            canManage: canManage,
          ),
        ),
        _tile(
          context,
          icon: Icons.payments_outlined,
          title: '付款',
          subtitle: '沿用店家金流設定',
          page: StoreSettingsPaymentPage(shopId: shopId),
        ),
        _tile(
          context,
          icon: Icons.local_shipping_outlined,
          title: '取貨 / 配送',
          subtitle: '店內取貨說明',
          page: StoreSettingsPickupPage(
            shopId: shopId,
            canManage: canManage,
          ),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => page),
          );
        },
      ),
    );
  }
}
