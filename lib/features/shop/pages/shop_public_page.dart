// lib/features/shop/pages/shop_public_page.dart
// 👤 前台店家家頁（完整版🔥 + Drawer版 + 修正錯誤）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/core/widgets/app_drawer.dart';
import 'package:petnest_saas/features/shop/widgets/shop_template_feature_card.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_intro_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';



class ShopPublicPage extends StatefulWidget {
  const ShopPublicPage({
    super.key,
    required this.shopId,
  });

  final String shopId;


  @override
  State<ShopPublicPage> createState() => _ShopPublicPageState();
}
class _ShopPublicPageState extends State<ShopPublicPage> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isPageChanging = false;

@override
void initState() {
  super.initState();
  _pageController = PageController(initialPage: 0);
}

Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('讀取失敗：${snapshot.error}')),
          );
        }

        final shop = snapshot.data;
if (shop == null) {
  return const Scaffold(
    body: Center(child: Text('找不到店家')),
  );
}

/// 🔥 店家已開啟的模組 / 服務類型
final List enabledModules = shop['enabledModules'] ?? [];
final List serviceTypes = shop['serviceTypes'] ?? [];

/// 🔥 模板判斷：之後首頁功能卡會依照這些顯示
final bool hasBooking = enabledModules.contains('booking');
final bool hasCatHotel = serviceTypes.contains('cat_hotel');
final bool hasDogHotel = serviceTypes.contains('dog_hotel');
final bool hasGrooming = serviceTypes.contains('grooming');
final bool hasHospital = serviceTypes.contains('hospital');
final bool hasShop = serviceTypes.contains('shop');

/// 🔥 目前主模板：先固定貓咪旅館
/// 未來可改成從店家設定讀取 primaryService
final String primaryService = 'cat_hotel';

/// 🔥 未來多模板入口判斷
/// 目前先保留，不顯示其他模板
final bool showServiceEntrance = serviceTypes.length > 1;

        /// 🔥 Banner（支援圖片 + 連結）
final List<dynamic> rawBanners = shop['banners'] ?? [];

final List<Map<String, String>> banners =
    rawBanners.where((e) {
      return (e['isActive'] ?? true) == true;
    }).map<Map<String, String>>((e) {
      return {
        'image': (e['imageUrl'] ?? '').toString(),
        'link': (e['linkUrl'] ?? '').toString(),
      };
    }).toList();

/// 舊資料兼容（如果還沒升級）
if (banners.isEmpty &&
    (shop['coverUrl'] ?? '').toString().isNotEmpty) {
  banners.add({
    'image': shop['coverUrl'],
    'link': '',
  });
}


        /// 🔥 正確：只保留一個 Scaffold
        return Scaffold(
  backgroundColor: const Color(0xFFFFFCF7),
  drawer: AppDrawer(shopId: widget.shopId),

  appBar: AppBar(
    backgroundColor: const Color(0xFFFFFCF7),
    elevation: 0,
    surfaceTintColor: Colors.transparent,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
            title: Column(
  children: [
    Text(
      shop['name'] ?? '店家',
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Color(0xFF3A2A1A),
      ),
    ),
    const SizedBox(height: 4),
    const Text(
      '🐾 讓每一隻貓咪都有溫暖的家 🐾',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Color(0xFF9A7B55),
      ),
    ),
  ],
),
            centerTitle: true,
          ),

          body: Column(
            children: [

              /// 🔥 上半部
Expanded(
  child: ListView(
    padding: const EdgeInsets.all(16),
    children: [

     /// 🔥 Banner（Stack版本，100%正常）
if (banners.isNotEmpty)
  SizedBox(
    height: 260,
    child: Stack(
      children: [

        /// 圖片滑動
        PageView.builder(
          controller: _pageController,
          physics: const PageScrollPhysics(),
          itemCount: banners.length,
          onPageChanged: (index) {
  _currentIndex = index;
},
          itemBuilder: (context, index) {
            final banner = banners[index];

            return GestureDetector(
              onTap: () {
                final link = banner['link'] ?? '';
                if (link.isNotEmpty) {
                  _openUrl(link);
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Image.network(
                      banner['image']!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        /// 🔥 圓點（在圖片裡面）
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (index) {
              return GestureDetector(
                onTap: () {
  if (_pageController.hasClients) {
    _pageController.jumpToPage(index);
  }
},
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: _currentIndex == index ? 12 : 8,
                  height: _currentIndex == index ? 12 : 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? Colors.white
                        : Colors.white54,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    ),
  ),

if (banners.isNotEmpty) const SizedBox(height: 20),



                    /// 🔥 貓咪旅館主服務卡
_buildMainServiceButton(
  icon: Icons.pets,
  title: '貓咪旅館',
  subtitle: '安心住宿・房型介紹・入住須知',
  actionText: '我要預約住宿',
  onTap: () async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('請先登入')),
    );
    return;
  }

  final hasAccepted =
      await ShopService.instance.hasAcceptedPolicy(
    shopId: widget.shopId,
    userId: user.uid,
  );

  if (!hasAccepted) {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopPolicyViewPage(
  shopId: widget.shopId,
  readOnly: false, 
),
      ),
    );

    if (result != true) return;
  }

  /// ✅ 通過才進預約
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ShopBookingPage(shopId: widget.shopId),
    ),
  );
},
                    ),

                    const SizedBox(height: 22),

ShopSectionTitle(
  icon: Icons.pets,
  title: '住宿服務',
),

const SizedBox(height: 12),

/// 貓咪旅館功能
GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.0,
                      children: [

                        ShopTemplateFeatureCard(
  icon: Icons.home,
  title: '環境介紹',
  subtitle: '住宿空間・安心設備',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopEnvironmentPage(
          shopId: widget.shopId,
        ),
      ),
    );
  },
),

ShopTemplateFeatureCard(
  icon: Icons.bed,
  title: '房間介紹',
  subtitle: '多種房型・專屬選擇',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopRoomIntroPage(
          shopId: widget.shopId,
        ),
      ),
    );
  },
),
                    ShopTemplateFeatureCard(
  icon: Icons.info,
  title: '入住須知',
  subtitle: '入住條件・注意事項',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopPolicyViewPage(
          shopId: widget.shopId,
          readOnly: true,
        ),
      ),
    );
  },
),
                      ],
                    ),

const SizedBox(height: 24),

ShopSectionTitle(
  icon: Icons.storefront,
  title: '了解我們',
),

const SizedBox(height: 12),

GridView.count(
  crossAxisCount: 2,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  childAspectRatio: 2.0,
  children: [

    _buildMenuButton(
      icon: Icons.map,
      title: '關於我們',
      onTap: () {},
    ),

    _buildMenuButton(
      icon: Icons.star,
      title: '評價',
      onTap: () {},
    ),
  ],
),

const SizedBox(height: 80),
                  ],
                ),
              ),

              /// 🔥 固定底部
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      '店家資訊',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    _buildInfoRow(Icons.access_time, '營業時間', shop['businessHours'] ?? ''),
                    _buildInfoRow(Icons.phone, '電話', shop['phone'] ?? ''),
                    _buildInfoRow(Icons.location_on, '地址', shop['address'] ?? ''),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        if ((shop['licenseNumber'] ?? '').toString().isNotEmpty)
                          Expanded(
                            child: _buildInfoRow(Icons.pets, '字號', shop['licenseNumber'] ?? ''),
                          ),

                        if (shop['showTaxId'] == true &&
                            (shop['taxId'] ?? '').toString().isNotEmpty)
                          Expanded(
                            child: _buildInfoRow(Icons.receipt, '統編', shop['taxId'] ?? ''),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSocialButton(icon: Icons.camera_alt, url: shop['igUrl']),
                        _buildSocialButton(icon: Icons.facebook, url: shop['fbUrl']),
                        _buildSocialButton(icon: Icons.chat, url: shop['lineUrl']),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

Widget ShopSectionTitle({
  required IconData icon,
  required String title,
  String actionText = '',
  VoidCallback? onTap,
}) {
  return Row(
    children: [
      Icon(
        icon,
        size: 20,
        color: const Color(0xFFFF8A2A),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Color(0xFF3A2A1A),
        ),
      ),
      const Spacer(),

      if (actionText.isNotEmpty)
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionText,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9A7B55),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ],
  );
}

Widget _buildMainServiceButton({
  required IconData icon,
  required String title,
  required String subtitle,
  required String actionText,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1DD),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD7A8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD59E),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 30,
              color: Color(0xFF6B3F16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3A2A1A),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A6A45),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  actionText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB86B18),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 18,
            color: Color(0xFFB86B18),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),

        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$title：', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String? url,
  }) {
    final isActive = (url ?? '').isNotEmpty;

    return GestureDetector(
      onTap: isActive ? () => _openUrl(url!) : null,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 28,
          color: isActive ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }
}