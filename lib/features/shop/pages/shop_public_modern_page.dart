// 檔案名稱：lib/features/shop/pages/shop_public_modern_page.dart
// 功能說明：讀取店家資料，顯示適合手機的緊湊型頂部與 Banner
// ✨ 店家新版前台首頁 Beta

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_app_drawer.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_banner_carousel.dart';
import 'package:petnest_saas/features/shop/data/environment_facility_options.dart';
import 'package:petnest_saas/features/shop/pages/room_type_detail_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_intro_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_review_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_staying_daily_care_section.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_faq_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_review_list_page.dart';
import 'package:petnest_saas/features/shop/widgets/floating_contact_button.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/services/home_banner_navigation.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/features/shop/widgets/store/featured_store_products_section.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_entrance_banner.dart';

class ShopPublicModernPage extends StatefulWidget {
  const ShopPublicModernPage({
    super.key,
    required this.shopId,
    this.platformPreview = false,
  });

  final String shopId;
  final bool platformPreview;

  @override
  State<ShopPublicModernPage> createState() => _ShopPublicModernPageState();
}

class _ShopPublicModernPageState extends State<ShopPublicModernPage> {
  static const Color _backgroundColor = Color(0xFFFFFCF7);

  List<StoreBannerModel> _enabledHomeBanners(Map<String, dynamic> shop) {
    return HomeBannerService.instance.parseEnabledFrontBanners(shop);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: _backgroundColor,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: _backgroundColor,
            body: Center(
              child: Text(
                '讀取失敗：${snapshot.error}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          );
        }

        final shop = snapshot.data;

        if (shop == null) {
          return const Scaffold(
            backgroundColor: _backgroundColor,
            body: Center(
              child: Text(
                '找不到店家資料',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          );
        }

        final shopName = (shop['name'] ?? '店家').toString().trim();
        final rawHomeAppearance = shop['homeAppearance'];

        final homeAppearance = rawHomeAppearance is Map
            ? Map<String, dynamic>.from(rawHomeAppearance)
            : <String, dynamic>{};

        final rawModernAppearance = homeAppearance['modern'];

        final modernAppearance = rawModernAppearance is Map
            ? Map<String, dynamic>.from(rawModernAppearance)
            : <String, dynamic>{};
        final modernTheme = HomeThemeModel.fromMap(
          modernAppearance['themeColors'],
          fallback: const HomeThemeModel(
            backgroundColorValue: 0xFFFFFBF7,
            cardColorValue: 0xFFFFFFFF,
            cardBorderColorValue: 0xFFFFD9B3,
            primaryColorValue: 0xFFFF8A00,
            textColorValue: 0xFF3A2A20,
          ),
        );
        final hasHeaderSubtitleSetting = modernAppearance.containsKey(
          'headerSubtitle',
        );

        final headerSubtitle = hasHeaderSubtitleSetting
            ? (modernAppearance['headerSubtitle'] ?? '').toString().trim()
            : '讓每一隻貓咪都有溫暖的家';
        final storeHomeSetting = ModernStoreHomeSetting.fromMap(
          modernAppearance,
        );
        final bannerFrameSetting = ModernBannerFrameSetting.fromMap(
          modernAppearance,
        );
        final showLeftHeaderIcon =
            modernAppearance['showLeftHeaderIcon'] != false;

        final showRightHeaderIcon =
            modernAppearance['showRightHeaderIcon'] != false;
        final leftHeaderIcon = (modernAppearance['leftHeaderIcon'] ?? 'paw')
            .toString();

        final rightHeaderIcon = (modernAppearance['rightHeaderIcon'] ?? 'paw')
            .toString();

        final rawEnvironmentIntro = shop['environmentIntro'];

        final environmentIntro = rawEnvironmentIntro is Map
            ? Map<String, dynamic>.from(rawEnvironmentIntro)
            : <String, dynamic>{};

        final rawFacilityKeys = environmentIntro['facilityKeys'];

        final facilityKeys = <String>[];

        if (rawFacilityKeys is List) {
          for (final item in rawFacilityKeys) {
            final value = item.toString().trim();

            if (value.isNotEmpty) {
              facilityKeys.add(value);
            }
          }
        }

        final banners = _enabledHomeBanners(shop);

        return Scaffold(
          backgroundColor: modernTheme.backgroundColor,

          drawer: ModernAppDrawer(
            shopId: widget.shopId,
            shop: shop,
            theme: modernTheme,
            platformPreview: widget.platformPreview,
          ),
          appBar: _buildAppBar(
            context: context,
            shopName: shopName,
            headerSubtitle: headerSubtitle,
            showLeftHeaderIcon: showLeftHeaderIcon,
            showRightHeaderIcon: showRightHeaderIcon,
            leftHeaderIcon: leftHeaderIcon,
            rightHeaderIcon: rightHeaderIcon,
            backgroundColor: modernTheme.backgroundColor,
            primaryColor: modernTheme.primaryColor,
            textColor: modernTheme.textColor,
          ),

          bottomNavigationBar: SafeArea(
            top: false,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ModernShopFooter(
                  shopId: widget.shopId,
                  shop: shop,
                  shopName: shopName,
                  primaryColor: modernTheme.primaryColor,
                  darkTextColor: modernTheme.textColor,
                  secondaryTextColor: modernTheme.textColor.withValues(
                    alpha: 0.65,
                  ),
                  cardColor: modernTheme.cardColor,
                  borderColor: modernTheme.cardBorderColor,
                ).showShopInfoSheet(context);
              },
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;

                if (velocity < -100) {
                  ModernShopFooter(
                    shopId: widget.shopId,
                    shop: shop,
                    shopName: shopName,
                    primaryColor: modernTheme.primaryColor,
                    darkTextColor: modernTheme.textColor,
                    secondaryTextColor: modernTheme.textColor.withValues(
                      alpha: 0.65,
                    ),
                    cardColor: modernTheme.cardColor,
                    borderColor: modernTheme.cardBorderColor,
                  ).showShopInfoSheet(context);
                }
              },
              child: Container(
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: modernTheme.backgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: modernTheme.cardBorderColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 15,
                      color: modernTheme.primaryColor,
                    ),
                    SizedBox(width: 3),
                    Text(
                      '店家資訊',
                      style: TextStyle(
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: modernTheme.textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenHeight = constraints.maxHeight;

                    // 含精選商品與賣場 Banner 後的首頁估算高度
                    const estimatedContentHeight = 1120.0;

                    final canScroll = estimatedContentHeight > screenHeight;

                    return ListView(
                      physics: canScroll
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 5, 12, 12),
                      children: [
                        _buildBannerSection(
                          shop: shop,
                          banners: banners,
                          theme: modernTheme,
                          frameSetting: bannerFrameSetting,
                        ),
                        const SizedBox(height: 10),

                        _buildEnvironmentFeatureSection(
                          facilityKeys: facilityKeys,
                          theme: modernTheme,
                        ),
                        const SizedBox(height: 12),

                        if (shop['showAnnouncementSection'] != false) ...[
                          _buildLatestAnnouncementSection(theme: modernTheme),
                          const SizedBox(height: 16),
                        ],

                        ModernStayingDailyCareSection(
                          shopId: widget.shopId,
                          theme: modernTheme,
                          platformPreview: widget.platformPreview,
                        ),

                        _buildPopularRoomSection(theme: modernTheme),

                        const SizedBox(height: 18),

                        FeaturedStoreProductsSection(
                          shopId: widget.shopId,
                          shop: shop,
                          theme: modernTheme,
                          setting: storeHomeSetting,
                        ),

                        StoreEntranceBanner(
                          shopId: widget.shopId,
                          shop: shop,
                          theme: modernTheme,
                          setting: storeHomeSetting,
                        ),

                        _buildStayServiceSection(shop, theme: modernTheme),

                        const SizedBox(height: 18),

                        ModernReviewSection(
                          shopId: widget.shopId,
                          primaryColor: modernTheme.primaryColor,
                          darkTextColor: modernTheme.textColor,
                          secondaryTextColor: modernTheme.textColor.withValues(
                            alpha: 0.65,
                          ),
                          cardColor: modernTheme.cardColor,
                          borderColor: modernTheme.cardBorderColor,
                          theme: modernTheme,
                        ),
                      ],
                    );
                  },
                ),
              ),

              FloatingContactButton(shop: shop, shopId: widget.shopId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStayServiceSection(
    Map<String, dynamic> shop, {
    required HomeThemeModel theme,
  }) {
    final showCamera = shop['showCameraSection'] != false;

    final services = <Map<String, dynamic>>[
      {
        'icon': Icons.home_outlined,
        'title': '環境介紹',
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ShopEnvironmentPage(shopId: widget.shopId, theme: theme),
            ),
          );
        },
      },
      {
        'icon': Icons.bedroom_parent_outlined,
        'title': '全部房型',
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ShopRoomIntroPage(shopId: widget.shopId, theme: theme),
            ),
          );
        },
      },
      {
        'icon': Icons.description_outlined,
        'title': '入住須知',
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ShopPolicyViewPage(
                shopId: widget.shopId,
                theme: theme,
                readOnly: true,
              ),
            ),
          );
        },
      },
      if (showCamera)
        {
          'icon': Icons.videocam_outlined,
          'title': '觀看攝影機',
          'onTap': () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('攝影機需於入住期間開放')));
          },
        },
      {
        'icon': Icons.favorite_border_rounded,
        'title': '關於我們',
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ShopAboutPage(shopId: widget.shopId, theme: theme),
            ),
          );
        },
      },
      {
        'icon': Icons.star_border_rounded,
        'title': '評價專區',
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ShopReviewListPage(shopId: widget.shopId, theme: theme),
            ),
          );
        },
      },
      if (shop['showFaqSection'] != false)
        {
          'icon': Icons.help_outline_rounded,
          'title': '常見問題',
          'onTap': () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ShopFaqPage(shopId: widget.shopId, theme: theme),
              ),
            );
          },
        },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hotel_outlined, size: 16, color: theme.primaryColor),
            const SizedBox(width: 6),
            Text(
              '住宿服務',
              style: TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: services.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final service = services[index];

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: service['onTap'] as VoidCallback,
                child: Container(
                  width: 78,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.cardBorderColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          service['icon'] as IconData,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        service['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularRoomSection({required HomeThemeModel theme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pets_rounded, size: 16, color: theme.primaryColor),
            const SizedBox(width: 6),
            Text(
              '熱門房型',
              style: TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: ShopService.instance.streamRoomTypes(widget.shopId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 196,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 120,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.cardBorderColor),
                ),
                child: Text(
                  '房型資料讀取失敗',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.65),
                  ),
                ),
              );
            }

            final roomTypes = snapshot.data ?? [];

            if (roomTypes.isEmpty) {
              return Container(
                height: 120,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.cardBorderColor),
                ),
                child: Text(
                  '目前尚未建立房型',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.65),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: roomTypes.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  if (index == roomTypes.length) {
                    return _buildAllRoomsCard(context, theme: theme);
                  }
                  return _buildRoomTypeCard(
                    context: context,
                    roomType: roomTypes[index],
                    theme: theme,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoomTypeCard({
    required BuildContext context,
    required Map<String, dynamic> roomType,
    required HomeThemeModel theme,
  }) {
    final name = (roomType['name'] ?? '未命名房型').toString().trim();

    final rawImages = roomType['images'];
    final images = rawImages is List
        ? rawImages
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];

    final imageUrl = images.isNotEmpty ? images.first : '';

    final rawPrice = roomType['price'];
    final price = rawPrice is num
        ? rawPrice.toInt()
        : int.tryParse(rawPrice?.toString() ?? '') ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) {
              return RoomTypeDetailPage(
                shopId: widget.shopId,
                roomType: roomType,
                startDate: DateTime.now(),
                endDate: DateTime.now().add(const Duration(days: 1)),
                theme: theme,
                isIntroMode: true,
              );
            },
          ),
        );
      },
      child: Container(
        width: 112,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 70,
                width: double.infinity,
                child: imageUrl.isEmpty
                    ? Container(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.bedroom_parent_outlined,
                          size: 30,
                          color: theme.primaryColor,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: theme.primaryColor.withValues(alpha: 0.12),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 28,
                              color: theme.primaryColor,
                            ),
                          );
                        },
                      ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(7, 5, 5, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: theme.textColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 12,
                          color: theme.primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      price > 0 ? '\$$price / 天起' : '價格洽店家',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllRoomsCard(
    BuildContext context, {
    required HomeThemeModel theme,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ShopRoomIntroPage(shopId: widget.shopId, theme: theme),
          ),
        );
      },
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '>>',
              style: TextStyle(
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w800,
                color: theme.primaryColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '全部房型',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required BuildContext context,
    required String shopName,
    required String headerSubtitle,
    required bool showLeftHeaderIcon,
    required bool showRightHeaderIcon,
    required String leftHeaderIcon,
    required String rightHeaderIcon,
    required Color backgroundColor,
    required Color primaryColor,
    required Color textColor,
  }) {
    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 60,
      leadingWidth: 46,
      titleSpacing: 0,
      leading: widget.platformPreview
          ? IconButton(
              tooltip: '返回',
              splashRadius: 20,
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              onPressed: () {
                Navigator.pop(context);
              },
            )
          : Builder(
              builder: (drawerContext) {
                return IconButton(
                  tooltip: '選單',
                  splashRadius: 20,
                  icon: const Icon(Icons.menu_rounded, size: 25),
                  onPressed: () {
                    Scaffold.of(drawerContext).openDrawer();
                  },
                );
              },
            ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLeftHeaderIcon) ...[
                Icon(
                  _headerIconData(leftHeaderIcon),
                  size: 14,
                  color: primaryColor,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.1,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              if (showRightHeaderIcon) ...[
                const SizedBox(width: 5),
                Icon(
                  _headerIconData(rightHeaderIcon),
                  size: 14,
                  color: primaryColor,
                ),
              ],
            ],
          ),
          if (headerSubtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              headerSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                height: 1.1,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w400,
                color: textColor.withValues(alpha: 0.68),
              ),
            ),
          ],
        ],
      ),
      centerTitle: true,
      actions: const [SizedBox(width: 12)],
    );
  }

  IconData _headerIconData(String value) {
    switch (value) {
      case 'heart':
        return Icons.favorite_rounded;

      case 'star':
        return Icons.star_rounded;

      case 'home':
        return Icons.home_rounded;

      case 'crown':
        return Icons.workspace_premium_rounded;

      case 'paw':
      default:
        return Icons.pets_rounded;
    }
  }

  Widget _buildBannerReviewBadge({
    required HomeThemeModel theme,
    required bool compact,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('shopId', isEqualTo: widget.shopId)
          .where('status', isEqualTo: 'visible')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        double averageRating = 0;

        if (docs.isNotEmpty) {
          var totalRating = 0;

          for (final doc in docs) {
            final rawRating = doc.data()['rating'];

            if (rawRating is num) {
              totalRating += rawRating.toInt();
            }
          }

          averageRating = totalRating / docs.length;
        }

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 7,
            vertical: compact ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: compact ? 10 : 12,
                color: const Color(0xFFFFB300),
              ),
              SizedBox(width: compact ? 2 : 3),
              Text(
                docs.isEmpty ? '尚無評價' : averageRating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: compact ? 9 : 10,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              if (docs.isNotEmpty && !compact) ...[
                const SizedBox(width: 3),
                Text(
                  '${docs.length} 則評價',
                  style: TextStyle(
                    fontSize: 8,
                    height: 1,
                    color: theme.textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBannerSection({
    required Map<String, dynamic> shop,
    required List<StoreBannerModel> banners,
    required HomeThemeModel theme,
    required ModernBannerFrameSetting frameSetting,
  }) {
    return ModernHomeBannerCarousel(
      key: ValueKey<String>('modern-home-banner-${widget.shopId}'),
      banners: banners,
      theme: theme,
      frameSetting: frameSetting,
      onBannerTap: (StoreBannerModel banner) {
        HomeBannerNavigation.open(
          context: context,
          shopId: widget.shopId,
          shop: shop,
          theme: theme,
          banner: banner,
          useModernDrawer: true,
        );
      },
      reviewBadge: _buildBannerReviewBadge(
        theme: theme,
        compact: frameSetting.isUltraCompact,
      ),
    );
  }

  Widget _buildEnvironmentFeatureSection({
    required List<String> facilityKeys,
    required HomeThemeModel theme,
  }) {
    if (facilityKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedFacilities = environmentFacilityOptions.where((item) {
      final key = (item['key'] ?? '').toString();
      return facilityKeys.contains(key);
    }).toList();

    if (selectedFacilities.isEmpty) {
      return const SizedBox.shrink();
    }

    void openEnvironmentPage() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ShopEnvironmentPage(shopId: widget.shopId, theme: theme),
        ),
      );
    }

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: selectedFacilities.length + 1,
        separatorBuilder: (context, index) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          final isLastButton = index == selectedFacilities.length;

          if (isLastButton) {
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: openEnvironmentPage,
              child: Container(
                width: 72,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.cardBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      size: 32,
                      color: theme.primaryColor,
                    ),
                    SizedBox(height: 5),
                    Text(
                      '環境介紹',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final facility = selectedFacilities[index];

          final title = (facility['title'] ?? '照護設備').toString().trim();

          final icon = facility['icon'] is IconData
              ? facility['icon'] as IconData
              : Icons.pets_outlined;

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: openEnvironmentPage,
            child: Container(
              width: 72,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.cardBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: theme.primaryColor),
                  ),

                  const SizedBox(height: 7),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLatestAnnouncementSection({required HomeThemeModel theme}) {
    void openAnnouncementPage() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ShopAnnouncementPage(shopId: widget.shopId, theme: theme),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('announcements')
          .where('isPublished', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        String title = '目前尚無公告';
        String type = 'normal';
        bool hasAnnouncement = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs.toList();

          docs.sort((a, b) {
            final aData = a.data();
            final bData = b.data();

            final aPinned = aData['isPinned'] == true;
            final bPinned = bData['isPinned'] == true;

            if (aPinned != bPinned) {
              return aPinned ? -1 : 1;
            }

            final aTime = aData['createdAt'];
            final bTime = bData['createdAt'];

            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }

            return 0;
          });

          final announcement = docs.first.data();

          title = (announcement['title'] ?? '未命名公告').toString().trim();
          type = (announcement['type'] ?? 'normal').toString();
          hasAnnouncement = true;
        }

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: openAnnouncementPage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.cardBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 7,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _announcementIcon(type),
                    size: 18,
                    color: theme.primaryColor,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '最新公告',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.2,
                          color: hasAnnouncement
                              ? theme.textColor.withValues(alpha: 0.65)
                              : theme.textColor.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.primaryColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _announcementIcon(String type) {
    switch (type) {
      case 'important':
        return Icons.priority_high_rounded;
      case 'business_hours':
        return Icons.schedule_rounded;
      case 'promotion':
        return Icons.local_offer_outlined;
      case 'checkin_notice':
        return Icons.notifications_active_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }
}
