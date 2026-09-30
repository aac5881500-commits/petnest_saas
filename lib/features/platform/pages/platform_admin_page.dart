// 檔案名稱：lib/features/platform/pages/platform_admin_page.dart
// 功能說明：平台管理入口，包含店家管理、方案付款、平台操作紀錄。
// 🛠️ 平台後台主頁
// 進入頁面前會透過 PlatformAdminService 驗證平台人員身分與啟用狀態。
// 桌機（寬度 >= 900）與手機共用同一份入口、權限判斷與導頁。

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
import 'platform_media_library_page.dart';

const double _kDesktopBreakpoint = 900;
const double _kDesktopThreeColumnBreakpoint = 1200;
const double _kDesktopMaxWidth = 1480;
const double _kDesktopCardHeight = 132;

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
          body: _PlatformAdminBody(
            hasPermission: hasPermission,
            hasAnyPermission: hasAnyPermission,
          ),
        );
      },
    );
  }
}

class _PlatformAdminBody extends StatelessWidget {
  const _PlatformAdminBody({
    required this.hasPermission,
    required this.hasAnyPermission,
  });

  final bool Function(String permission) hasPermission;
  final bool Function(List<String> permissions) hasAnyPermission;

  @override
  Widget build(BuildContext context) {
    final sections = _platformAdminSections(
      openPage: (page) {
        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
      },
      hasPermission: hasPermission,
      hasAnyPermission: hasAnyPermission,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _kDesktopBreakpoint) {
          return _buildDesktopPlatformDashboard(
            context,
            sections,
            constraints.maxWidth,
          );
        }
        return _buildMobilePlatformDashboard(context, sections);
      },
    );
  }
}

class _PlatformBadgeStreams {
  const _PlatformBadgeStreams({
    required this.shopRequests,
    required this.contactRequests,
    required this.paymentReviews,
    required this.deleteRequests,
  });

  factory _PlatformBadgeStreams.live() {
    final firestore = FirebaseFirestore.instance;
    return _PlatformBadgeStreams(
      shopRequests: firestore
          .collection('shop_change_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      contactRequests: firestore
          .collection('platform_contact_requests')
          .where('status', isEqualTo: 'open')
          .snapshots(),
      paymentReviews: firestore
          .collection('shops')
          .where('paymentSetting.reviewStatus', isEqualTo: 'pending')
          .snapshots(),
      deleteRequests: firestore
          .collection('account_delete_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
    );
  }

  final Stream<QuerySnapshot<Map<String, dynamic>>> shopRequests;
  final Stream<QuerySnapshot<Map<String, dynamic>>> contactRequests;
  final Stream<QuerySnapshot<Map<String, dynamic>>> paymentReviews;
  final Stream<QuerySnapshot<Map<String, dynamic>>> deleteRequests;
}

class _PlatformEntry {
  const _PlatformEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeStream,
    this.sensitive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? badgeStream;
  final bool sensitive;
}

class _PlatformSection {
  const _PlatformSection({
    required this.icon,
    required this.title,
    required this.helper,
    required this.entries,
  });

  final IconData icon;
  final String title;
  final String helper;
  final List<_PlatformEntry> entries;
}

List<_PlatformSection> _platformAdminSections({
  required void Function(Widget page) openPage,
  required bool Function(String permission) hasPermission,
  required bool Function(List<String> permissions) hasAnyPermission,
  _PlatformBadgeStreams? badgeStreams,
}) {
  _PlatformBadgeStreams? cachedBadges;
  _PlatformBadgeStreams badges() {
    return cachedBadges ??= badgeStreams ?? _PlatformBadgeStreams.live();
  }

  final shopEntries = <_PlatformEntry>[
    if (hasAnyPermission([
      PlatformPermissionKeys.viewShops,
      PlatformPermissionKeys.manageShopStatus,
      PlatformPermissionKeys.manageShopSubscriptions,
    ]))
      _PlatformEntry(
        icon: Icons.storefront,
        title: '店家管理',
        subtitle: '管理公開狀態、停權、方案與付款到期日',
        onTap: () => openPage(const PlatformShopManagePage()),
      ),
    if (hasPermission(PlatformPermissionKeys.reviewShopRequests))
      _PlatformEntry(
        icon: Icons.approval_outlined,
        title: '店家申請中心',
        subtitle: '審核店家資料修改、認證與公開申請',
        badgeStream: badges().shopRequests,
        onTap: () => openPage(const PlatformShopRequestManagePage()),
      ),
    if (hasPermission(PlatformPermissionKeys.manageSupportRequests))
      _PlatformEntry(
        icon: Icons.support_agent,
        title: '聯絡平台案件',
        subtitle: '查看店主送出的問題、需求與回報紀錄',
        badgeStream: badges().contactRequests,
        onTap: () => openPage(const PlatformContactRequestListPage()),
      ),
  ];

  final billingEntries = <_PlatformEntry>[
    if (hasAnyPermission([
      PlatformPermissionKeys.viewPaymentStatus,
      PlatformPermissionKeys.reviewPaymentApplications,
    ]))
      _PlatformEntry(
        icon: Icons.account_balance_wallet_outlined,
        title: '綠界金流審核中心',
        subtitle: '審核店家綠界申請、付款方式與金流啟用狀態',
        badgeStream: badges().paymentReviews,
        onTap: () => openPage(const PlatformPaymentReviewPage()),
      ),
    if (hasPermission(PlatformPermissionKeys.manageShopSubscriptions))
      _PlatformEntry(
        icon: Icons.payments,
        title: '方案 / 付款管理',
        subtitle: '選擇店家，管理方案、付款期限與功能開關',
        onTap: () => openPage(const PlatformShopManagePage()),
      ),
    if (hasPermission(PlatformPermissionKeys.manageActivationCodes))
      _PlatformEntry(
        icon: Icons.key_outlined,
        title: '激活碼管理',
        subtitle: '建立創店激活碼、查看使用次數與啟用狀態',
        onTap: () => openPage(const PlatformActivationCodeManagePage()),
      ),
  ];

  final memberEntries = <_PlatformEntry>[
    if (hasAnyPermission([
      PlatformPermissionKeys.viewPlatformMembers,
      PlatformPermissionKeys.managePlatformMembers,
    ]))
      _PlatformEntry(
        icon: Icons.people_alt_outlined,
        title: '平台會員管理',
        subtitle: '管理平台會員、封鎖狀態與平台備註',
        onTap: () => openPage(const PlatformMemberManagePage()),
      ),
    if (hasPermission(PlatformPermissionKeys.manageAccountDeleteRequests))
      _PlatformEntry(
        icon: Icons.delete_outline,
        title: '帳號刪除申請',
        subtitle: '查看會員刪除帳號申請與處理狀態',
        badgeStream: badges().deleteRequests,
        sensitive: true,
        onTap: () => openPage(const PlatformAccountDeleteRequestPage()),
      ),
  ];

  final settingEntries = <_PlatformEntry>[
    if (hasPermission(PlatformPermissionKeys.managePlatformAdmins))
      _PlatformEntry(
        icon: Icons.admin_panel_settings_outlined,
        title: '平台人員與權限',
        subtitle: '新增平台員工、分配個別權限與停用帳號',
        sensitive: true,
        onTap: () => openPage(const PlatformUserManagementPage()),
      ),
    if (hasPermission(PlatformPermissionKeys.managePlatformMedia))
      _PlatformEntry(
        icon: Icons.collections_outlined,
        title: '外觀圖庫',
        subtitle: '上傳並管理店家可選用的頁面與卡片背景',
        onTap: () => openPage(const PlatformMediaLibraryPage()),
      ),
    if (hasPermission(PlatformPermissionKeys.managePlatformReviews))
      _PlatformEntry(
        icon: Icons.rate_review_outlined,
        title: '評價管理',
        subtitle: '查看全平台評價、店家回覆與處理不當評論',
        onTap: () => openPage(const PlatformReviewManagePage()),
      ),
    if (hasPermission(PlatformPermissionKeys.managePlatformPolicies))
      _PlatformEntry(
        icon: Icons.article_outlined,
        title: '平台條款管理',
        subtitle: '管理平台會員條款與創店主條款版本',
        onTap: () => openPage(const PlatformPolicyManagePage()),
      ),
  ];

  return [
    if (shopEntries.isNotEmpty)
      _PlatformSection(
        icon: Icons.storefront,
        title: '店家管理',
        helper: '店家狀態、申請與客服案件',
        entries: shopEntries,
      ),
    if (billingEntries.isNotEmpty)
      _PlatformSection(
        icon: Icons.payments,
        title: '方案與收費',
        helper: '金流審核、方案付款與激活碼',
        entries: billingEntries,
      ),
    if (memberEntries.isNotEmpty)
      _PlatformSection(
        icon: Icons.people_alt_outlined,
        title: '會員管理',
        helper: '會員資料與帳號刪除申請',
        entries: memberEntries,
      ),
    if (settingEntries.isNotEmpty)
      _PlatformSection(
        icon: Icons.settings_outlined,
        title: '平台設定',
        helper: '人員權限、圖庫、評價與條款',
        entries: settingEntries,
      ),
  ];
}

Widget _buildDesktopPlatformDashboard(
  BuildContext context,
  List<_PlatformSection> sections,
  double viewportWidth,
) {
  final inset = MediaQuery.paddingOf(context);
  final columns = viewportWidth >= _kDesktopThreeColumnBreakpoint ? 3 : 2;

  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kDesktopMaxWidth),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          32 + inset.left,
          12,
          32 + inset.right,
          32 + inset.bottom,
        ),
        children: [
          const _DesktopDashboardHeader(),
          if (sections.isEmpty)
            const _PlatformEmptyEntries()
          else
            for (var i = 0; i < sections.length; i++) ...[
              _PlatformSectionHeader(
                icon: sections[i].icon,
                title: sections[i].title,
                helper: sections[i].helper,
              ),
              const SizedBox(height: 8),
              _DesktopEntryGrid(entries: sections[i].entries, columns: columns),
              if (i != sections.length - 1) const SizedBox(height: 24),
            ],
        ],
      ),
    ),
  );
}

Widget _buildMobilePlatformDashboard(
  BuildContext context,
  List<_PlatformSection> sections,
) {
  final inset = MediaQuery.paddingOf(context);

  return ListView(
    padding: EdgeInsets.fromLTRB(
      16 + inset.left,
      12,
      16 + inset.right,
      24 + inset.bottom,
    ),
    children: [
      if (sections.isEmpty)
        const _PlatformEmptyEntries()
      else
        for (var i = 0; i < sections.length; i++) ...[
          _PlatformSectionHeader(
            icon: sections[i].icon,
            title: sections[i].title,
          ),
          const SizedBox(height: 8),
          for (var j = 0; j < sections[i].entries.length; j++) ...[
            _MobileEntryTile(entry: sections[i].entries[j]),
            if (j != sections[i].entries.length - 1) const SizedBox(height: 8),
          ],
          if (i != sections.length - 1) const SizedBox(height: 20),
        ],
    ],
  );
}

class _DesktopDashboardHeader extends StatelessWidget {
  const _DesktopDashboardHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 2, bottom: 14),
      child: SizedBox(
        height: 44,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '管理店家、收費、平台帳號與營運案件',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformEmptyEntries extends StatelessWidget {
  const _PlatformEmptyEntries();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          '目前沒有可使用的平台功能',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

class _PlatformSectionHeader extends StatelessWidget {
  const _PlatformSectionHeader({
    required this.icon,
    required this.title,
    this.helper,
  });

  final IconData icon;
  final String title;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final compact = helper == null;
    final titleStyle = TextStyle(
      fontSize: compact ? 14.5 : 15,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF111827),
      height: 1.2,
    );

    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );

    return SizedBox(
      height: compact ? 28 : 36,
      child: Row(
        children: [
          Icon(icon, size: compact ? 16 : 18, color: const Color(0xFF1565C0)),
          const SizedBox(width: 8),
          if (compact)
            Flexible(child: titleText)
          else ...[
            titleText,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                helper!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopEntryGrid extends StatelessWidget {
  const _DesktopEntryGrid({required this.entries, required this.columns});

  final List<_PlatformEntry> entries;
  final int columns;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    final rows = <Widget>[];

    for (var i = 0; i < entries.length; i += columns) {
      final end = i + columns < entries.length ? i + columns : entries.length;
      final slice = entries.sublist(i, end);
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: gap));
      }
      rows.add(
        SizedBox(
          height: _kDesktopCardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: gap),
                Expanded(
                  child: c < slice.length
                      ? _DesktopEntryCard(entry: slice[c])
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}

class _EntryTone {
  const _EntryTone({
    required this.iconColor,
    required this.iconBackground,
    required this.accent,
  });

  final Color iconColor;
  final Color iconBackground;
  final Color accent;

  static const standard = _EntryTone(
    iconColor: Color(0xFF1565C0),
    iconBackground: Color(0xFFEAF3FF),
    accent: Color(0xFF1D4ED8),
  );

  static const sensitive = _EntryTone(
    iconColor: Color(0xFF3730A3),
    iconBackground: Color(0xFFEEF2FF),
    accent: Color(0xFF4338CA),
  );

  factory _EntryTone.of(bool sensitive) {
    return sensitive ? _EntryTone.sensitive : standard;
  }
}

class _EntryIcon extends StatelessWidget {
  const _EntryIcon({
    required this.icon,
    required this.tone,
    required this.boxSize,
    required this.iconSize,
    this.radius,
  });

  final IconData icon;
  final _EntryTone tone;
  final double boxSize;
  final double iconSize;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boxSize,
      height: boxSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.iconBackground,
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius == null ? null : BorderRadius.circular(radius!),
      ),
      child: Icon(icon, size: iconSize, color: tone.iconColor),
    );
  }
}

class _PendingCountBadge extends StatelessWidget {
  const _PendingCountBadge({required this.stream});

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count <= 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopEntryCard extends StatefulWidget {
  const _DesktopEntryCard({required this.entry});

  final _PlatformEntry entry;

  @override
  State<_DesktopEntryCard> createState() => _DesktopEntryCardState();
}

class _DesktopEntryCardState extends State<_DesktopEntryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final tone = _EntryTone.of(entry.sensitive);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: _hover ? const Color(0xFFF7FAFF) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: _hover ? const Color(0xFF60A5FA) : const Color(0xFFD7E0EA),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A)
                .withValues(alpha: _hover ? 0.07 : 0.04),
            blurRadius: _hover ? 10 : 6,
            offset: Offset(0, _hover ? 3 : 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: entry.onTap,
          onHover: (hovering) {
            if (_hover == hovering) {
              return;
            }
            setState(() => _hover = hovering);
          },
          borderRadius: BorderRadius.circular(17),
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      _EntryIcon(
                        icon: entry.icon,
                        tone: tone,
                        boxSize: 36,
                        iconSize: 22,
                      ),
                      const Spacer(),
                      if (entry.badgeStream != null)
                        _PendingCountBadge(stream: entry.badgeStream!),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 20,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      entry.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 16,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '前往',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tone.accent,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: tone.accent,
                        ),
                      ],
                    ),
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

class _MobileEntryTile extends StatelessWidget {
  const _MobileEntryTile({required this.entry});

  final _PlatformEntry entry;

  @override
  Widget build(BuildContext context) {
    final tone = _EntryTone.of(entry.sensitive);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFD7E0EA)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              children: [
                _EntryIcon(
                  icon: entry.icon,
                  tone: tone,
                  boxSize: 42,
                  iconSize: 22,
                  radius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.badgeStream != null)
                  _PendingCountBadge(stream: entry.badgeStream!),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
List<({String title, List<String> entries})> debugPlatformAdminCatalog({
  required bool Function(String permission) hasPermission,
  required bool Function(List<String> permissions) hasAnyPermission,
}) {
  final empty = Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
  final sections = _platformAdminSections(
    openPage: (_) {},
    hasPermission: hasPermission,
    hasAnyPermission: hasAnyPermission,
    badgeStreams: _PlatformBadgeStreams(
      shopRequests: empty,
      contactRequests: empty,
      paymentReviews: empty,
      deleteRequests: empty,
    ),
  );

  return [
    for (final section in sections)
      (
        title: section.title,
        entries: [for (final entry in section.entries) entry.title],
      ),
  ];
}

@visibleForTesting
Widget debugPlatformAdminDashboardPreview() {
  final empty = Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
  final sections = _platformAdminSections(
    openPage: (_) {},
    hasPermission: (_) => true,
    hasAnyPermission: (_) => true,
    badgeStreams: _PlatformBadgeStreams(
      shopRequests: empty,
      contactRequests: empty,
      paymentReviews: empty,
      deleteRequests: empty,
    ),
  );

  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= _kDesktopBreakpoint) {
        return _buildDesktopPlatformDashboard(
          context,
          sections,
          constraints.maxWidth,
        );
      }
      return _buildMobilePlatformDashboard(context, sections);
    },
  );
}
