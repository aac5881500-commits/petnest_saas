// 檔案名稱：lib/features/shop/widgets/modern_home/home_shortcut_catalog.dart
// 功能說明：右上角與設定選單共用的快捷功能名稱與圖示。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_quick_action_setting.dart';

class HomeShortcutOption {
  const HomeShortcutOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

class HomeShortcutCatalog {
  const HomeShortcutCatalog._();

  static const List<HomeShortcutOption> options = <HomeShortcutOption>[
    HomeShortcutOption(
      id: HomeQuickActionIds.cart,
      label: '購物車',
      icon: Icons.shopping_cart_outlined,
    ),
    HomeShortcutOption(
      id: HomeQuickActionIds.chat,
      label: 'PetNest 店家聊天',
      icon: Icons.chat_bubble_outline,
    ),
    HomeShortcutOption(
      id: HomeQuickActionIds.phone,
      label: '電話',
      icon: Icons.phone_outlined,
    ),
    HomeShortcutOption(
      id: HomeQuickActionIds.line,
      label: 'LINE',
      icon: Icons.chat_outlined,
    ),
    HomeShortcutOption(
      id: HomeQuickActionIds.facebook,
      label: 'Facebook',
      icon: Icons.facebook_outlined,
    ),
    HomeShortcutOption(
      id: HomeQuickActionIds.instagram,
      label: 'Instagram',
      icon: Icons.camera_alt_outlined,
    ),
    HomeShortcutOption(
      id: HomeQuickActionIds.bookings,
      label: '我的預約',
      icon: Icons.event_available_outlined,
    ),
    HomeShortcutOption(
      id: HomeQuickActionIds.promotions,
      label: '優惠活動',
      icon: Icons.card_giftcard_outlined,
    ),
    HomeShortcutOption(
      id: HomeQuickActionIds.member,
      label: '會員中心',
      icon: Icons.person_outline,
    ),
    HomeShortcutOption(
      id: HomeQuickActionIds.faq,
      label: '常見問題',
      icon: Icons.help_outline,
    ),
  ];

  static HomeShortcutOption? find(String id) {
    for (final HomeShortcutOption option in options) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }
}
