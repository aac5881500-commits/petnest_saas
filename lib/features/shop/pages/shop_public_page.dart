// lib/features/shop/pages/shop_public_page.dart
// 👤 前台店家家頁（完整版🔥 + Drawer版 + 修正錯誤）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
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
import 'package:petnest_saas/features/shop/pages/shop_faq_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_list_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_review_list_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_modern_page.dart';
import 'package:petnest_saas/features/shop/widgets/floating_contact_button.dart';

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

  void _showFreeModeSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('此店家目前為免費版，完整前台功能尚未開放，請直接聯絡店家洽詢')),
    );
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

        final accountStatus = (shop['accountStatus'] ?? 'normal').toString();
        final shopStatus = (shop['status'] ?? 'active').toString();

        if (accountStatus == 'suspended' || shopStatus == 'suspended') {
          return Scaffold(
            backgroundColor: const Color(0xFFFFFCF7),
            appBar: AppBar(
              title: const Text('店家暫停服務'),
              backgroundColor: const Color(0xFFFFFCF7),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 64, color: Colors.red),
                      SizedBox(height: 18),
                      Text(
                        '店家暫停服務',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 10),
                      const Text(
                        '此店家目前已停止使用平台服務。\n你可以前往平台探索其他優質店家。',
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.5, color: Colors.black54),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.search),
                          label: const Text('探索其他店家'),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PlatformShopListPage(),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final rawHomeAppearance = shop['homeAppearance'];

        final homeAppearance = rawHomeAppearance is Map
            ? Map<String, dynamic>.from(rawHomeAppearance)
            : <String, dynamic>{};

        final layout = (homeAppearance['layout'] ?? 'classic').toString();

        if (layout == 'modern') {
          return ShopPublicModernPage(
            shopId: widget.shopId,
            platformPreview: widget.platformPreview,
          );
        }

        final rawClassicAppearance = homeAppearance['classic'];

        final classicAppearance = rawClassicAppearance is Map
            ? Map<String, dynamic>.from(rawClassicAppearance)
            : <String, dynamic>{};

        final classicTheme = HomeThemeModel.fromClassicSettings(
          rawData: classicAppearance.isNotEmpty
              ? classicAppearance
              : homeAppearance,
        );

        final externalLinksEnabled = shop['externalLinksEnabled'] != false;
        final plan = shop['plan']?.toString() ?? 'free';
        final paidUntil = shop['paidUntil'];

        bool isPaidActive = false;

        if (paidUntil is Timestamp) {
          isPaidActive = paidUntil.toDate().isAfter(DateTime.now());
        }

        final isFreeMode = plan == 'free' || !isPaidActive;

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
            .where((e) => e['image']!.isNotEmpty)
            .toList();

        /// 舊資料兼容（如果還沒升級）
        if (banners.isEmpty && (shop['coverUrl'] ?? '').toString().isNotEmpty) {
          banners.add({'image': shop['coverUrl']});
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          for (final banner in banners) {
            final imageUrl = banner['image'];
            if (imageUrl == null || imageUrl.isEmpty) continue;

            precacheImage(NetworkImage(imageUrl), context);
          }
        });

        /// 🔥 正確：只保留一個 Scaffold
        return Scaffold(
          backgroundColor: classicTheme.backgroundColor,

          drawer: AppDrawer(
            shopId: widget.shopId,
            theme: classicTheme,
            platformPreview: widget.platformPreview,
          ),

          appBar: AppBar(
            backgroundColor: classicTheme.backgroundColor,
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: classicTheme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '🐾 讓每一隻貓咪都有溫暖的家 🐾',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: classicTheme.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            centerTitle: true,
          ),

          body: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  /// 🔥 上半部
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        /// 🔥 Banner（Stack版本，100%正常）
                        if (banners.isNotEmpty)
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                /// 圖片滑動
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragEnd: (details) {
                                    if (banners.length <= 1) return;

                                    final velocity =
                                        details.primaryVelocity ?? 0;

                                    if (velocity < -120) {
                                      setState(() {
                                        _currentIndex =
                                            _currentIndex == banners.length - 1
                                            ? 0
                                            : _currentIndex + 1;
                                      });
                                    }

                                    if (velocity > 120) {
                                      setState(() {
                                        _currentIndex = _currentIndex == 0
                                            ? banners.length - 1
                                            : _currentIndex - 1;
                                      });
                                    }
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      color: Colors.black,
                                      child: Center(
                                        child: Image.network(
                                          banners[_currentIndex]['image']!,
                                          key: ValueKey(
                                            banners[_currentIndex]['image'],
                                          ),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      ),
                                    ),
                                  ),
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

                        if (isFreeMode) ...[
                          _buildFreeModeNoticeCard(shop),
                        ] else ...[
                          /// 🔥 貓咪旅館主服務卡
                          _buildMainServiceButton(
                            theme: classicTheme,
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
                                      theme: classicTheme,
                                      readOnly: true,
                                    ),
                                  ),
                                );

                                if (result != true) return;
                              }

                              if (!mounted) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShopBookingPage(
                                    shopId: widget.shopId,
                                    theme: classicTheme,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 14),

                          if (shop['showAnnouncementSection'] != false) ...[
                            _buildNoticePreviewCard(
                              theme: classicTheme,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ShopAnnouncementPage(
                                      shopId: widget.shopId,
                                      theme: classicTheme,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                          ] else
                            const SizedBox(height: 4),

                          ShopSectionTitle(
                            icon: Icons.pets,
                            title: '住宿服務',
                            theme: classicTheme,
                          ),

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
                                theme: classicTheme,
                                title: '環境介紹',
                                subtitle: '住宿空間・安心設備',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ShopEnvironmentPage(
                                        shopId: widget.shopId,
                                        theme: classicTheme,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ShopTemplateFeatureCard(
                                icon: Icons.bed,
                                theme: classicTheme,
                                title: '房間介紹',
                                subtitle: '多種房型・專屬選擇',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ShopRoomIntroPage(
                                        shopId: widget.shopId,
                                        theme: classicTheme,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ShopTemplateFeatureCard(
                                icon: Icons.info,
                                theme: classicTheme,
                                title: '入住須知',
                                subtitle: '入住條件・注意事項',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ShopPolicyViewPage(
                                        shopId: widget.shopId,
                                        theme: classicTheme,
                                        readOnly: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (shop['showCameraSection'] != false)
                                ShopTemplateFeatureCard(
                                  theme: classicTheme,
                                  icon: Icons.videocam,
                                  title: '觀看攝影機',
                                  subtitle: '即時查看毛孩狀況',
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('攝影機功能將於後續版本提供'),
                                      ),
                                    );
                                  },
                                ),
                              ShopTemplateFeatureCard(
                                theme: classicTheme,
                                icon: Icons.favorite,
                                title: '關於我們',
                                subtitle: '品牌理念・店家故事',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ShopAboutPage(
                                        shopId: widget.shopId,
                                        theme: classicTheme,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: FirebaseFirestore.instance
                                    .collection('reviews')
                                    .where('shopId', isEqualTo: widget.shopId)
                                    .where('status', isEqualTo: 'visible')
                                    .snapshots(),
                                builder: (context, reviewSnapshot) {
                                  final reviewDocs =
                                      reviewSnapshot.data?.docs ?? [];

                                  double total = 0;
                                  for (final doc in reviewDocs) {
                                    final data = doc.data();
                                    total += ((data['rating'] ?? 0) as num)
                                        .toDouble();
                                  }

                                  final subtitle = reviewDocs.isEmpty
                                      ? '目前尚無評價'
                                      : '⭐ ${(total / reviewDocs.length).toStringAsFixed(1)}（${reviewDocs.length}）・查看全部評價';

                                  return ShopTemplateFeatureCard(
                                    theme: classicTheme,
                                    icon: Icons.star,
                                    title: '評價專區',
                                    subtitle: subtitle,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ShopReviewListPage(
                                            shopId: widget.shopId,
                                            theme: classicTheme,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              if (shop['showFaqSection'] != false)
                                ShopTemplateFeatureCard(
                                  theme: classicTheme,
                                  icon: Icons.help,
                                  title: '常見問題',
                                  subtitle: '常見疑問・快速解答',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ShopFaqPage(
                                          shopId: widget.shopId,
                                          theme: classicTheme,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),

                  /// 🔥 固定底部
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    decoration: BoxDecoration(
                      color: classicTheme.cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: classicTheme.textColor.withValues(alpha: 0.06),
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
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: classicTheme.textColor,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showShopInfo
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: classicTheme.primaryColor,
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
                            theme: classicTheme,
                          ),
                          GestureDetector(
                            onTap: externalLinksEnabled
                                ? () => _callPhone(shop['phone'] ?? '')
                                : null,
                            child: _buildInfoRow(
                              Icons.phone,
                              '電話',
                              shop['phone'] ?? '',
                              theme: classicTheme,
                            ),
                          ),
                          GestureDetector(
                            onTap: externalLinksEnabled
                                ? () => _openMap(
                                    '${shop['city'] ?? ''}${shop['district'] ?? ''}${shop['address'] ?? ''}',
                                  )
                                : null,
                            child: _buildInfoRow(
                              Icons.location_on,
                              '地址',
                              '${shop['city'] ?? ''}${shop['district'] ?? ''}${shop['address'] ?? ''}',
                              theme: classicTheme,
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
                                    theme: classicTheme,
                                  ),
                                ),

                              if (shop['showTaxId'] == true &&
                                  (shop['taxId'] ?? '').toString().isNotEmpty)
                                Expanded(
                                  child: _buildInfoRow(
                                    Icons.receipt,
                                    '統編',
                                    shop['taxId'] ?? '',
                                    theme: classicTheme,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),

                        if (externalLinksEnabled && !isFreeMode)
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

              FloatingContactButton(shop: shop),
            ],
          ),
        );
      },
    );
  }

  Widget ShopSectionTitle({
    required IconData icon,
    required String title,
    required HomeThemeModel theme,
    String actionText = '',
    VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: theme.textColor,
          ),
        ),
        const Spacer(),

        if (actionText.isNotEmpty)
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionText,
              style: TextStyle(
                fontSize: 13,
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoticePreviewCard({
    required HomeThemeModel theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorderColor),
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
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.campaign, size: 22, color: theme.primaryColor),
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
                  String typeLabel = '最新公告';

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
                    typeLabel = _announcementTypeLabel(
                      data['type']?.toString() ?? 'normal',
                    );
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
                            color: theme.primaryColor,
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

                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryColor,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: theme.textColor),
                      ),
                    ],
                  );
                },
              ),
            ),
            Icon(Icons.chevron_right, size: 22, color: theme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeModeNoticeCard(Map<String, dynamic> shop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD7A8)),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 42, color: Color(0xFFB86B18)),

          const SizedBox(height: 12),

          const Text(
            '此店家目前使用免費方案',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 8),

          const Text('線上預約功能將於後續版本提供', textAlign: TextAlign.center),

          const SizedBox(height: 18),

          if ((shop['phone'] ?? '').toString().isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _callPhone(shop['phone']);
                },
                icon: const Icon(Icons.phone),
                label: const Text('直接聯絡店家'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainServiceButton({
    required HomeThemeModel theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.cardBorderColor),
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: theme.primaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    actionText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 18, color: theme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value, {
    required HomeThemeModel theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.primaryColor),
          const SizedBox(width: 8),
          Text(
            '$title：',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.textColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.75)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required FaIconData icon,
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
        child: Center(
          child: FaIcon(
            icon,
            size: 28,
            color: isActive ? activeColor : Colors.grey,
          ),
        ),
      ),
    );
  }

  String _announcementTypeLabel(String type) {
    switch (type) {
      case 'important':
        return '重要公告';
      case 'business_hours':
        return '營業異動';
      case 'promotion':
        return '優惠活動';
      case 'checkin_notice':
        return '入住提醒';
      case 'normal':
      default:
        return '一般公告';
    }
  }
}
