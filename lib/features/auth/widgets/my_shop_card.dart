// 檔案名稱：lib/features/auth/widgets/my_shop_card.dart
// 功能說明：顯示登入者可管理的店家卡片，包含店家資訊與首頁統計資料
// 🏪 我的店家卡片

import 'package:flutter/material.dart';

class MyShopCard extends StatelessWidget {
  const MyShopCard({
    super.key,
    required this.shop,
    required this.onTap,
    required this.child,
  });

  final Map<String, dynamic> shop;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
