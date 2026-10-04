// 檔案名稱：lib/features/auth/widgets/my_shop_badges.dart
// 功能說明：營業、角色、公開狀態使用同一套小型 chip。
// 🏷️ 我的店家標籤列

import 'package:flutter/material.dart';

class MyShopBadges extends StatelessWidget {
  const MyShopBadges({
    super.key,
    required this.role,
    required this.isPublic,
    required this.isOpenNow,
  });

  final String role;
  final bool isPublic;
  final bool isOpenNow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool dark = colors.brightness == Brightness.dark;
    final Color positive = dark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32);
    final Color neutral = colors.onSurfaceVariant;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _Badge(
          text: isOpenNow ? '營業中' : '休息中',
          icon: Icons.circle,
          foreground: isOpenNow ? positive : neutral,
          background: isOpenNow
              ? positive.withValues(alpha: 0.12)
              : colors.surfaceContainerHighest,
        ),
        _Badge(
          text: role,
          icon: Icons.badge_outlined,
          foreground: colors.primary,
          background: colors.primaryContainer.withValues(alpha: 0.55),
        ),
        _Badge(
          text: isPublic ? '公開中' : '未公開',
          icon: Icons.visibility_outlined,
          foreground: isPublic ? positive : neutral,
          background: isPublic
              ? positive.withValues(alpha: 0.12)
              : colors.surfaceContainerHighest,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String text;
  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1,
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
