// lib/features/platform/pages/platform_shop_manage_page.dart
// 🏪 平台店家管理頁
// 功能：平台後台查看所有店家，管理公開狀態、方案、付款期限與店家狀態

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/services/platform_admin_service.dart';
import 'package:petnest_saas/features/platform/widgets/platform_shop_stat_card.dart';
import 'package:petnest_saas/features/platform/widgets/platform_shop_status_pill.dart';
import 'package:petnest_saas/features/platform/widgets/platform_shop_info_pill.dart';
import 'package:petnest_saas/features/platform/widgets/platform_shop_metric_card.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_send_shop_notification_page.dart';
import 'package:petnest_saas/features/platform/widgets/shop_plan_manage_dialog.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_device_manage_page.dart';

class PlatformShopManagePage extends StatelessWidget {
  const PlatformShopManagePage({super.key});
  String _formatDate(dynamic value) {
    if (value == null) return '尚未設定';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '尚未設定';

    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) {
      return '剛剛';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分鐘前';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}小時前';
    }

    if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    }

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }

  String _planLabel(String value) {
    switch (value) {
      case 'free':
        return '免費版';
      case 'basic':
        return '基本版';
      case 'pro':
        return '專業版';
      case 'premium':
        return '旗艦版';
      default:
        return '未設定';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return '正常';
      case 'suspended':
        return '停權';
      case 'pending':
        return '待審核';
      default:
        return '未知';
    }
  }

  List<String> _normalizeModulesByPlan({
    required String plan,
    required List<String> currentModules,
  }) {
    final baseModules = <String>['basic_info'];

    final mainModules = currentModules
        .where((item) => item != 'basic_info' && item != 'reports')
        .toList();

    if (plan == 'free') {
      return baseModules;
    }

    if (plan == 'basic') {
      if (mainModules.isEmpty) {
        return baseModules;
      }

      return [...baseModules, mainModules.first];
    }

    return currentModules.isEmpty ? baseModules : currentModules;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<bool>>(
      future: Future.wait<bool>([
        PlatformAdminService.instance.hasPermission(
          PlatformPermissionKeys.viewShops,
        ),
        PlatformAdminService.instance.hasPermission(
          PlatformPermissionKeys.manageShopStatus,
        ),
        PlatformAdminService.instance.hasPermission(
          PlatformPermissionKeys.manageShopSubscriptions,
        ),
      ]),
      builder: (context, permissionSnapshot) {
        if (permissionSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final permissions =
            permissionSnapshot.data ?? const <bool>[false, false, false];

        final canViewShops = permissions[0];
        final canManageShopStatus = permissions[1];
        final canManageShopSubscriptions = permissions[2];

        final canAccess =
            canViewShops || canManageShopStatus || canManageShopSubscriptions;

        if (!canAccess) {
          return const Scaffold(body: Center(child: Text('你沒有店家管理權限')));
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: AppBar(title: const Text('店家管理')),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              final totalShops = docs.length;

              final activeShops = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'active';
              }).length;

              final suspendedShops = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'suspended';
              }).length;

              final trialShops = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final plan = data['plan']?.toString() ?? 'free';

                return plan == 'free';
              }).length;
              if (docs.isEmpty) {
                return const Center(child: Text('目前沒有店家'));
              }

              return ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      PlatformShopStatCard(
                        icon: Icons.storefront,
                        title: '全部店家',
                        value: totalShops,
                        subtitle: '所有已註冊店家',
                        color: Colors.blue,
                      ),
                      PlatformShopStatCard(
                        icon: Icons.verified,
                        title: '正常營運',
                        value: activeShops,
                        subtitle: '公開中店家',
                        color: Colors.green,
                      ),
                      PlatformShopStatCard(
                        icon: Icons.schedule,
                        title: '試用中',
                        value: trialShops,
                        subtitle: '免費方案店家',
                        color: Colors.orange,
                      ),
                      PlatformShopStatCard(
                        icon: Icons.block,
                        title: '已停權',
                        value: suspendedShops,
                        subtitle: '已停權店家',
                        color: Colors.red,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  ...List.generate(docs.length, (index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final name = data['name']?.toString() ?? '未命名店家';
                    final city = data['city']?.toString() ?? '';
                    final district = data['district']?.toString() ?? '';
                    final logoUrl =
                        data['platformHomeLogoUrl']?.toString().isNotEmpty ==
                            true
                        ? data['platformHomeLogoUrl'].toString()
                        : data['logoUrl']?.toString() ?? '';
                    final isPublic = data['isPublic'] == true;
                    final licenseVerified = data['licenseVerified'] == true;
                    final taxIdVerified = data['taxIdVerified'] == true;
                    final externalLinksEnabled =
                        data['externalLinksEnabled'] != false;
                    final plan = data['plan']?.toString() ?? 'free';
                    final enabledModules = List<String>.from(
                      data['enabledModules'] ?? [],
                    );
                    final status = data['status']?.toString() ?? 'active';
                    final accountStatus =
                        data['accountStatus']?.toString() ?? 'normal';
                    final paidUntil = data['paidUntil'];

                    DateTime? paidUntilDate;

                    if (paidUntil is Timestamp) {
                      paidUntilDate = paidUntil.toDate();
                    } else if (paidUntil is DateTime) {
                      paidUntilDate = paidUntil;
                    }

                    final isExpired =
                        paidUntilDate != null &&
                        paidUntilDate.isBefore(DateTime.now());

                    final createdAt = data['createdAt'];
                    final ownerUid = data['ownerUid']?.toString() ?? '';
                    final acceptedShopOwnerPolicyVersion =
                        data['acceptedShopOwnerPolicyVersion'] ?? 0;
                    final activationCode =
                        data['activationCode']?.toString() ?? '';
                    final planStatus = status == 'suspended'
                        ? '已停權'
                        : plan == 'free'
                        ? '免費版'
                        : isExpired
                        ? '已到期\n免費版權限'
                        : '付費中';
                    return Card(
                      elevation: 0,
                      color: status == 'suspended'
                          ? const Color(0xFFFFFBFB)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: status == 'suspended'
                              ? Colors.red.shade100
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF3FF),
                                    borderRadius: BorderRadius.circular(18),
                                    image: logoUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(logoUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: logoUrl.isNotEmpty
                                      ? null
                                      : Center(
                                          child: Text(
                                            name.isEmpty
                                                ? '?'
                                                : name.substring(0, 1),
                                            style: const TextStyle(
                                              color: Color(0xFF1565C0),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 22,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              '$city $district',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        'Shop ID：${doc.id}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    PlatformShopStatusPill(
                                      label: _statusLabel(status),
                                      color: _statusColor(status),
                                    ),

                                    if (accountStatus == 'restricted') ...[
                                      const SizedBox(height: 6),
                                      const PlatformShopStatusPill(
                                        label: '限制模式',
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  PlatformShopInfoPill(
                                    icon: Icons.visibility,
                                    label: isPublic ? '前台公開' : '前台隱藏',
                                  ),
                                  PlatformShopInfoPill(
                                    icon: Icons.verified_outlined,
                                    label: licenseVerified
                                        ? '特寵字號：已認證'
                                        : '特寵字號：未認證',
                                  ),
                                  PlatformShopInfoPill(
                                    icon: Icons.receipt_long_outlined,
                                    label: taxIdVerified ? '統編：已認證' : '統編：未認證',
                                  ),
                                  PlatformShopInfoPill(
                                    icon: Icons.workspace_premium,
                                    label: _planLabel(plan),
                                  ),
                                  PlatformShopInfoPill(
                                    icon: Icons.event,
                                    label: '到期：${_formatDate(paidUntil)}',
                                  ),
                                  PlatformShopInfoPill(
                                    icon: Icons.add_business,
                                    label: '建立：${_formatDate(createdAt)}',
                                  ),
                                  FutureBuilder<DocumentSnapshot>(
                                    future: ownerUid.isEmpty
                                        ? null
                                        : FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(ownerUid)
                                              .get(),
                                    builder: (context, userSnapshot) {
                                      final userData =
                                          userSnapshot.data?.data()
                                              as Map<String, dynamic>?;

                                      final lastLoginAt =
                                          userData?['lastLoginAt'];
                                      final lastActiveAt =
                                          userData?['lastActiveAt'];

                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          PlatformShopInfoPill(
                                            icon: Icons.login,
                                            label:
                                                '最後登入：${_formatDate(lastLoginAt)}',
                                          ),
                                          PlatformShopInfoPill(
                                            icon: Icons.access_time,
                                            label:
                                                '最後活躍：${_formatDate(lastActiveAt)}',
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  PlatformShopInfoPill(
                                    icon: Icons.article_outlined,
                                    label: acceptedShopOwnerPolicyVersion == 0
                                        ? '創店條款：未記錄'
                                        : '創店條款：v$acceptedShopOwnerPolicyVersion',
                                  ),
                                  if (activationCode.isNotEmpty)
                                    PlatformShopInfoPill(
                                      icon: Icons.key_outlined,
                                      label: '激活碼：$activationCode',
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.event_note,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '方案',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _planLabel(plan),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          planStatus,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: status == 'suspended'
                                                ? Colors.red
                                                : plan == 'free'
                                                ? Colors.orange
                                                : isExpired
                                                ? Colors.deepOrange
                                                : Colors.green,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: BorderSide(
                                        color: Colors.blue.shade200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: canManageShopSubscriptions
                                        ? () {
                                            showDialog(
                                              context: context,
                                              builder: (_) {
                                                return ShopPlanManageDialog(
                                                  shopId: doc.id,
                                                  shopName: name,
                                                  shop: data,
                                                );
                                              },
                                            );
                                          }
                                        : null,
                                    child: const Text('方案與權限管理'),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.public,
                                    size: 20,
                                    color: isPublic ? Colors.blue : Colors.grey,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isPublic ? '前台已公開' : '前台已隱藏',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: isPublic
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isPublic
                                              ? '此店家目前會顯示在平台找店'
                                              : '此店家目前不會顯示在平台找店',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isPublic,
                                    onChanged: canManageShopStatus
                                        ? (value) async {
                                            await FirebaseFirestore.instance
                                                .collection('shops')
                                                .doc(doc.id)
                                                .update({
                                                  'isPublic': value,
                                                  'updatedAt':
                                                      FieldValue.serverTimestamp(),
                                                });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: externalLinksEnabled
                                    ? const Color(0xFFF9FAFB)
                                    : const Color(0xFFFFF7F7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: externalLinksEnabled
                                      ? Colors.grey.shade200
                                      : Colors.red.shade100,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.link_off,
                                    size: 20,
                                    color: externalLinksEnabled
                                        ? Colors.blue
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          externalLinksEnabled
                                              ? '外部連結已啟用'
                                              : '外部連結已關閉',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: externalLinksEnabled
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          externalLinksEnabled
                                              ? 'IG / FB / LINE 等外部連結目前可顯示'
                                              : '此店家的外部連結目前已被平台關閉',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: externalLinksEnabled,
                                    onChanged: canManageShopStatus
                                        ? (value) async {
                                            await FirebaseFirestore.instance
                                                .collection('shops')
                                                .doc(doc.id)
                                                .update({
                                                  'externalLinksEnabled': value,
                                                  'updatedAt':
                                                      FieldValue.serverTimestamp(),
                                                });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.78,
                              children: [
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('bookings')
                                      .where('shopId', isEqualTo: doc.id)
                                      .snapshots(),
                                  builder: (context, bookingSnapshot) {
                                    final bookingDocs =
                                        bookingSnapshot.data?.docs ?? [];

                                    final now = DateTime.now();
                                    final monthStart = DateTime(
                                      now.year,
                                      now.month,
                                      1,
                                    );

                                    final monthCount = bookingDocs.where((
                                      bookingDoc,
                                    ) {
                                      final bookingData =
                                          bookingDoc.data()
                                              as Map<String, dynamic>;
                                      final createdAt =
                                          bookingData['createdAt'];

                                      if (createdAt is! Timestamp) return false;

                                      return createdAt.toDate().isAfter(
                                        monthStart,
                                      );
                                    }).length;

                                    return PlatformShopMetricCard(
                                      icon: Icons.receipt_long,
                                      title: '訂單總數',
                                      value: bookingDocs.length.toString(),
                                      subtitle: '本月 $monthCount 筆',
                                      iconColor: Colors.green,
                                    );
                                  },
                                ),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(doc.id)
                                      .collection('members')
                                      .snapshots(),
                                  builder: (context, memberSnapshot) {
                                    final memberDocs =
                                        memberSnapshot.data?.docs ?? [];

                                    final now = DateTime.now();
                                    final monthStart = DateTime(
                                      now.year,
                                      now.month,
                                      1,
                                    );

                                    final monthCount = memberDocs.where((
                                      memberDoc,
                                    ) {
                                      final memberData =
                                          memberDoc.data()
                                              as Map<String, dynamic>;
                                      final createdAt = memberData['createdAt'];

                                      if (createdAt is! Timestamp) return false;

                                      return createdAt.toDate().isAfter(
                                        monthStart,
                                      );
                                    }).length;

                                    return PlatformShopMetricCard(
                                      icon: Icons.people_alt_outlined,
                                      title: '會員數',
                                      value: memberDocs.length.toString(),
                                      subtitle: '本月新增 $monthCount 人',
                                      iconColor: Colors.orange,
                                    );
                                  },
                                ),
                                PlatformShopMetricCard(
                                  icon: Icons.image_outlined,
                                  title: '媒體容量',
                                  value: '未統計',
                                  subtitle: '之後統計',
                                  iconColor: Colors.purple,
                                ),
                                PlatformShopMetricCard(
                                  icon: Icons.public,
                                  title: '前台公開',
                                  value: isPublic ? '已公開' : '已隱藏',
                                  subtitle: isPublic ? '目前可被搜尋' : '目前不顯示',
                                  iconColor: Colors.blue,
                                  valueColor: isPublic
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: BorderSide(
                                        color: Colors.blue.shade200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () {},
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      '管理',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF4B5563),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () {},
                                    icon: const Icon(
                                      Icons.dashboard_customize_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      '模組設定',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blueGrey,
                                      side: BorderSide(
                                        color: Colors.blueGrey.shade200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: canManageShopStatus
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PlatformShopDeviceManagePage(
                                                      shopId: doc.id,
                                                      shopName: name,
                                                    ),
                                              ),
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.sensors, size: 18),
                                    label: const Text(
                                      '設備管理',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: BorderSide(
                                        color: Colors.green.shade200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ShopPublicPage(
                                            shopId: doc.id,
                                            platformPreview: true,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      '查看前台',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                const SizedBox(height: 8),

                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                      side: BorderSide(
                                        color: Colors.orange.shade200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PlatformSendShopNotificationPage(
                                                shopId: doc.id,
                                                shopName: name,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.notifications_active_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      '通知店家',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: status == 'suspended'
                                          ? Colors.green
                                          : Colors.red,
                                      side: BorderSide(
                                        color: status == 'suspended'
                                            ? Colors.green.shade200
                                            : Colors.red.shade200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: canManageShopStatus
                                        ? () async {
                                            final nextStatus =
                                                status == 'suspended'
                                                ? 'active'
                                                : 'suspended';

                                            await FirebaseFirestore.instance
                                                .collection('shops')
                                                .doc(doc.id)
                                                .update({
                                                  'status': nextStatus,
                                                  'updatedAt':
                                                      FieldValue.serverTimestamp(),
                                                });
                                          }
                                        : null,
                                    icon: Icon(
                                      status == 'suspended'
                                          ? Icons.check_circle_outline
                                          : Icons.block,
                                      size: 18,
                                    ),
                                    label: Text(
                                      status == 'suspended' ? '解除停權' : '停權店家',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ), // StreamBuilder
        ); // Scaffold
      },
    ); // FutureBuilder
  }
}
