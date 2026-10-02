import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_bottom_navigation.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_menu_button.dart';

/// 底部導覽主要分頁的外框。底欄與店家選單跟首頁用同一套元件。
class ShopMainTabFrame extends StatelessWidget {
  const ShopMainTabFrame({
    super.key,
    required this.child,
    required this.selectedId,
    required this.slots,
    required this.navigation,
    required this.shop,
    required this.theme,
    required this.shopId,
    required this.canOpenAdmin,
    required this.previewOnly,
    required this.isEmbeddedAdminPreview,
    required this.onSelect,
    required this.onPlatform,
    required this.onAdmin,
  });

  final Widget child;
  final String selectedId;
  final List<FrontendNavigationItem?> slots;
  final FrontendNavigationConfig navigation;
  final Map<String, dynamic> shop;
  final HomeThemeModel theme;
  final String shopId;
  final bool canOpenAdmin;
  final bool previewOnly;
  final bool isEmbeddedAdminPreview;
  final ValueChanged<FrontendNavigationItem> onSelect;
  final VoidCallback onPlatform;
  final VoidCallback onAdmin;

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    final double clearance = ModernBottomNavigation.contentClearance(
      navigation.bottomAppearance,
      safeBottom,
    );
    final String shopName = (shop['name'] ?? '店家').toString();
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool allowNavigation = !isEmbeddedAdminPreview && !previewOnly;
    return Scaffold(
      extendBody: true,
      backgroundColor: theme.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(bottom: clearance),
            child: child,
          ),
          if (canOpenAdmin)
            ShopMenuButton(
              shopId: shopId,
              userId: userId,
              shopName: shopName,
              logoUrl: (shop['logoUrl'] ?? '').toString(),
              theme: theme,
              surface: navigation.bottomSurface,
              bottomBarHeight: ModernBottomNavigation.slotHeight(
                navigation.bottomAppearance,
                safeBottom,
              ),
              visible: true,
              persistPosition: allowNavigation && userId.isNotEmpty,
              allowNavigation: allowNavigation,
              onPlatform: onPlatform,
              onAdmin: onAdmin,
            ),
        ],
      ),
      bottomNavigationBar: ModernBottomNavigation(
        slots: slots,
        theme: theme,
        selectedId: selectedId,
        appearance: navigation.bottomAppearance,
        surface: navigation.bottomSurface,
        onSelect: onSelect,
      ),
    );
  }
}
