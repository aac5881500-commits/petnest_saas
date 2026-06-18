// lib/core/widgets/app_drawer.dart
// 🔥 店家前台共用左側選單 Drawer：會員資訊、前台功能、後台入口、系統功能

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_faq_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_intro_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.shopId,
    this.platformPreview = false,
  });

  final String shopId;
  final bool platformPreview;

  Color get _orange => const Color(0xFFFF8A3D);
  Color get _brown => const Color(0xFF4A2C18);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 16),

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
                            builder: (_) => LoginPage(redirectShopId: shopId),
                          ),
                        );
                      } else {
                        Navigator.pushNamed(context, '/member');
                      }
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
                          builder: (_) => MyBookingsPage(returnShopId: shopId),
                        ),
                      );
                    },
                  ),

                  if (user != null) _latestBookingCard(context, user.uid),

                  _divider(),
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
                        leading: Icon(Icons.pets, color: _orange, size: 18),
                        title: Text(
                          '店家功能',
                          style: TextStyle(
                            color: _brown,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: [
                          _menuItem(
                            icon: Icons.calendar_month,
                            title: '我要預約',
                            onTap: () => _goBooking(context),
                          ),
                          _menuItem(
                            icon: Icons.home,
                            title: '環境介紹',
                            onTap: () {
                              Navigator.pop(context);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ShopEnvironmentPage(shopId: shopId),
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
                                  builder: (_) =>
                                      ShopRoomIntroPage(shopId: shopId),
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
                                  builder: (_) => ShopAboutPage(shopId: shopId),
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
                                    builder: (_) =>
                                        ShopAnnouncementPage(shopId: shopId),
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
                                    builder: (_) => ShopFaqPage(shopId: shopId),
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

            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF5E8), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: user == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFFFFE5C8),
                  child: Icon(Icons.pets, color: _orange, size: 34),
                ),
                const SizedBox(height: 14),
                Text(
                  '尚未登入',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _brown,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '登入後可查看訂單與寵物資料',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
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
                    child: const Text('登入 / 註冊'),
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
                final name = data?['name'] ?? '';
                final phone = data?['phone'] ?? '';

                return Stack(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: const Color(0xFFFFE5C8),
                          child: Icon(Icons.pets, color: _orange, size: 34),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isNotEmpty ? name : '會員',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: _brown,
                                ),
                              ),

                              const SizedBox(height: 5),

                              if (phone.toString().isNotEmpty)
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),

                              const SizedBox(height: 4),

                              Text(
                                user.email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.home_rounded),
                        color: _orange,
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
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Icon(Icons.pets, color: _orange, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: _brown,
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor ?? Colors.black54, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: showArrow
          ? const Icon(Icons.chevron_right, color: Colors.black38)
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
              color: const Color(0xFFFFF7EF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFD8B0)),
            ),
            child: const Text(
              '目前沒有最新訂單',
              style: TextStyle(fontSize: 13, color: Colors.black54),
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

        Color statusColor = const Color(0xFFFF8A3D);

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
            margin: const EdgeInsets.only(top: 8, bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8F1), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD2AA)),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.08),
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
                        fontSize: 15,
                      ),
                    ),

                    const Spacer(),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
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
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(14),
                        image: roomImage != null
                            ? DecorationImage(
                                image: NetworkImage(roomImage),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: roomImage == null
                          ? const Icon(
                              Icons.home_work_rounded,
                              color: Colors.black26,
                              size: 34,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),

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
                                    const Icon(
                                      Icons.storefront,
                                      size: 14,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        shopName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 4),

                              Text(
                                '$roomTypeName $roomName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                size: 17,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$startDate - $endDate ($nights晚)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Row(
                            children: [
                              const Icon(
                                Icons.payments_outlined,
                                size: 17,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 6),

                              Text(
                                'NT\$ $totalPrice',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
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
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              if (hasDeposit)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
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
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                              if (customerUnreadMessageCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
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
                                      fontSize: 12,
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

                const SizedBox(height: 14),

                Container(height: 1, color: Colors.orange.shade100),

                const SizedBox(height: 12),

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
                          color: _orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: _orange),
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
      child: Divider(color: Colors.grey.shade200, thickness: 1),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Row(
        children: [
          Icon(Icons.pets, color: _orange, size: 30),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PetNest 寵物旅社',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 3),
                Text(
                  '用心・專業・愛護每一位毛孩 ❤',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
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

    final hasAccepted = await ShopService.instance.hasAcceptedPolicy(
      shopId: shopId,
      userId: user.uid,
    );

    if (!hasAccepted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopPolicyViewPage(shopId: shopId)),
      );

      if (result != true) return;
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShopBookingPage(shopId: shopId)),
    );
  }
}
