// 🏠 HomePage（登入後首頁）
// lib/features/auth/pages/home_page.dart
// 功能：登入後首頁、建立店家、我的店家列表、登出

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/auth_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/platform/pages/create_shop_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_list_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_admin_page.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_card.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_stat_row.dart';
import 'package:petnest_saas/features/auth/widgets/platform_section_title.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_badges.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_info.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_open_status_helper.dart';
import 'package:petnest_saas/features/auth/pages/my_shop_card_media_page.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_meta_info.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_qr_link_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<List<Map<String, dynamic>>>? _shopsFuture;

  @override
  void initState() {
    super.initState();

    _shopsFuture = ShopService.instance.getMyShops();
  }

  Future<void> _reloadShops() async {
    setState(() {
      _shopsFuture = ShopService.instance.getMyShops();
    });
  }

  Future<void> _openCreateShopPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateShopPage()),
    );

    if (!mounted) return;

    await _reloadShops();
  }

  String _businessTypeLabel(String value) {
    switch (value) {
      case 'cat_hotel':
        return '貓咪旅館';
      case 'dog_hotel':
        return '狗狗旅館';
      case 'grooming':
        return '寵物美容';
      case 'hospital':
        return '動物醫院';
      case 'shop':
        return '寵物賣場';
      default:
        return '其他服務';
    }
  }

  String _roleLabel(String value) {
    switch (value) {
      case 'owner':
        return '店主';
      case 'manager':
        return '主管';
      case 'staff':
        return '員工';
      default:
        return value;
    }
  }

  bool _isRootAdmin(String? uid) {
    return uid == 'LTk2AdDOAIVGhlkt97fnbD5TXIf1' ||
        uid == '7FNrECQeqAca9Vu8lBBzTSdcJcg1';
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Padding(
          padding: EdgeInsets.zero,
          child: Image.asset(
            'assets/images/petnest_logo.png',
            height: 558,
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          if (_isRootAdmin(uid))
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlatformAdminPage()),
                );
              },
              icon: const Icon(Icons.admin_panel_settings, size: 18),
              label: const Text('平台後台'),
            ),

          PopupMenuButton<String>(
            icon: const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 18),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                await _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '目前登入',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),

                    SelectableText(
                      uid ?? '',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('登出'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user?.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PlatformShopListPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.search, size: 17),
                      label: const Text('找店'),
                    ),
                    TextButton.icon(
                      onPressed: _openCreateShopPage,
                      icon: const Icon(Icons.add_business, size: 17),
                      label: const Text('開店'),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                const PlatformSectionTitle(title: '我的店家'),
                const SizedBox(height: 12),

                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _shopsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final shops = snapshot.data ?? [];

                      if (shops.isEmpty) {
                        return const Center(child: Text('還沒有店家'));
                      }

                      return PageView.builder(
                        itemCount: shops.length,
                        controller: PageController(viewportFraction: 0.94),
                        itemBuilder: (context, index) {
                          final shop = shops[index];
                          final coverUrl =
                              shop['platformHomeCoverUrl']?.toString() ?? '';
                          final logoUrl =
                              shop['platformHomeLogoUrl']?.toString() ?? '';
                          final city = shop['city']?.toString() ?? '';
                          final district = shop['district']?.toString() ?? '';
                          final enabledModules = List<String>.from(
                            shop['enabledModules'] ?? [],
                          );

                          final licenseNumber =
                              shop['licenseNumber']?.toString() ?? '';

                          final taxId = shop['taxId']?.toString() ?? '';

                          final updatedAt = shop['updatedAt'];
                          final isOpen = shop['isOpen'] == true;
                          final openTime = shop['openTime']?.toString() ?? '';
                          final closeTime = shop['closeTime']?.toString() ?? '';

                          final isOpenNow = isShopOpenNow(
                            isOpen: isOpen,
                            openTime: openTime,
                            closeTime: closeTime,
                          );
                          final isPublic = shop['isPublic'] == true;

                          final businessType = _businessTypeLabel(
                            shop['businessType']?.toString() ?? '',
                          );

                          final role = _roleLabel(
                            shop['role']?.toString() ?? '',
                          );
                          return MyShopCard(
                            shop: shop,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ShopDashboardPage(shopId: shop['shopId']),
                                ),
                              );
                            },
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        height: 70,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(22),
                                              ),
                                          image: coverUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(coverUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: coverUrl.isEmpty
                                            ? const Center(
                                                child: Icon(
                                                  Icons.storefront,
                                                  size: 28,
                                                  color: Colors.black26,
                                                ),
                                              )
                                            : null,
                                      ),

                                      Positioned(
                                        left: 14,
                                        top: 14,
                                        child: _HomeBadge(
                                          text: isOpenNow ? '營業中' : '休息中',
                                          icon: Icons.circle,
                                        ),
                                      ),
                                      Positioned(
                                        right: 14,
                                        top: 14,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    MyShopCardMediaPage(
                                                      shopId: shop['shopId']
                                                          .toString(),
                                                    ),
                                              ),
                                            ).then((_) {
                                              _reloadShops();
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.image,
                                                  size: 15,
                                                  color: Colors.blue,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '圖片',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      2,
                                      10,
                                      10,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 56,
                                              height: 56,
                                              margin: const EdgeInsets.only(
                                                right: 14,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: Colors.grey.shade200,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.06),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                                image: logoUrl.isNotEmpty
                                                    ? DecorationImage(
                                                        image: NetworkImage(
                                                          logoUrl,
                                                        ),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                              ),
                                              child: logoUrl.isEmpty
                                                  ? const Icon(
                                                      Icons.storefront,
                                                      size: 24,
                                                      color: Colors.black26,
                                                    )
                                                  : null,
                                            ),

                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  MyShopInfo(
                                                    shopName:
                                                        shop['name'] ?? '未命名店家',
                                                    businessType: businessType,
                                                    city: city,
                                                    district: district,
                                                    shopId: shop['shopId']
                                                        .toString(),
                                                    shopCode:
                                                        shop['shopCode']
                                                            ?.toString() ??
                                                        '',
                                                  ),

                                                  const SizedBox(height: 4),

                                                  MyShopBadges(
                                                    role: role,
                                                    isPublic: isPublic,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const Icon(
                                              Icons.chevron_right,
                                              size: 34,
                                              color: Colors.black45,
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        MyShopQrLinkCard(
                                          shopCode:
                                              shop['shopCode']
                                                      ?.toString()
                                                      .isNotEmpty ==
                                                  true
                                              ? shop['shopCode'].toString()
                                              : shop['shopId'].toString(),
                                        ),
                                        const SizedBox(height: 8),

                                        MyShopStatRow(
                                          shopId: shop['shopId'].toString(),
                                        ),
                                        MyShopMetaInfo(
                                          enabledModules: enabledModules,
                                          openTime: openTime,
                                          closeTime: closeTime,
                                          isPublic: isPublic,
                                          licenseNumber: licenseNumber,
                                          taxId: taxId,
                                          updatedAt: updatedAt,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
}

class _HomeBadge extends StatelessWidget {
  const _HomeBadge({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: text == '營業中' ? Colors.green.shade600 : Colors.grey.shade500,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: text == '營業中'
                  ? Colors.green.shade700
                  : Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
