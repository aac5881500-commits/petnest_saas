// lib/features/shop/pages/shop_public_page.dart
// 👤 前台店家家頁（完整版🔥 + Drawer版 + 修正錯誤）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/core/widgets/app_drawer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petnest_saas/features/shop/widgets/shop_template_feature_card.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_intro_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopPublicPage extends StatefulWidget {
  const ShopPublicPage({
    super.key,
    required this.shopId,
    this.platformPreview = false,
  });

  final String shopId;
  final bool platformPreview;
  @override
  State<ShopPublicPage> createState() => _ShopPublicPageState();
}

class _ShopPublicPageState extends State<ShopPublicPage> {
  late final PageController _pageController;
  int _currentIndex = 0;

  bool _showShopInfo = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;

    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) return;

    final uri = Uri.parse('tel:$cleanPhone');
    await launchUrl(uri);
  }

  Future<void> _openMap(String address) async {
    final cleanAddress = address.trim();
    if (cleanAddress.isEmpty) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(cleanAddress)}',
    );

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
          return Scaffold(body: Center(child: Text('讀取失敗：${snapshot.error}')));
        }

        final shop = snapshot.data;
        if (shop == null) {
          return const Scaffold(body: Center(child: Text('找不到店家')));
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

        final List<Map<String, String>> banners = rawBanners
            .where((e) {
              return (e['isActive'] ?? true) == true;
            })
            .map<Map<String, String>>((e) {
              return {'image': (e['imageUrl'] ?? '').toString()};
            })
            .toList();

        /// 舊資料兼容（如果還沒升級）
        if (banners.isEmpty && (shop['coverUrl'] ?? '').toString().isNotEmpty) {
          banners.add({'image': shop['coverUrl']});
        }

        /// 🔥 正確：只保留一個 Scaffold
        return Scaffold(
          backgroundColor: const Color(0xFFFFFCF7),
          drawer: AppDrawer(
            shopId: widget.shopId,
            platformPreview: widget.platformPreview,
          ),

          appBar: AppBar(
            backgroundColor: const Color(0xFFFFFCF7),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: widget.platformPreview
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: '返回店家管理',
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  )
                : Builder(
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
                        height: 160,
                        child: Stack(
                          children: [
                            /// 圖片滑動
                            PageView.builder(
                              controller: _pageController,
                              physics: const PageScrollPhysics(),
                              itemCount: banners.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                final banner = banners[index];

                                return ClipRRect(
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
                                );
                              },
                            ),

                            if (banners.length > 1)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_currentIndex + 1} / ${banners.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('請先登入')));
                          return;
                        }

                        final hasAccepted = await ShopService.instance
                            .hasAcceptedPolicy(
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

                    const SizedBox(height: 14),

                    _buildNoticePreviewCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ShopAnnouncementPage(shopId: widget.shopId),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    ShopSectionTitle(icon: Icons.pets, title: '住宿服務'),

                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.15,
                      children: [
                        ShopTemplateFeatureCard(
                          icon: Icons.home,
                          title: '環境介紹',
                          subtitle: '住宿空間・安心設備',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ShopEnvironmentPage(shopId: widget.shopId),
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
                                builder: (_) =>
                                    ShopRoomIntroPage(shopId: widget.shopId),
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

                        ShopTemplateFeatureCard(
                          icon: Icons.videocam,
                          title: '觀看攝影機',
                          subtitle: '即時查看毛孩狀況',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('攝影機功能尚未開放')),
                            );
                          },
                        ),

                        ShopTemplateFeatureCard(
                          icon: Icons.favorite,
                          title: '關於我們',
                          subtitle: '品牌理念・店家故事',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ShopAboutPage(shopId: widget.shopId),
                              ),
                            );
                          },
                        ),

                        ShopTemplateFeatureCard(
                          icon: Icons.card_giftcard,
                          title: '優惠活動',
                          subtitle: '限時優惠・活動方案',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('優惠活動尚未開放')),
                            );
                          },
                        ),

                        ShopTemplateFeatureCard(
                          icon: Icons.star,
                          title: '評價專區',
                          subtitle: '顧客評價・真實回饋',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('評價功能尚未開放')),
                            );
                          },
                        ),

                        ShopTemplateFeatureCard(
                          icon: Icons.help,
                          title: '常見問題',
                          subtitle: '常見疑問・快速解答',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('常見問題尚未開放')),
                            );
                          },
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
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showShopInfo = !_showShopInfo;
                        });
                      },
                      child: Row(
                        children: [
                          Text(
                            '店家資訊',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _showShopInfo
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    if (_showShopInfo) ...[
                      _buildInfoRow(
                        Icons.access_time,
                        '營業時間',
                        shop['businessHours'] ?? '',
                      ),
                      GestureDetector(
                        onTap: () => _callPhone(shop['phone'] ?? ''),
                        child: _buildInfoRow(
                          Icons.phone,
                          '電話',
                          shop['phone'] ?? '',
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openMap(
                          '${shop['city'] ?? ''}${shop['district'] ?? ''}${shop['address'] ?? ''}',
                        ),
                        child: _buildInfoRow(
                          Icons.location_on,
                          '地址',
                          '${shop['city'] ?? ''}${shop['district'] ?? ''}${shop['address'] ?? ''}',
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          if ((shop['licenseNumber'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Expanded(
                              child: _buildInfoRow(
                                Icons.pets,
                                '字號',
                                shop['licenseNumber'] ?? '',
                              ),
                            ),

                          if (shop['showTaxId'] == true &&
                              (shop['taxId'] ?? '').toString().isNotEmpty)
                            Expanded(
                              child: _buildInfoRow(
                                Icons.receipt,
                                '統編',
                                shop['taxId'] ?? '',
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSocialButton(
                          icon: FontAwesomeIcons.instagram,
                          url: shop['igUrl'],
                          activeColor: const Color(0xFFE1306C),
                        ),

                        _buildSocialButton(
                          icon: FontAwesomeIcons.facebook,
                          url: shop['fbUrl'],
                          activeColor: const Color(0xFF1877F2),
                        ),

                        _buildSocialButton(
                          icon: FontAwesomeIcons.line,
                          url: shop['lineUrl'],
                          activeColor: const Color(0xFF06C755),
                        ),
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
        Icon(icon, size: 20, color: const Color(0xFFFF8A2A)),
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

  Widget _buildNoticePreviewCard({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0E0CC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1DD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign,
                size: 22,
                color: Color(0xFFB86B18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shops')
                    .doc(widget.shopId)
                    .collection('announcements')
                    .where('isPublished', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  String previewText = '目前尚無公告';
                  bool isPinned = false;

                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final docs = snapshot.data!.docs.toList();

                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;

                      final aPinned = aData['isPinned'] == true;
                      final bPinned = bData['isPinned'] == true;

                      if (aPinned != bPinned) {
                        return aPinned ? -1 : 1;
                      }

                      final aTime = aData['createdAt'];
                      final bTime = bData['createdAt'];

                      if (aTime is! Timestamp || bTime is! Timestamp) return 0;

                      return bTime.compareTo(aTime);
                    });

                    final data = docs.first.data() as Map<String, dynamic>;

                    previewText = data['title']?.toString() ?? '未命名公告';

                    isPinned = data['isPinned'] == true;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPinned)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '置頂公告',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      const Text(
                        '最新公告',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB86B18),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF3A2A1A),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Icon(Icons.chevron_right, size: 22, color: Color(0xFFB86B18)),
          ],
        ),
      ),
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
        padding: const EdgeInsets.all(8),
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
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD59E),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: Color(0xFF6B3F16)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
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
                      fontSize: 14,
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
    required Color activeColor,
  }) {
    final isActive = (url ?? '').isNotEmpty;

    return GestureDetector(
      onTap: isActive ? () => _openUrl(url!) : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 28,
          color: isActive ? activeColor : Colors.grey,
        ),
      ),
    );
  }
}
