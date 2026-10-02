import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';
import 'package:petnest_saas/features/booking/pages/my_reviews_page.dart';
import 'package:petnest_saas/features/member/pages/member_page.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_customer_chat_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_entry_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_faq_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_intro_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/my_store_orders_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_home_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';
import 'package:petnest_saas/core/services/auth_service.dart';
import 'package:petnest_saas/features/shop/navigation/shop_main_tab_route.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_main_tab_frame.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_embedded_scope.dart';

class FrontendNavigationLaunch {
  const FrontendNavigationLaunch({
    required this.shopId,
    required this.shop,
    required this.theme,
    this.previewOnly = false,
    this.isEmbeddedAdminPreview = false,
    this.shellTabs = false,
    this.navigation,
    this.shopState,
    this.canOpenAdmin = false,
    this.onPreviewSelect,
    this.onScrollHomeToTop,
    this.onReturnedToHome,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final HomeThemeModel theme;
  final bool previewOnly;
  final bool isEmbeddedAdminPreview;
  final bool shellTabs;
  final FrontendNavigationConfig? navigation;
  final FrontendNavShopState? shopState;
  final bool canOpenAdmin;
  final ValueChanged<String>? onPreviewSelect;
  final VoidCallback? onScrollHomeToTop;
  final VoidCallback? onReturnedToHome;

  Future<void> open(BuildContext context, FrontendNavigationItem item) async {
    if (previewOnly &&
        !(item.action == FrontendNavAction.admin && !isEmbeddedAdminPreview)) {
      onPreviewSelect?.call(item.id);
      final ScaffoldState? scaffold = Scaffold.maybeOf(context);
      if (scaffold != null && scaffold.isDrawerOpen) {
        Navigator.of(context).pop();
      }
      return;
    }
    switch (item.action) {
      case FrontendNavAction.home:
        onScrollHomeToTop?.call();
        _closeDrawer(context);
        return;
      case FrontendNavAction.platform:
        _goToPlatform(context);
        return;
      case FrontendNavAction.admin:
        if (isEmbeddedAdminPreview) {
          return;
        }
        _closeDrawer(context);
        if (ShopDashboardEmbeddedScope.tryExitToDashboard(context)) {
          return;
        }
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => ShopDashboardPage(shopId: shopId),
          ),
          (Route<dynamic> route) => false,
        );
        return;
      case FrontendNavAction.logout:
        await _logout(context);
        return;
      case FrontendNavAction.shopInfo:
        _closeDrawer(context);
        if (!context.mounted) {
          return;
        }
        ModernShopFooter(
          shopId: shopId,
          shop: shop,
          shopName: (shop['name'] ?? '店家').toString(),
          primaryColor: theme.primaryColor,
          darkTextColor: theme.textColor,
          secondaryTextColor: theme.secondaryTextColor,
          cardColor: theme.cardColor,
          borderColor: theme.cardBorderColor,
          isPreview: false,
        ).showShopInfoSheet(context);
        return;
      case FrontendNavAction.booking:
      case FrontendNavAction.rooms:
      case FrontendNavAction.store:
      case FrontendNavAction.announcements:
      case FrontendNavAction.orders:
      case FrontendNavAction.member:
      case FrontendNavAction.reviews:
      case FrontendNavAction.policy:
      case FrontendNavAction.about:
      case FrontendNavAction.faq:
      case FrontendNavAction.environment:
      case FrontendNavAction.chat:
      case FrontendNavAction.storeOrders:
        _closeDrawer(context);
        if (!context.mounted) {
          return;
        }
        final User? user = FirebaseAuth.instance.currentUser;
        if (item.requiresLogin && user == null) {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => LoginPage(redirectShopId: shopId),
            ),
          );
          return;
        }
        if (shellTabs && navigation != null && shopState != null) {
          await _openMainTab(context, item);
          return;
        }
        await Navigator.push(context, _routeFor(item));
    }
  }

  Future<void> _openMainTab(
    BuildContext context,
    FrontendNavigationItem item,
  ) async {
    final NavigatorState navigator = Navigator.of(context);
    if (item.action == FrontendNavAction.home) {
      ShopMainTabRoute.popToShopHome(navigator);
      onScrollHomeToTop?.call();
      return;
    }
    final String name = ShopMainTabRoute.nameFor(item.id);
    final String? current = ModalRoute.of(context)?.settings.name;
    if (current == name) {
      return;
    }
    final MaterialPageRoute<void> route = MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (BuildContext routeContext) {
        return ShopMainTabFrame(
          shopId: shopId,
          selectedId: item.id,
          slots: navigation!.resolvedBottomSlots(shopState!),
          navigation: navigation!,
          shop: shop,
          theme: theme,
          canOpenAdmin: canOpenAdmin,
          previewOnly: previewOnly,
          isEmbeddedAdminPreview: isEmbeddedAdminPreview,
          onSelect: (FrontendNavigationItem next) {
            open(routeContext, next);
          },
          onPlatform: () => open(
            routeContext,
            FrontendNavigationRegistry.find('platform')!,
          ),
          onAdmin: () => open(
            routeContext,
            FrontendNavigationRegistry.find('admin')!,
          ),
          child: _pageFor(item),
        );
      },
    );
    if (current != null && current.startsWith(ShopMainTabRoute.prefix)) {
      await navigator.pushReplacement(route);
      return;
    }
    await navigator.push(route);
    onReturnedToHome?.call();
  }

  Future<void> _logout(BuildContext context) async {
    _closeDrawer(context);
    if (!context.mounted) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('登出'),
          content: const Text('要登出目前的帳號嗎？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('登出'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await AuthService.instance.logout();
  }

  MaterialPageRoute<void> _routeFor(FrontendNavigationItem item) {
    return MaterialPageRoute<void>(builder: (_) => _pageFor(item));
  }

  Widget _pageFor(FrontendNavigationItem item) {
    switch (item.action) {
      case FrontendNavAction.booking:
        return ShopBookingEntryPage(
          shopId: shopId,
          theme: theme,
          useModernDrawer: true,
        );
      case FrontendNavAction.rooms:
        return ShopRoomIntroPage(shopId: shopId, theme: theme);
      case FrontendNavAction.environment:
        return ShopEnvironmentPage(shopId: shopId, theme: theme);
      case FrontendNavAction.store:
        return StoreHomePage(shopId: shopId, shop: shop, theme: theme);
      case FrontendNavAction.announcements:
        return ShopAnnouncementPage(shopId: shopId);
      case FrontendNavAction.orders:
        return MyBookingsPage(returnShopId: shopId);
      case FrontendNavAction.member:
        return MemberPage(
          shopId: shopId,
          shopName: (shop['name'] ?? '').toString(),
          theme: theme,
        );
      case FrontendNavAction.reviews:
        return const MyReviewsPage();
      case FrontendNavAction.policy:
        return ShopPolicyViewPage(shopId: shopId, theme: theme, readOnly: true);
      case FrontendNavAction.about:
        return ShopAboutPage(shopId: shopId, theme: theme);
      case FrontendNavAction.faq:
        return ShopFaqPage(shopId: shopId);
      case FrontendNavAction.chat:
        return ShopCustomerChatPage(
          shopId: shopId,
          shopName: (shop['name'] ?? '').toString(),
          shopLogoUrl: (shop['logoUrl'] ?? '').toString(),
        );
      case FrontendNavAction.storeOrders:
        return MyStoreOrdersPage(shopId: shopId, theme: theme);
      case FrontendNavAction.home:
      case FrontendNavAction.shopInfo:
      case FrontendNavAction.platform:
      case FrontendNavAction.admin:
      case FrontendNavAction.logout:
        return ShopPublicPage(shopId: shopId);
    }
  }

  void _closeDrawer(BuildContext context) {
    final ScaffoldState? scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
  }

  void _goToPlatform(BuildContext context) {
    final NavigatorState root = Navigator.of(context, rootNavigator: true);
    _closeDrawer(context);
    root.pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false);
  }
}
