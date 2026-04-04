// lib/features/shop/pages/shop_public_page.dart
// 👤 前台店家頁（完整版🔥 + Drawer版 + 修正錯誤）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopPublicPage extends StatelessWidget {
  const ShopPublicPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(shopId),
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

        final List<dynamic> rawCovers = shop['coverUrls'] ?? [];
        final List<String> coverUrls =
            rawCovers.map((e) => e.toString()).toList();

        if (coverUrls.isEmpty &&
            (shop['coverUrl'] ?? '').toString().isNotEmpty) {
          coverUrls.add(shop['coverUrl']);
        }

        /// 🔥 正確：只保留一個 Scaffold
        return Scaffold(
          drawer: _buildDrawer(context),

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

                    /// Banner
                    if (coverUrls.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 260,
                          child: PageView.builder(
                            itemCount: coverUrls.length,
                            itemBuilder: (context, index) {
                              return Image.network(
                                coverUrls[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                              );
                            },
                          ),
                        ),
                      ),

                    if (coverUrls.isNotEmpty) const SizedBox(height: 20),

                    /// 我要預約（大）
                    _buildMenuButton(
                      icon: Icons.calendar_month,
                      title: '我要預約',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ShopBookingPage(shopId: shopId),
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
                          onTap: () {},
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

  /// Drawer
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [

            const ListTile(
              title: Text('選單', style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('回首頁'),
              onTap: () => Navigator.pop(context),
            ),

            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('回平台'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('回後台'),
              onTap: () {},
            ),

            const Divider(),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('快速功能', style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('我要預約'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopBookingPage(shopId: shopId),
                  ),
                );
              },
            ),

            ListTile(leading: const Icon(Icons.home), title: const Text('環境介紹')),
            ListTile(leading: const Icon(Icons.bed), title: const Text('房間介紹')),
            ListTile(leading: const Icon(Icons.info), title: const Text('入住須知')),
            ListTile(leading: const Icon(Icons.map), title: const Text('關於我們')),
            ListTile(leading: const Icon(Icons.star), title: const Text('評價')),

            const Divider(),

            ListTile(leading: const Icon(Icons.person), title: const Text('會員')),
            ListTile(leading: const Icon(Icons.settings), title: const Text('功能設定')),

            const Divider(),

            ListTile(leading: const Icon(Icons.report), title: const Text('客戶申訴')),
            ListTile(leading: const Icon(Icons.bug_report), title: const Text('BUG回饋')),
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