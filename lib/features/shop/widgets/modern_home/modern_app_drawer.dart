// lib/features/shop/widgets/modern_home/modern_app_drawer.dart
// 🐾 新版首頁專用 Drawer
// 功能：保留原本完整選單功能，後續可獨立重新設計，不影響 Classic

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_entry_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';
import 'package:petnest_saas/features/booking/pages/my_reviews_page.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/member/pages/member_page.dart';
import 'package:petnest_saas/features/member/pages/member_point_detail_page.dart';
import 'package:petnest_saas/core/widgets/drawer_point_balance_card.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_customer_chat_page.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_faq_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_modern_logo.dart';
import 'package:petnest_saas/core/widgets/member_avatar.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_intro_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/my_store_orders_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/store_home_page.dart';

class ModernAppDrawer extends StatelessWidget {
  const ModernAppDrawer({
    super.key,
    required this.shopId,
    required this.shop,
    required this.theme,
    this.platformPreview = false,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final HomeThemeModel theme;
  final bool platformPreview;

  Color get _primaryColor => theme.primaryColor;
  Color get _textColor => theme.textColor;
  Color get _backgroundColor => theme.backgroundColor;
  Color get _cardColor => theme.cardColor;
  Color get _borderColor => theme.cardBorderColor;

  // 暫時保留舊變數名稱，避免一次修改太多原本功能。
  Color get _orange => _primaryColor;
  Color get _brown => _textColor;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.72,
      elevation: 0,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: ColoredBox(
          color: _backgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, user),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      const SizedBox(height: 16),

                      if (!platformPreview && user != null)
                        DrawerPointBalanceCard(
                          shopId: shopId,
                          primaryColor: _primaryColor,
                          textColor: _textColor,
                          cardColor: _cardColor,
                          borderColor: _borderColor,
                          onTap: () {
                            Navigator.pop(context);

                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => MemberPointDetailPage(
                                  shopId: shopId,
                                  shopName: (shop['name'] ?? '').toString(),
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 8),

                      if (platformPreview) ...[
                        _sectionTitle('平台巡檢'),
                        _menuItem(
                          icon: Icons.admin_panel_settings,
                          title: '返回平台店家管理',
                          iconColor: Colors.blue,
                          textColor: Colors.blue,
                          onTap: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PlatformShopManagePage(),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                        _divider(),
                      ],

                      if (theme.drawerSetting.showMemberCenter) ...[
                        _sectionTitle('會員區'),

                        _menuItem(
                          icon: Icons.person,
                          title: '會員中心',
                          onTap: () {
                            Navigator.pop(context);
                            if (user == null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LoginPage(redirectShopId: shopId),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => MemberPage(
                                    shopId: shopId,
                                    shopName: (shop['name'] ?? '').toString(),
                                  ),
                                ),
                              );
                            }
                          },
                        ),

                        if (user != null && ShopChatService.isEnabled(shop))
                          _menuItem(
                            icon: Icons.chat_bubble_outline,
                            title: '店家訊息',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => ShopCustomerChatPage(
                                    shopId: shopId,
                                    shopName: (shop['name'] ?? '').toString(),
                                    shopLogoUrl: (shop['logoUrl'] ?? '')
                                        .toString(),
                                  ),
                                ),
                              );
                            },
                          ),

                        _menuItem(
                          icon: Icons.rate_review_outlined,
                          title: '我的評價',
                          onTap: () {
                            Navigator.pop(context);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyReviewsPage(),
                              ),
                            );
                          },
                        ),

                        _menuItem(
                          icon: Icons.receipt_long,
                          title: '我的訂單',
                          onTap: () {
                            Navigator.pop(context);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MyBookingsPage(returnShopId: shopId),
                              ),
                            );
                          },
                        ),
                        if (StorefrontAccess.isModuleEnabled(shop))
                          _menuItem(
                            icon: Icons.shopping_bag_outlined,
                            title: '我的商城訂單',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => MyStoreOrdersPage(
                                    shopId: shopId,
                                    theme: theme,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],

                      if (user != null &&
                          theme.drawerSetting.showLatestBooking) ...[
                        _latestBookingCard(context, user.uid),
                      ],

                      _divider(),
                      if (theme.drawerSetting.showShopMenus)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('shops')
                              .doc(shopId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final shop =
                                snapshot.data?.data() as Map<String, dynamic>?;

                            final plan = shop?['plan']?.toString() ?? 'free';
                            final paidUntil = shop?['paidUntil'];

                            bool isPaidActive = false;

                            if (paidUntil is Timestamp) {
                              isPaidActive = paidUntil.toDate().isAfter(
                                DateTime.now(),
                              );
                            }

                            final isFreeMode = plan == 'free' || !isPaidActive;

                            if (isFreeMode) {
                              return const SizedBox.shrink();
                            }

                            return ExpansionTile(
                              initiallyExpanded: false,
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              iconColor: _primaryColor,
                              collapsedIconColor: _textColor.withOpacity(0.45),
                              textColor: _textColor,
                              collapsedTextColor: _textColor,
                              backgroundColor: Colors.transparent,
                              collapsedBackgroundColor: Colors.transparent,
                              shape: Border(
                                bottom: BorderSide(
                                  color: _borderColor,
                                  width: 0.8,
                                ),
                              ),
                              collapsedShape: const Border(),
                              leading: Icon(
                                Icons.pets,
                                color: _primaryColor,
                                size: 14,
                              ),
                              title: Text(
                                '店家功能',
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              children: [
                                _menuItem(
                                  icon: Icons.calendar_month,
                                  title: '我要預約',
                                  onTap: () => _goBooking(context),
                                ),
                                if (StorefrontAccess.isModuleEnabled(
                                  shop ?? this.shop,
                                ))
                                  _menuItem(
                                    icon: Icons.storefront_outlined,
                                    title: '寵物賣場',
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => StoreHomePage(
                                            shopId: shopId,
                                            shop: shop ?? this.shop,
                                            theme: theme,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                _menuItem(
                                  icon: Icons.home_outlined,
                                  title: '環境介紹',
                                  onTap: () {
                                    Navigator.pop(context);

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ShopEnvironmentPage(
                                          shopId: shopId,
                                          theme: theme,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _menuItem(
                                  icon: Icons.bed,
                                  title: '房間介紹',
                                  onTap: () {
                                    Navigator.pop(context);

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ShopRoomIntroPage(
                                          shopId: shopId,
                                          theme: theme,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _menuItem(
                                  icon: Icons.description,
                                  title: '入住須知',
                                  onTap: () {
                                    Navigator.pop(context);

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ShopPolicyViewPage(
                                          shopId: shopId,
                                          theme: theme,
                                          readOnly: true,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _menuItem(
                                  icon: Icons.favorite,
                                  title: '關於我們',
                                  onTap: () {
                                    Navigator.pop(context);

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ShopAboutPage(
                                          shopId: shopId,
                                          theme: theme,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (shop?['showAnnouncementSection'] != false)
                                  _menuItem(
                                    icon: Icons.campaign_outlined,
                                    title: '最新公告',
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ShopAnnouncementPage(
                                            shopId: shopId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                if (shop?['showFaqSection'] != false)
                                  _menuItem(
                                    icon: Icons.help_outline,
                                    title: '常見問題',
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ShopFaqPage(shopId: shopId),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            );
                          },
                        ),

                      _divider(),

                      if (user != null)
                        FutureBuilder<Map<String, dynamic>?>(
                          future: ShopService.instance.getUserMemberInShop(
                            shopId: shopId,
                            uid: user.uid,
                          ),
                          builder: (context, snapshot) {
                            final memberData = snapshot.data;

                            bool hasAnyPermission = false;

                            for (final key in ShopPermissionKeys.all) {
                              if (ShopService.instance.hasPermission(
                                memberData,
                                key,
                              )) {
                                hasAnyPermission = true;
                                break;
                              }
                            }

                            if (memberData == null) {
                              return const SizedBox();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('系統'),
                                _menuItem(
                                  icon: Icons.home_work_outlined,
                                  title: '回平台首頁',
                                  onTap: () {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/home',
                                      (route) => false,
                                    );
                                  },
                                ),
                                _menuItem(
                                  icon: Icons.desktop_windows,
                                  title: '回後台',
                                  onTap: () {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ShopDashboardPage(shopId: shopId),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                ),
                                _divider(),
                              ],
                            );
                          },
                        ),

                      if (user != null)
                        _menuItem(
                          icon: Icons.logout,
                          title: '登出',
                          iconColor: Colors.red,
                          textColor: Colors.red,
                          showArrow: false,
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                    ],
                  ),
                ),

                if (theme.drawerSetting.showFooter) _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: _textColor.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: user == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.pets_rounded,
                          color: _orange,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '歡迎來到 PetNest',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _brown,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '登入後可查看訂單與寵物資料',
                              style: TextStyle(
                                fontSize: 13,
                                color: _textColor.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginPage(redirectShopId: shopId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text(
                        '登入 / 註冊',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('user_profiles')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;

                  final String name = (data?['name'] ?? '').toString().trim();
                  final String phone = (data?['phone'] ?? '').toString().trim();

                  return Row(
                    children: [
                      MemberAvatar(
                        imageUrl: resolveMemberAvatarUrl(
                          customAvatarUrl: (data?['avatarUrl'] ?? '')
                              .toString(),
                          authPhotoUrl: user.photoURL,
                        ),
                        size: 50,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isNotEmpty ? name : '會員',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _brown,
                              ),
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textColor.withOpacity(0.85),
                                ),
                              ),
                            ],
                            if ((user.email ?? '').isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                user.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _textColor.withOpacity(0.65),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: '回首頁',
                        onPressed: () {
                          Navigator.pop(context);

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopPublicPage(shopId: shopId),
                            ),
                          );
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: _primaryColor.withOpacity(0.12),
                          foregroundColor: _primaryColor,
                        ),
                        icon: const Icon(Icons.home_rounded, size: 18),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.pets, color: _orange, size: 14),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: _brown,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    bool showArrow = true,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
      minLeadingWidth: 22,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: iconColor ?? _textColor.withOpacity(0.68),
        size: 18,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? _textColor.withOpacity(0.92),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: showArrow
          ? Icon(
              Icons.chevron_right,
              size: 18,
              color: _textColor.withOpacity(0.42),
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _latestBookingCard(BuildContext context, String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('shopId', isEqualTo: shopId)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(top: 6, bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: Text(
              '目前沒有最新訂單',
              style: TextStyle(
                fontSize: 13,
                color: _textColor.withOpacity(0.65),
              ),
            ),
          );
        }

        final doc = snapshot.data!.docs.first;

        final data = doc.data() as Map<String, dynamic>;

        final customerUnreadMessageCount =
            (data['customerUnreadMessageCount'] ?? 0) as int;

        String status = data['status'] ?? 'pending';

        final rawPaymentMethod = (data['paymentMethod'] ?? '').toString();

        final rawDepositAmount = (data['depositAmount'] ?? 0).toInt();

        final rawDepositStatus = (data['depositStatus'] ?? '').toString();

        if (status == 'cancelled') {
          status = '已取消';
        } else if (status == 'completed') {
          status = '已完成';
        } else if (status == 'checked_in') {
          status = '已入住';
        } else if (status == 'confirmed') {
          status = '已確認';
        } else if (rawDepositStatus == 'pending_review') {
          status = '待店家確認付款';
        } else if (rawDepositAmount > 0) {
          status = '需支付訂金';
        } else if (rawPaymentMethod == 'transfer') {
          status = '尚未轉帳';
        } else {
          status = '待確認';
        }

        final roomTypeName = data['roomTypeName'] ?? '未指定房型';

        final shopName = (data['shopName'] ?? '').toString();

        final roomName = data['roomName'] ?? data['roomNumber'] ?? '';

        final roomImages = data['roomImages'] ?? [];

        String? roomImage;

        if (roomImages is List && roomImages.isNotEmpty) {
          final firstImage = roomImages.first;

          if (firstImage != null && firstImage.toString().isNotEmpty) {
            roomImage = firstImage.toString();
          }
        }

        final totalPrice = (data['totalPrice'] ?? 0).toInt();

        final paymentMethod = (data['paymentMethod'] ?? '').toString();

        final paymentMethodText = paymentMethod == 'transfer' ? '銀行轉帳' : '現場付款';

        final depositAmount = (data['depositAmount'] ?? 0).toInt();

        final depositExpireText = _formatDateTime(data['depositExpireAt']);

        final hasDeposit = depositAmount > 0;

        final canShowDepositExpire =
            hasDeposit &&
            depositExpireText.isNotEmpty &&
            status != '已確認' &&
            status != '已入住' &&
            status != '已完成' &&
            status != '已取消';

        final startDate = _formatDate(data['startDate']);

        final endDate = _formatDate(data['endDate']);

        final nights = data['nights'] ?? 1;

        Color statusColor = _primaryColor;

        if (status == '已完成') {
          statusColor = Colors.green;
        } else if (status == '已取消') {
          statusColor = Colors.red;
        } else if (status == '已入住') {
          statusColor = Colors.blue;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingDetailPage(docId: doc.id, data: data),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(top: 6, bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderColor),
              boxShadow: [
                BoxShadow(
                  color: _textColor.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '最新訂單',
                      style: TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),

                    const Spacer(),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        image: roomImage != null
                            ? DecorationImage(
                                image: NetworkImage(roomImage),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: roomImage == null
                          ? Icon(
                              Icons.home_work_rounded,
                              color: _textColor.withOpacity(0.28),
                              size: 24,
                            )
                          : null,
                    ),
                    const SizedBox(width: 9),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (shopName.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.storefront,
                                      size: 14,
                                      color: _primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        shopName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 2),

                              Text(
                                '$roomTypeName $roomName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _textColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 5),

                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month,
                                size: 14,
                                color: _textColor.withOpacity(0.55),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$startDate - $endDate ($nights晚)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _textColor.withOpacity(0.85),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          Row(
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                size: 14,
                                color: _textColor.withOpacity(0.55),
                              ),
                              const SizedBox(width: 4),

                              Text(
                                'NT\$ $totalPrice',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _textColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  paymentMethodText,
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),

                              if (hasDeposit)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    '訂金 NT\$ $depositAmount',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),

                              if (customerUnreadMessageCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    '💬 店家回覆 $customerUnreadMessageCount',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          if (canShowDepositExpire) ...[
                            const SizedBox(height: 8),

                            Text(
                              '付款期限：$depositExpireText',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Container(height: 1, color: _borderColor),

                const SizedBox(height: 6),

                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyBookingsPage(returnShopId: shopId),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        '查看全部訂單',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, size: 17, color: _primaryColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return '未設定';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) return '未設定';

    return '${date.month}/${date.day}';
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(color: _borderColor, thickness: 1),
    );
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '';

    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');

    return '$y-$m-$d $hh:$mm';
  }

  Widget _buildFooter() {
    final String shopName = (shop['name'] ?? 'PetNest 寵物旅社').toString().trim();

    final String logoUrl = (shop['logoUrl'] ?? '').toString().trim();

    final rawHomeAppearance = shop['homeAppearance'];

    final homeAppearance = rawHomeAppearance is Map
        ? Map<String, dynamic>.from(rawHomeAppearance)
        : <String, dynamic>{};

    final rawModernAppearance = homeAppearance['modern'];

    final modernAppearance = rawModernAppearance is Map
        ? Map<String, dynamic>.from(rawModernAppearance)
        : <String, dynamic>{};

    final bool hasHeaderSubtitleSetting = modernAppearance.containsKey(
      'headerSubtitle',
    );

    final String headerSubtitle = hasHeaderSubtitleSetting
        ? (modernAppearance['headerSubtitle'] ?? '').toString().trim()
        : '讓每一隻貓咪都有溫暖的家';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
      color: _backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, thickness: 1, color: _borderColor),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ShopModernLogo(
                imageUrl: logoUrl,
                size: 50,
                primaryColor: _primaryColor,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shopName.isNotEmpty ? shopName : 'PetNest 寵物旅社',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),

                    if (headerSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        headerSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textColor.withOpacity(0.62),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _goBooking(BuildContext context) async {
    Navigator.pop(context);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginPage(redirectShopId: shopId)),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopBookingEntryPage(
          shopId: shopId,
          theme: theme,
          useModernDrawer: true,
        ),
      ),
    );
  }
}
