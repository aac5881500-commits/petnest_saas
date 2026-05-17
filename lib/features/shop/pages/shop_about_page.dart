// lib/features/shop/pages/shop_about_page.dart
// 🐾 前台關於我們頁

import 'package:flutter/material.dart';

import 'package:petnest_saas/features/shop/widgets/about/about_hero_section.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_message_section.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_philosophy_section.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_shop_info_section.dart';

class ShopAboutPage extends StatelessWidget {
  const ShopAboutPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFCF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          '關於我們',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF3A2A1A),
          ),
        ),
      ),
      body: ListView(
        children: [
          AboutHeroSection(
  shopId: shopId,
),

          SizedBox(height: 28),

          AboutPhilosophySection(),

          SizedBox(height: 30),

          AboutMessageSection(
  shopId: shopId,
),

          SizedBox(height: 30),

          AboutShopInfoSection(
  shopId: shopId,
),

          SizedBox(height: 40),
        ],
      ),
    );
  }
}