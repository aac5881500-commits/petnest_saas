// 檔案名稱：lib/features/platform/pages/platform_admin_page.dart
// 功能說明：平台管理入口，包含店家管理、方案付款、平台操作紀錄。
// 🛠️ 平台後台主頁
// 進入頁面前會透過 PlatformAdminService 驗證平台人員身分與啟用狀態。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/constants/platform_root_admin.dart';
import '../../../core/models/platform_admin_model.dart';
import '../../../core/services/platform_admin_service.dart';
import 'platform_account_delete_request_page.dart';
import 'platform_activation_code_manage_page.dart';
import 'platform_contact_request_list_page.dart';
import 'platform_member_manage_page.dart';
import 'platform_payment_review_page.dart';
import 'platform_policy_manage_page.dart';
import 'platform_review_manage_page.dart';
import 'platform_shop_manage_page.dart';
import 'platform_shop_request_manage_page.dart';
import 'platform_user_management_page.dart';

class PlatformAdminPage extends StatelessWidget {
  const PlatformAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlatformAdminModel?>(
      future: PlatformAdminService.instance.getCurrentAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF6F7FB),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F7FB),
            appBar: AppBar(title: const Text('平台後台')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '讀取平台權限失敗：${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final currentAdmin = snapshot.data;

        final isRootAdmin = PlatformRootAdmin.isRoot(
          PlatformAdminService.instance.currentUserId,
        );

        bool hasPermission(String permission) {
          return isRootAdmin ||
              PlatformAdminService.instance.adminHasPermission(
                currentAdmin,
                permission,
              );
        }

        bool hasAnyPermission(List<String> permissions) {
          return permissions.any(hasPermission);
        }

        final canAccess =
            isRootAdmin || (currentAdmin != null && currentAdmin.enabled);

        if (!canAccess) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F7FB),
            appBar: AppBar(title: const Text('平台後台')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 56, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      '你沒有平台後台使用權限',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('此帳號不是平台人員，或平台帳號目前已被停用。', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: AppBar(title: const Text('平台後台')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _AdminSectionTitle(icon: Icons.storefront, title: '店家管理'),

              if (hasAnyPermission([
                PlatformPermissionKeys.viewShops,
                PlatformPermissionKeys.manageShopStatus,
                PlatformPermissionKeys.manageShopSubscriptions,
              ])) ...[
                _AdminEntryCard(
                  icon: Icons.storefront,
                  title: '店家管理',
                  subtitle: '管理公開狀態、停權、方案與付款到期日',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlatformShopManagePage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              if (hasPermission(PlatformPermissionKeys.reviewShopRequests)) ...[
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('shop_change_requests')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;

                    return _AdminEntryCard(
                      icon: Icons.approval_outlined,
                      title: '店家申請中心',
                      subtitle: '審核店家資料修改、認證與公開申請',
                      badgeCount: count,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PlatformShopRequestManagePage(),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (hasPermission(
                PlatformPermissionKeys.manageSupportRequests,
              )) ...[
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('platform_contact_requests')
                      .where('status', isEqualTo: 'open')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;

                    return _AdminEntryCard(
                      icon: Icons.support_agent,
                      title: '聯絡平台案件',
                      subtitle: '查看店主送出的問題、需求與回報紀錄',
                      badgeCount: count,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PlatformContactRequestListPage(),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              const _AdminSectionTitle(icon: Icons.payments, title: '方案與收費'),

              // 💳 顯示等待平台審核的綠界金流申請數量
              if (hasAnyPermission([
                PlatformPermissionKeys.viewPaymentStatus,
                PlatformPermissionKeys.reviewPaymentApplications,
              ])) ...[
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .where(
                        'paymentSetting.reviewStatus',
                        isEqualTo: 'pending',
                      )
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;

                    return _AdminEntryCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: '綠界金流審核中心',
                      subtitle: '審核店家綠界申請、付款方式與金流啟用狀態',
                      badgeCount: count,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PlatformPaymentReviewPage(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],

              const SizedBox(height: 12),

              if (hasPermission(
                PlatformPermissionKeys.manageShopSubscriptions,
              )) ...[
                _AdminEntryCard(
                  icon: Icons.payments,
                  title: '方案 / 付款管理',
                  subtitle: '之後管理月費方案、付款期限與功能開關',
                  onTap: () {},
                ),
              ],

              const SizedBox(height: 12),

              if (hasPermission(
                PlatformPermissionKeys.manageActivationCodes,
              )) ...[
                _AdminEntryCard(
                  icon: Icons.key_outlined,
                  title: '激活碼管理',
                  subtitle: '建立創店激活碼、查看使用次數與啟用狀態',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PlatformActivationCodeManagePage(),
                      ),
                    );
                  },
                ),
              ],

              const _AdminSectionTitle(
                icon: Icons.people_alt_outlined,
                title: '會員管理',
              ),

              if (hasAnyPermission([
                PlatformPermissionKeys.viewPlatformMembers,
                PlatformPermissionKeys.managePlatformMembers,
              ])) ...[
                _AdminEntryCard(
                  icon: Icons.people_alt_outlined,
                  title: '平台會員管理',
                  subtitle: '管理平台會員、封鎖狀態與平台備註',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlatformMemberManagePage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (hasPermission(
                PlatformPermissionKeys.manageAccountDeleteRequests,
              )) ...[
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('account_delete_requests')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;

                    return _AdminEntryCard(
                      icon: Icons.delete_outline,
                      title: '帳號刪除申請',
                      subtitle: '查看會員刪除帳號申請與處理狀態',
                      badgeCount: count,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PlatformAccountDeleteRequestPage(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],

              const _AdminSectionTitle(
                icon: Icons.settings_outlined,
                title: '平台設定',
              ),

              const SizedBox(height: 12),

              if (hasPermission(
                PlatformPermissionKeys.managePlatformAdmins,
              )) ...[
                _AdminEntryCard(
                  icon: Icons.admin_panel_settings_outlined,
                  title: '平台人員與權限',
                  subtitle: '新增平台員工、分配個別權限與停用帳號',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlatformUserManagementPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              if (hasPermission(
                PlatformPermissionKeys.managePlatformReviews,
              )) ...[
                _AdminEntryCard(
                  icon: Icons.rate_review_outlined,
                  title: '評價管理',
                  subtitle: '查看全平台評價、店家回覆與處理不當評論',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlatformReviewManagePage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 12),

              if (hasPermission(
                PlatformPermissionKeys.managePlatformPolicies,
              )) ...[
                _AdminEntryCard(
                  icon: Icons.article_outlined,
                  title: '平台條款管理',
                  subtitle: '管理平台會員條款與創店主條款版本',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlatformPolicyManagePage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              if (hasPermission(PlatformPermissionKeys.viewPlatformLogs)) ...[
                _AdminEntryCard(
                  icon: Icons.history,
                  title: '平台操作紀錄',
                  subtitle: '之後查看誰修改店家、方案、停權狀態',
                  onTap: () {},
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AdminSectionTitle extends StatelessWidget {
  const _AdminSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminEntryCard extends StatelessWidget {
  const _AdminEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount,
  });

  final int? badgeCount;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF3FF),
          child: Icon(icon, color: const Color(0xFF1565C0)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            if ((badgeCount ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${badgeCount!}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
