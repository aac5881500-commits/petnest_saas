// 檔案名稱：lib/features/auth/widgets/my_shop_card.dart
// 功能說明：顯示登入者可管理的店家卡片，點擊後進入該店家。
// 🏪 我的店家卡片

import 'package:flutter/material.dart';

class MyShopCard extends StatelessWidget {
  const MyShopCard({super.key, required this.child, this.onTap});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget body = onTap == null
        ? child
        : InkWell(onTap: onTap, child: child);
    return Material(
      color: colors.surface,
      elevation: 1,
      shadowColor: colors.shadow.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }
}
