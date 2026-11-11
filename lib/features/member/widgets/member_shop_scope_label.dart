import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class MemberShopScopeLabel extends StatelessWidget {
  const MemberShopScopeLabel({
    super.key,
    required this.shopId,
    this.shopName = '',
    this.note = '權益僅限此店使用',
  });
  final String shopId, shopName, note;
  @override
  Widget build(BuildContext context) {
    Widget label(String name) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        '所屬店家：$name\n$note',
        style: const TextStyle(fontSize: 12, height: 1.5),
      ),
    );
    if (shopName.trim().isNotEmpty) return label(shopName.trim());
    if (shopId.trim().isEmpty) return label('尚未選擇店家');
    return StreamBuilder<Map<String, dynamic>?>(
      key: ValueKey(shopId),
      stream: ShopService.instance.streamShop(shopId),
      builder: (_, snapshot) {
        final name =
            (snapshot.data?['name'] ?? snapshot.data?['shopName'] ?? '')
                .toString()
                .trim();
        return label(
          name.isNotEmpty
              ? name
              : snapshot.hasError
              ? '店家資料暫時無法取得'
              : '店家資料載入中',
        );
      },
    );
  }
}
