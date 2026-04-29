// lib/features/shop/pages/shop_public_page.dart
// 👤 前台店家頁（完整版🔥 + Drawer版 + 修正錯誤）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/core/widgets/app_drawer.dart';



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
          drawer: AppDrawer(shopId: widget.shopId),

          appBar: AppBar(
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
            title: Text(
              shop['name'] ?? '店家',
              style: const TextStyle(fontWeight: FontWeight.bold),
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

                    /// 我要預約（大）
                    _buildMenuButton(
                      icon: Icons.calendar_month,
                      title: '我要預約',
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

                    const SizedBox(height: 12),

                    /// 其他按鈕
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.0,
                      children: [

                        _buildMenuButton(
                          icon: Icons.home,
                          title: '環境介紹',
                          onTap: () {},
                        ),

                        _buildMenuButton(
                          icon: Icons.bed,
                          title: '房間介紹',
                          onTap: () {},
                        ),

                        _buildMenuButton(
  icon: Icons.info,
  title: '入住須知',
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