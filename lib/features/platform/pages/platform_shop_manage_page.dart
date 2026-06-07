// lib/features/platform/pages/platform_shop_manage_page.dart
// 🏪 平台店家管理頁
// 功能：平台後台查看所有店家，管理公開狀態、方案、付款期限與店家狀態

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/platform/widgets/platform_shop_stat_card.dart';
import 'package:petnest_saas/features/platform/widgets/platform_shop_status_pill.dart';
import 'package:petnest_saas/features/platform/widgets/platform_shop_info_pill.dart';
import 'package:petnest_saas/features/platform/widgets/platform_shop_metric_card.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';

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
              Wrap(
                spacing: 12,
                runSpacing: 12,
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
                    data['platformHomeLogoUrl']?.toString().isNotEmpty == true
                    ? data['platformHomeLogoUrl'].toString()
                    : data['logoUrl']?.toString() ?? '';
                final isPublic = data['isPublic'] == true;
                final plan = data['plan']?.toString() ?? 'free';
                final enabledModules = List<String>.from(
                  data['enabledModules'] ?? [],
                );
                final status = data['status']?.toString() ?? 'active';
                final paidUntil = data['paidUntil'];
                final createdAt = data['createdAt'];
                final lastLoginAt = data['lastLoginAt'];
                final acceptedShopOwnerPolicyVersion =
                    data['acceptedShopOwnerPolicyVersion'] ?? 0;
                final activationCode = data['activationCode']?.toString() ?? '';
                final planStatus = status == 'suspended'
                    ? '已停權'
                    : plan == 'free'
                    ? '試用中'
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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

                            PlatformShopStatusPill(
                              label: _statusLabel(status),
                              color: _statusColor(status),
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
                              PlatformShopInfoPill(
                                icon: Icons.login,
                                label: '最後登入：${_formatDate(lastLoginAt)}',
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  side: BorderSide(color: Colors.blue.shade200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) {
                                      return AlertDialog(
                                        title: const Text('變更方案'),
                                        content: const Text(
                                          '正式版建議不要直接切換方案，之後這裡會改成：延長試用、人工續約、強制降級、開通測試權限。',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(dialogContext);
                                            },
                                            child: const Text('我知道了'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: const Text('變更方案'),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                onChanged: (value) async {
                                  await FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(doc.id)
                                      .update({
                                        'isPublic': value,
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                },
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
                          childAspectRatio: 1.15,
                          children: [
                            PlatformShopMetricCard(
                              icon: Icons.receipt_long,
                              title: '訂單總數',
                              value: '0',
                              subtitle: '本月 0 筆',
                              iconColor: Colors.green,
                            ),
                            PlatformShopMetricCard(
                              icon: Icons.people_alt_outlined,
                              title: '會員數',
                              value: '0',
                              subtitle: '本月新增 0 人',
                              iconColor: Colors.orange,
                            ),
                            PlatformShopMetricCard(
                              icon: Icons.image_outlined,
                              title: '媒體容量',
                              value: '未統計',
                              subtitle: '之後依圖片上傳紀錄計算',
                              iconColor: Colors.purple,
                            ),
                            PlatformShopMetricCard(
                              icon: Icons.public,
                              title: '前台公開',
                              value: isPublic ? '已公開' : '已隱藏',
                              subtitle: isPublic ? '目前可被搜尋' : '目前不顯示',
                              iconColor: Colors.blue,
                              valueColor: isPublic ? Colors.green : Colors.red,
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
                                  side: BorderSide(color: Colors.blue.shade200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {},
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text(
                                  '管理',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF4B5563),
                                  side: BorderSide(color: Colors.grey.shade300),
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
                                  style: TextStyle(fontWeight: FontWeight.w800),
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
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

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
                                onPressed: () async {
                                  final nextStatus = status == 'suspended'
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
                                },
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
      ),
    );
  }
}
