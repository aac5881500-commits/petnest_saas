// 檔案名稱：lib/core/services/shop_contact_shortcut_service.dart
// 功能說明：執行店家首頁已啟用的浮動聯絡快捷；沒有時導向關於我們聯絡資訊

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_customer_chat_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopContactShortcutService {
  ShopContactShortcutService._();

  static final ShopContactShortcutService instance =
      ShopContactShortcutService._();

  Future<void> contactShop({
    required BuildContext context,
    required String shopId,
  }) async {
    final Map<String, dynamic>? shop = await ShopService.instance.getShop(
      shopId,
    );
    if (!context.mounted) {
      return;
    }
    final Map<String, dynamic> data = shop ?? <String, dynamic>{};
    if (ShopChatService.isFloatingEnabled(data)) {
      final String type = ShopChatService.resolvedFloatingType(data);
      if (type == ShopChatService.floatingTypePetnestChat) {
        await _openChat(context, shopId);
        return;
      }
      final String? url = _urlForType(data, type);
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return;
      }
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopAboutPage(
          shopId: shopId,
          theme: HomeBannerService.instance.themeFromShop(data),
          scrollToContact: true,
        ),
      ),
    );
  }

  String? _urlForType(Map<String, dynamic> shop, String type) {
    switch (type) {
      case ShopChatService.floatingTypePhone:
        final String phone = (shop['phone'] ?? '').toString().trim();
        return phone.isEmpty ? null : 'tel:$phone';
      case ShopChatService.floatingTypeLine:
        final String line = (shop['lineUrl'] ?? '').toString().trim();
        return line.isEmpty ? null : line;
      case ShopChatService.floatingTypeFacebook:
        final String fb = (shop['fbUrl'] ?? '').toString().trim();
        return fb.isEmpty ? null : fb;
      case ShopChatService.floatingTypeInstagram:
        final String ig = (shop['igUrl'] ?? '').toString().trim();
        return ig.isEmpty ? null : ig;
      default:
        return null;
    }
  }

  Future<void> _openChat(BuildContext context, String shopId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopCustomerChatPage(shopId: shopId),
      ),
    );
  }
}
