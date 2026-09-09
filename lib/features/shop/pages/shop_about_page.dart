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

class ShopAboutPage extends StatefulWidget {
  const ShopAboutPage({
    super.key,
    required this.shopId,
    required this.theme,
    this.previewTitle,
    this.previewDescription,
    this.previewMessage,
    this.previewImageUrl,
    this.previewFrame,
    this.scrollToContact = false,
  });

  final String shopId;
  final HomeThemeModel theme;
  final String? previewTitle;
  final String? previewDescription;
  final String? previewMessage;
  final String? previewImageUrl;
  final AboutCoverFrameSetting? previewFrame;
  final bool scrollToContact;

  @override
  State<ShopAboutPage> createState() => _ShopAboutPageState();
}

class _ShopAboutPageState extends State<ShopAboutPage> {
  final GlobalKey _contactKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.scrollToContact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext? target = _contactKey.currentContext;
        if (target == null) {
          return;
        }
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.theme.cardColor,
        foregroundColor: widget.theme.textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          '關於我們',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: widget.theme.textColor,
          ),
        ),
      ),
      body: ListView(
        children: [
          AboutHeroSection(
            shopId: widget.shopId,
            theme: widget.theme,
            previewTitle: widget.previewTitle,
            previewDescription: widget.previewDescription,
            previewImageUrl: widget.previewImageUrl,
            previewFrame: widget.previewFrame,
          ),
          const SizedBox(height: 28),
          AboutPhilosophySection(theme: widget.theme),
          const SizedBox(height: 30),
          AboutMessageSection(
            shopId: widget.shopId,
            theme: widget.theme,
            previewMessage: widget.previewMessage,
          ),
          const SizedBox(height: 30),
          KeyedSubtree(
            key: _contactKey,
            child: AboutShopInfoSection(
              shopId: widget.shopId,
              theme: widget.theme,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
