// 檔案名稱：lib/features/shop/pages/shop_about_page.dart
// 功能說明：顯示店家品牌介紹、理念、店家訊息與聯絡資訊
// 🐾 前台關於我們頁
// 並依照 Classic / Modern 首頁套用共用主題

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_cover_frame_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_hero_section.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_message_section.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_philosophy_section.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_shop_info_section.dart';

class ShopAboutPage extends StatelessWidget {
  const ShopAboutPage({
    super.key,
    required this.shopId,
    required this.theme,
    this.previewTitle,
    this.previewDescription,
    this.previewMessage,
    this.previewImageUrl,
    this.previewFrame,
  });

  final String shopId;
  final HomeThemeModel theme;
  final String? previewTitle;
  final String? previewDescription;
  final String? previewMessage;
  final String? previewImageUrl;
  final AboutCoverFrameSetting? previewFrame;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          '關於我們',
          style: TextStyle(fontWeight: FontWeight.w900, color: theme.textColor),
        ),
      ),
      body: ListView(
        children: [
          AboutHeroSection(
            shopId: shopId,
            theme: theme,
            previewTitle: previewTitle,
            previewDescription: previewDescription,
            previewImageUrl: previewImageUrl,
            previewFrame: previewFrame,
          ),
          const SizedBox(height: 28),
          AboutPhilosophySection(theme: theme),
          const SizedBox(height: 30),
          AboutMessageSection(
            shopId: shopId,
            theme: theme,
            previewMessage: previewMessage,
          ),
          const SizedBox(height: 30),
          AboutShopInfoSection(shopId: shopId, theme: theme),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
