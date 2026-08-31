// lib/features/shop/pages/store/shop_store_promotion_type_page.dart
// 🛒 先選活動類型，再進該類型專用表單

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_promotion_form_page.dart';

class ShopStorePromotionTypePage extends StatelessWidget {
  const ShopStorePromotionTypePage({super.key, required this.shopId});

  final String shopId;

  static const List<String> _types = <String>[
    StorePromotionTypes.bundle,
    StorePromotionTypes.quantity,
    StorePromotionTypes.category,
    StorePromotionTypes.amount,
  ];

  static const Map<String, IconData> _icons = <String, IconData>{
    StorePromotionTypes.bundle: Icons.inventory_2_outlined,
    StorePromotionTypes.quantity: Icons.layers_outlined,
    StorePromotionTypes.category: Icons.category_outlined,
    StorePromotionTypes.amount: Icons.payments_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(title: const Text('選擇活動類型')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          const Text(
            '跨商品 / 跨分類 / 購物車活動',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '商品自己的特價、打折、買 X 送 Y 請到商品編輯頁設定。',
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 16),
          ..._types.map((String type) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ShopStorePromotionFormPage(
                          shopId: shopId,
                          initialType: type,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          _icons[type] ?? Icons.local_offer_outlined,
                          size: 28,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                StorePromotionTypes.label(type),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                StorePromotionTypes.description(type),
                                style: TextStyle(
                                  height: 1.4,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
