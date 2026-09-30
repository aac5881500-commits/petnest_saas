// 檔案名稱：lib/features/platform/pages/platform_shop_manage_page.dart
// 功能說明：平台後台查看所有店家，管理公開狀態、方案、付款期限與店家狀態
// 🏪 平台店家管理頁
// 桌機為左側清單＋右側工作區；手機／平板為摘要清單＋詳細頁。
// 資料、權限、統計與按鈕行為維持同一套。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/widgets/app_state_panel.dart';

import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/constants/platform_root_admin.dart';
import '../../../core/services/platform_admin_service.dart';

import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_send_shop_notification_page.dart';
import 'package:petnest_saas/features/platform/widgets/shop_plan_manage_dialog.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_device_manage_page.dart';
import 'package:petnest_saas/features/platform/widgets/platform_transfer_shop_owner_dialog.dart';

const Color _kPageBackground = Color(0xFFF6F7FB);
const Color _kCardBorder = Color(0xFFD7E0EA);
const Color _kInk = Color(0xFF111827);
const Color _kMuted = Color(0xFF6B7280);
const Color _kSelectedFill = Color(0xFFF3F8FF);
const Color _kSelectedLine = Color(0xFF2563EB);
const double _kDesktopBreakpoint = 1000;
const double _kContentMaxWidth = 1580;

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

        return _ShopManageScreen(
          canManageShopStatus: canManageShopStatus,
          canManageShopSubscriptions: canManageShopSubscriptions,
          formatDate: _formatDate,
          planLabel: _planLabel,
          statusLabel: _statusLabel,
          statusColor: _statusColor,
        );
      },
    );
  }
}

class _ShopManageScreen extends StatefulWidget {
  const _ShopManageScreen({
    required this.canManageShopStatus,
    required this.canManageShopSubscriptions,
    required this.formatDate,
    required this.planLabel,
    required this.statusLabel,
    required this.statusColor,
  });

  final bool canManageShopStatus;
  final bool canManageShopSubscriptions;
  final String Function(dynamic value) formatDate;
  final String Function(String value) planLabel;
  final String Function(String status) statusLabel;
  final Color Function(String status) statusColor;

  @override
  State<_ShopManageScreen> createState() => _ShopManageScreenState();
}

class _ShopManageScreenState extends State<_ShopManageScreen> {
  final Set<String> _busyShops = {};
  int _reload = 0;
  final TextEditingController _search = TextEditingController();
  String _statusFilter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? _desktopSelectedId;
  String? _mobileOpenId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(_reload),
      stream: FirebaseFirestore.instance
          .collection('shops')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: _kPageBackground,
            appBar: AppBar(title: const Text('店家管理')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('店家管理')),
            body: AppStatePanel(
              title: '店家資料暫時無法載入',
              message: '請確認網路連線後重試。若持續失敗，請確認帳號的管理權限。',
              onRetry: () => setState(() => _reload++),
            ),
          );
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
          return Scaffold(
            backgroundColor: _kPageBackground,
            appBar: AppBar(title: const Text('店家管理')),
            body: const AppStatePanel(
              title: '目前沒有店家',
              message: '建立店家後，會在這裡顯示店家狀態與管理功能。',
              icon: Icons.storefront_outlined,
            ),
          );
        }

        final allShops = [
          for (final doc in docs)
            _readShop(
              context: context,
              shopId: doc.id,
              data: doc.data() as Map<String, dynamic>,
              canManageShopStatus: widget.canManageShopStatus,
              canManageShopSubscriptions: widget.canManageShopSubscriptions,
              formatDate: widget.formatDate,
              planLabel: widget.planLabel,
              statusLabel: widget.statusLabel,
              statusColor: widget.statusColor,
              busy: _busyShops.contains(doc.id),
              onWrite: _writeShop,
            ),
        ];

        final query = _search.text.trim().toLowerCase();
        final shops = allShops.where((shop) {
          final matchesStatus =
              _statusFilter == 'all' || shop.status == _statusFilter;
          final searchable =
              '${shop.name} ${shop.shopId} ${shop.location} ${shop.ownerUid}'
                  .toLowerCase();
          return matchesStatus && (query.isEmpty || searchable.contains(query));
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= _kDesktopBreakpoint;
            final mobileShop = desktop ? null : _shopById(shops, _mobileOpenId);
            final desktopShop =
                _shopById(shops, _desktopSelectedId) ??
                (shops.isEmpty ? null : shops.first);

            return PopScope(
              canPop: mobileShop == null,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop || _mobileOpenId == null) {
                  return;
                }
                setState(() => _mobileOpenId = null);
              },
              child: Scaffold(
                backgroundColor: _kPageBackground,
                appBar: AppBar(
                  title: Text(mobileShop?.name ?? '店家管理'),
                  leading: mobileShop == null
                      ? null
                      : BackButton(
                          onPressed: () => setState(() => _mobileOpenId = null),
                        ),
                ),
                body: Column(
                  children: [
                    if (mobileShop == null) _buildSearchBar(),
                    Expanded(
                      child: shops.isEmpty
                          ? const AppStatePanel(
                              title: '找不到符合條件的店家',
                              message: '試試其他店名、地區或店家編號，或切換狀態篩選。',
                              icon: Icons.search_off_outlined,
                            )
                          : desktop
                          ? _buildDesktopShopManager(
                              shops: shops,
                              selected: desktopShop!,
                              totalShops: totalShops,
                              activeShops: activeShops,
                              trialShops: trialShops,
                              suspendedShops: suspendedShops,
                              formatDate: widget.formatDate,
                              onSelect: (shopId) {
                                setState(() => _desktopSelectedId = shopId);
                              },
                            )
                          : mobileShop == null
                          ? _buildMobileShopList(
                              shops: shops,
                              totalShops: totalShops,
                              activeShops: activeShops,
                              trialShops: trialShops,
                              suspendedShops: suspendedShops,
                              onOpen: (shopId) {
                                setState(() {
                                  _mobileOpenId = shopId;
                                  _desktopSelectedId = shopId;
                                });
                              },
                            )
                          : _PlatformShopDetailPage(
                              shop: mobileShop,
                              formatDate: widget.formatDate,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _writeShop(
    String shopId,
    Map<String, dynamic> changes,
    String successMessage,
  ) async {
    if (_busyShops.contains(shopId) || !mounted) return;
    setState(() => _busyShops.add(shopId));
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('儲存失敗，請確認網路連線與管理權限後再試。')));
    } finally {
      if (mounted) setState(() => _busyShops.remove(shopId));
    }
  }

  Widget _buildSearchBar() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜尋店名、地區或店家編號',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜尋',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _search.clear()),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final option in const {
                      'all': '全部',
                      'active': '啟用中',
                      'pending': '待審核',
                      'suspended': '已停權',
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(option.value),
                          selected: _statusFilter == option.key,
                          onSelected: (_) =>
                              setState(() => _statusFilter = option.key),
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
}

_ShopVisual? _shopById(List<_ShopVisual> shops, String? shopId) {
  if (shopId == null) {
    return null;
  }
  for (final shop in shops) {
    if (shop.shopId == shopId) {
      return shop;
    }
  }
  return null;
}

_ShopVisual _readShop({
  required BuildContext context,
  required String shopId,
  required Map<String, dynamic> data,
  required bool canManageShopStatus,
  required bool canManageShopSubscriptions,
  required String Function(dynamic value) formatDate,
  required String Function(String value) planLabel,
  required String Function(String status) statusLabel,
  required Color Function(String status) statusColor,
  required bool busy,
  required Future<void> Function(String, Map<String, dynamic>, String) onWrite,
}) {
  final name = data['name']?.toString() ?? '未命名店家';
  final city = data['city']?.toString() ?? '';
  final district = data['district']?.toString() ?? '';
  final logoUrl = data['platformHomeLogoUrl']?.toString().isNotEmpty == true
      ? data['platformHomeLogoUrl'].toString()
      : data['logoUrl']?.toString() ?? '';
  final isPublic = data['isPublic'] == true;
  final licenseVerified = data['licenseVerified'] == true;
  final taxIdVerified = data['taxIdVerified'] == true;
  final externalLinksEnabled = data['externalLinksEnabled'] != false;
  final plan = data['plan']?.toString() ?? 'free';
  final status = data['status']?.toString() ?? 'active';
  final accountStatus = data['accountStatus']?.toString() ?? 'normal';
  final paidUntil = data['paidUntil'];

  DateTime? paidUntilDate;
  if (paidUntil is Timestamp) {
    paidUntilDate = paidUntil.toDate();
  } else if (paidUntil is DateTime) {
    paidUntilDate = paidUntil;
  }

  final isExpired =
      paidUntilDate != null && paidUntilDate.isBefore(DateTime.now());
  final createdAt = data['createdAt'];
  final ownerUid = data['ownerUid']?.toString() ?? '';
  final acceptedShopOwnerPolicyVersion =
      data['acceptedShopOwnerPolicyVersion'] ?? 0;
  final activationCode = data['activationCode']?.toString() ?? '';
  final planStatus = status == 'suspended'
      ? '已停權'
      : plan == 'free'
      ? '免費版'
      : isExpired
      ? '已到期，免費版權限'
      : '付費中';
  final planStatusColor = status == 'suspended'
      ? Colors.red
      : plan == 'free'
      ? Colors.orange
      : isExpired
      ? Colors.deepOrange
      : Colors.green;

  return _ShopVisual(
    shopId: shopId,
    name: name,
    logoUrl: logoUrl,
    location: '$city $district',
    ownerUid: ownerUid,
    status: status,
    statusLabel: statusLabel(status),
    statusColor: statusColor(status),
    restricted: accountStatus == 'restricted',
    suspended: status == 'suspended',
    showTransfer: PlatformRootAdmin.isRoot(
      FirebaseAuth.instance.currentUser?.uid,
    ),
    onTransfer: () {
      showDialog<bool>(
        context: context,
        builder: (_) {
          return PlatformTransferShopOwnerDialog(
            shopId: shopId,
            shopName: name,
            currentOwnerUid: ownerUid,
            previousOwnerUid: (data['previousOwnerUid'] ?? '').toString(),
          );
        },
      );
    },
    isPublic: isPublic,
    licenseVerified: licenseVerified,
    taxIdVerified: taxIdVerified,
    planName: planLabel(plan),
    expireLabel: '到期：${formatDate(paidUntil)}',
    createdLabel: '建立：${formatDate(createdAt)}',
    policyLabel: acceptedShopOwnerPolicyVersion == 0
        ? '創店條款：未記錄'
        : '創店條款：v$acceptedShopOwnerPolicyVersion',
    activationLabel: activationCode.isEmpty ? null : '激活碼：$activationCode',
    planStatus: planStatus,
    planStatusColor: planStatusColor,
    onManagePlan: canManageShopSubscriptions
        ? () {
            showDialog(
              context: context,
              builder: (_) {
                return ShopPlanManageDialog(
                  shopId: shopId,
                  shopName: name,
                  shop: data,
                );
              },
            );
          }
        : null,
    onPublicChanged: canManageShopStatus && !busy
        ? (value) async {
            await onWrite(shopId, {
              'isPublic': value,
            }, value ? '店家已公開' : '店家已隱藏');
          }
        : null,
    externalLinksEnabled: externalLinksEnabled,
    onExternalChanged: canManageShopStatus && !busy
        ? (value) async {
            await onWrite(shopId, {
              'externalLinksEnabled': value,
            }, value ? '外部連結已啟用' : '外部連結已關閉');
          }
        : null,
    onDevices: canManageShopStatus
        ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlatformShopDeviceManagePage(
                  shopId: shopId,
                  shopName: name,
                ),
              ),
            );
          }
        : null,
    onPreview: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShopPublicPage(shopId: shopId, platformPreview: true),
        ),
      );
    },
    onNotify: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PlatformSendShopNotificationPage(shopId: shopId, shopName: name),
        ),
      );
    },
    onToggleSuspend: canManageShopStatus && !busy
        ? () async {
            final nextStatus = status == 'suspended' ? 'active' : 'suspended';
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(nextStatus == 'suspended' ? '確認停權店家？' : '確認恢復店家？'),
                content: Text('店家：$name\n將變更店家的啟用狀態。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('確認'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            await onWrite(shopId, {
              'status': nextStatus,
            }, nextStatus == 'suspended' ? '店家已停權' : '店家已恢復');
          }
        : null,
  );
}

class _ShopVisual {
  const _ShopVisual({
    required this.shopId,
    required this.name,
    required this.logoUrl,
    required this.location,
    required this.ownerUid,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.restricted,
    required this.suspended,
    required this.showTransfer,
    required this.onTransfer,
    required this.isPublic,
    required this.licenseVerified,
    required this.taxIdVerified,
    required this.planName,
    required this.expireLabel,
    required this.createdLabel,
    required this.policyLabel,
    required this.activationLabel,
    required this.planStatus,
    required this.planStatusColor,
    required this.onManagePlan,
    required this.onPublicChanged,
    required this.externalLinksEnabled,
    required this.onExternalChanged,
    required this.onDevices,
    required this.onPreview,
    required this.onNotify,
    required this.onToggleSuspend,
  });

  final String shopId;
  final String name;
  final String logoUrl;
  final String location;
  final String ownerUid;
  final String status;
  final String statusLabel;
  final Color statusColor;
  final bool restricted;
  final bool suspended;
  final bool showTransfer;
  final VoidCallback onTransfer;
  final bool isPublic;
  final bool licenseVerified;
  final bool taxIdVerified;
  final String planName;
  final String expireLabel;
  final String createdLabel;
  final String policyLabel;
  final String? activationLabel;
  final String planStatus;
  final Color planStatusColor;
  final VoidCallback? onManagePlan;
  final ValueChanged<bool>? onPublicChanged;
  final bool externalLinksEnabled;
  final ValueChanged<bool>? onExternalChanged;
  final VoidCallback? onDevices;
  final VoidCallback onPreview;
  final VoidCallback onNotify;
  final VoidCallback? onToggleSuspend;

  String get publicShort => isPublic ? '前台公開' : '前台隱藏';
}

Widget _buildDesktopShopManager({
  required List<_ShopVisual> shops,
  required _ShopVisual selected,
  required int totalShops,
  required int activeShops,
  required int trialShops,
  required int suspendedShops,
  required String Function(dynamic value) formatDate,
  required ValueChanged<String> onSelect,
}) {
  return _DesktopFrame(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DesktopHeader(),
          const SizedBox(height: 12),
          _StatGrid(
            columns: 4,
            tileHeight: 104,
            total: totalShops,
            active: activeShops,
            trial: trialShops,
            suspended: suspendedShops,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 300,
                  child: _buildDesktopShopList(
                    shops: shops,
                    selectedId: selected.shopId,
                    onSelect: onSelect,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildDesktopShopWorkspace(
                    shop: selected,
                    formatDate: formatDate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DesktopFrame extends StatelessWidget {
  const _DesktopFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: child,
        ),
      ),
    );
  }
}

Widget _buildDesktopShopList({
  required List<_ShopVisual> shops,
  required String selectedId,
  required ValueChanged<String> onSelect,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _kCardBorder),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '所有店家',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                  ),
                ),
                Text(
                  '${shops.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kCardBorder),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              itemCount: shops.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final shop = shops[index];
                return _ShopListTile(
                  shop: shop,
                  selected: shop.shopId == selectedId,
                  onTap: () => onSelect(shop.shopId),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDesktopShopWorkspace({
  required _ShopVisual shop,
  required String Function(dynamic value) formatDate,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _kCardBorder),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          _ShopIdentityHeader(shop: shop, logoSize: 60),
          const SizedBox(height: 18),
          const _SectionLabel('營運概況'),
          const SizedBox(height: 8),
          _ShopMetricsGrid(shop: shop, tileHeight: 86),
          const SizedBox(height: 18),
          const _SectionLabel('方案與平台控制'),
          const SizedBox(height: 8),
          _PlanRow(shop: shop),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ToggleCard.public(shop, minHeight: 76)),
              const SizedBox(width: 12),
              Expanded(child: _ToggleCard.external(shop, minHeight: 76)),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('平台資料'),
          const SizedBox(height: 8),
          _ShopInfoChips(shop: shop, formatDate: formatDate),
          const SizedBox(height: 18),
          const _SectionLabel('店家操作'),
          const SizedBox(height: 8),
          _ShopActionGrid(shop: shop, buttonHeight: 48, gap: 12),
        ],
      ),
    ),
  );
}

Widget _buildMobileShopList({
  required List<_ShopVisual> shops,
  required int totalShops,
  required int activeShops,
  required int trialShops,
  required int suspendedShops,
  required ValueChanged<String> onOpen,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final bottom = MediaQuery.paddingOf(context).bottom;
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottom),
        children: [
          _StatGrid(
            columns: 2,
            tileHeight: 116,
            total: totalShops,
            active: activeShops,
            trial: trialShops,
            suspended: suspendedShops,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '所有店家',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ),
              Text(
                '${shops.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final shop in shops) ...[
            _ShopSummaryCard(shop: shop, onTap: () => onOpen(shop.shopId)),
            const SizedBox(height: 12),
          ],
        ],
      );
    },
  );
}

class _PlatformShopDetailPage extends StatelessWidget {
  const _PlatformShopDetailPage({required this.shop, required this.formatDate});

  final _ShopVisual shop;
  final String Function(dynamic value) formatDate;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottom),
      children: [
        _DetailSummaryCard(shop: shop),
        const SizedBox(height: 14),
        const _SectionLabel('營運概況'),
        const SizedBox(height: 8),
        _ShopMetricsGrid(shop: shop, tileHeight: 92),
        const SizedBox(height: 16),
        const _SectionLabel('方案與公開設定'),
        const SizedBox(height: 8),
        _PlanRow(shop: shop),
        const SizedBox(height: 10),
        _ToggleCard.public(shop, minHeight: 74),
        const SizedBox(height: 10),
        _ToggleCard.external(shop, minHeight: 74),
        const SizedBox(height: 16),
        _MorePlatformData(
          child: _ShopInfoChips(shop: shop, formatDate: formatDate),
        ),
        const SizedBox(height: 16),
        const _SectionLabel('店家操作'),
        const SizedBox(height: 8),
        _ShopActionGrid(shop: shop, buttonHeight: 48, gap: 10),
      ],
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 68,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '店家總覽',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _kInk,
                height: 1.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '管理店家狀態、方案、公開資訊與平台權限',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: _kMuted, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _kMuted,
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.columns,
    required this.tileHeight,
    required this.total,
    required this.active,
    required this.trial,
    required this.suspended,
  });

  final int columns;
  final double tileHeight;
  final int total;
  final int active;
  final int trial;
  final int suspended;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(
        icon: Icons.storefront,
        title: '全部店家',
        value: total,
        subtitle: '所有已註冊店家',
        color: Colors.blue,
      ),
      _StatTile(
        icon: Icons.verified,
        title: '正常營運',
        value: active,
        subtitle: '公開中店家',
        color: Colors.green,
      ),
      _StatTile(
        icon: Icons.schedule,
        title: '試用中',
        value: trial,
        subtitle: '免費方案店家',
        color: Colors.orange,
      ),
      _StatTile(
        icon: Icons.block,
        title: '已停權',
        value: suspended,
        subtitle: '已停權店家',
        color: Colors.red,
      ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      final end = i + columns < tiles.length ? i + columns : tiles.length;
      final slice = tiles.sublist(i, end);
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 12));
      }
      rows.add(
        SizedBox(
          height: tileHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(child: c < slice.length ? slice[c] : const SizedBox()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final int value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _kMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopListTile extends StatelessWidget {
  const _ShopListTile({
    required this.shop,
    required this.selected,
    required this.onTap,
  });

  final _ShopVisual shop;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kSelectedFill : const Color(0xFFFCFCFD),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF93C5FD) : _kCardBorder,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 86),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected ? _kSelectedLine : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ShopLogo(name: shop.name, logoUrl: shop.logoUrl, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _kInk,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _StatusPill(
                              label: shop.statusLabel,
                              color: shop.statusColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shop.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _kMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${shop.planName} · ${shop.publicShort}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopSummaryCard extends StatelessWidget {
  const _ShopSummaryCard({required this.shop, required this.onTap});

  final _ShopVisual shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kCardBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _ShopLogo(name: shop.name, logoUrl: shop.logoUrl, size: 46),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _kInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shop.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _kMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${shop.planName} · ${shop.publicShort}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _StatusPill(label: shop.statusLabel, color: shop.statusColor),
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
      ),
    );
  }
}

class _ShopIdentityHeader extends StatelessWidget {
  const _ShopIdentityHeader({required this.shop, required this.logoSize});

  final _ShopVisual shop;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final ownerText = shop.ownerUid.isEmpty ? '未設定' : shop.ownerUid;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ShopLogo(name: shop.name, logoUrl: shop.logoUrl, size: logoSize),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(label: shop.statusLabel, color: shop.statusColor),
                  if (shop.restricted) ...[
                    const SizedBox(width: 6),
                    const _StatusPill(label: '限制模式', color: Colors.orange),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                shop.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: _kMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Shop ID：${shop.shopId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              Text(
                'ownerUid：$ownerText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
        if (shop.showTransfer) ...[
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: shop.onTransfer,
            child: const Text(
              '轉移店主',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailSummaryCard extends StatelessWidget {
  const _DetailSummaryCard({required this.shop});

  final _ShopVisual shop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShopIdentityHeader(shop: shop, logoSize: 56),
            const SizedBox(height: 8),
            Text(
              '${shop.planName} · ${shop.publicShort}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.shop});

  final _ShopVisual shop;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E4F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_note,
              color: Color(0xFF1565C0),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  shop.planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shop.planStatus,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: shop.planStatusColor,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: shop.onManagePlan,
            child: const Text(
              '方案與權限管理',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.minHeight,
  });

  factory _ToggleCard.public(_ShopVisual shop, {required double minHeight}) {
    return _ToggleCard(
      icon: Icons.public,
      title: shop.isPublic ? '前台已公開' : '前台已隱藏',
      subtitle: shop.isPublic ? '此店家目前會顯示在平台找店' : '此店家目前不會顯示在平台找店',
      value: shop.isPublic,
      onChanged: shop.onPublicChanged,
      minHeight: minHeight,
    );
  }

  factory _ToggleCard.external(_ShopVisual shop, {required double minHeight}) {
    return _ToggleCard(
      icon: shop.externalLinksEnabled ? Icons.link : Icons.link_off,
      title: shop.externalLinksEnabled ? '外部連結已啟用' : '外部連結已關閉',
      subtitle: shop.externalLinksEnabled
          ? 'IG / FB / LINE 等外部連結目前可顯示'
          : '此店家的外部連結目前已被平台關閉',
      value: shop.externalLinksEnabled,
      onChanged: shop.onExternalChanged,
      minHeight: minHeight,
    );
  }

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final tone = value ? const Color(0xFF15803D) : const Color(0xFFDC2626);
    final fill = value ? const Color(0xFFF4FBF6) : const Color(0xFFFFF8F8);
    final border = value ? const Color(0xFFD1FAE5) : const Color(0xFFFECACA);
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tone,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kMuted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ShopInfoChips extends StatelessWidget {
  const _ShopInfoChips({required this.shop, required this.formatDate});

  final _ShopVisual shop;
  final String Function(dynamic value) formatDate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: shop.ownerUid.isEmpty
          ? null
          : FirebaseFirestore.instance
                .collection('users')
                .doc(shop.ownerUid)
                .get(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final lastLoginAt = userData?['lastLoginAt'];
        final lastActiveAt = userData?['lastActiveAt'];
        final chips = <_ChipSpec>[
          _ChipSpec(
            Icons.verified_outlined,
            shop.licenseVerified ? '特寵字號：已認證' : '特寵字號：未認證',
          ),
          _ChipSpec(
            Icons.receipt_long_outlined,
            shop.taxIdVerified ? '統編：已認證' : '統編：未認證',
          ),
          _ChipSpec(Icons.event, shop.expireLabel),
          _ChipSpec(Icons.add_business, shop.createdLabel),
          _ChipSpec(Icons.login, '最後登入：${formatDate(lastLoginAt)}'),
          _ChipSpec(Icons.access_time, '最後活躍：${formatDate(lastActiveAt)}'),
          _ChipSpec(Icons.article_outlined, shop.policyLabel),
          if (shop.activationLabel != null)
            _ChipSpec(Icons.key_outlined, shop.activationLabel!),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxText = constraints.maxWidth - 44 < 64
                ? 64.0
                : constraints.maxWidth - 44;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips)
                  _InfoChip(
                    icon: chip.icon,
                    label: chip.label,
                    maxTextWidth: maxText,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MorePlatformData extends StatefulWidget {
  const _MorePlatformData({required this.child});

  final Widget child;

  @override
  State<_MorePlatformData> createState() => _MorePlatformDataState();
}

class _MorePlatformDataState extends State<_MorePlatformData> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '更多平台資料',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: _kMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ShopMetricsGrid extends StatelessWidget {
  const _ShopMetricsGrid({required this.shop, required this.tileHeight});

  final _ShopVisual shop;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    return _metricGrid(
      tileHeight: tileHeight,
      orders: _OrdersMetric(shopId: shop.shopId),
      members: _MembersMetric(shopId: shop.shopId),
      media: const _MetricTile(
        icon: Icons.image_outlined,
        iconColor: Colors.purple,
        title: '媒體容量',
        value: '未統計',
        subtitle: '之後統計',
      ),
      visibility: _MetricTile(
        icon: Icons.public,
        iconColor: Colors.blue,
        title: '前台公開',
        value: shop.isPublic ? '已公開' : '已隱藏',
        subtitle: shop.isPublic ? '目前可被搜尋' : '目前不顯示',
        valueColor: shop.isPublic ? Colors.green : Colors.red,
      ),
    );
  }
}

Widget _metricGrid({
  required double tileHeight,
  required Widget orders,
  required Widget members,
  required Widget media,
  required Widget visibility,
}) {
  return Column(
    children: [
      SizedBox(
        height: tileHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: orders),
            const SizedBox(width: 10),
            Expanded(child: members),
          ],
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: tileHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: media),
            const SizedBox(width: 10),
            Expanded(child: visibility),
          ],
        ),
      ),
    ],
  );
}

class _ShopActionGrid extends StatelessWidget {
  const _ShopActionGrid({
    required this.shop,
    required this.buttonHeight,
    required this.gap,
  });

  final _ShopVisual shop;
  final double buttonHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final releasing = shop.status == 'suspended';
    final buttons = [
      _ShopActionButton(
        icon: Icons.sensors,
        label: '設備管理',
        onPressed: shop.onDevices,
      ),
      _ShopActionButton(
        icon: Icons.visibility_outlined,
        label: '查看前台',
        onPressed: shop.onPreview,
      ),
      _ShopActionButton(
        icon: Icons.notifications_active_outlined,
        label: '通知店家',
        onPressed: shop.onNotify,
      ),
    ];
    final suspend = _ShopActionButton(
      icon: releasing ? Icons.check_circle_outline : Icons.block,
      label: releasing ? '解除停權' : '停權店家',
      onPressed: shop.onToggleSuspend,
      foreground: releasing ? const Color(0xFF15803D) : const Color(0xFFDC2626),
      border: releasing ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
      background: releasing ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7F7),
    );
    final rows = <Widget>[];
    for (var i = 0; i < buttons.length; i += 2) {
      final right = i + 1 < buttons.length ? buttons[i + 1] : const SizedBox();
      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: gap));
      }
      rows.add(
        SizedBox(
          height: buttonHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: buttons[i]),
              SizedBox(width: gap),
              Expanded(child: right),
            ],
          ),
        ),
      );
    }
    rows.add(SizedBox(height: gap));
    rows.add(SizedBox(height: buttonHeight, child: suspend));
    return Column(children: rows);
  }
}

class _ShopLogo extends StatelessWidget {
  const _ShopLogo({
    required this.name,
    required this.logoUrl,
    required this.size,
  });

  final String name;
  final String logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(14),
        image: logoUrl.isNotEmpty
            ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: logoUrl.isNotEmpty
          ? null
          : Text(
              name.isEmpty ? '?' : name.substring(0, 1),
              style: TextStyle(
                color: const Color(0xFF1565C0),
                fontWeight: FontWeight.w800,
                fontSize: size * 0.38,
              ),
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class _ChipSpec {
  const _ChipSpec(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.maxTextWidth,
  });

  final IconData icon;
  final String label;
  final double maxTextWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 31),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _kMuted),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxTextWidth),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: valueColor ?? _kInk,
                height: 1.1,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersMetric extends StatelessWidget {
  const _OrdersMetric({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('shopId', isEqualTo: shopId)
          .snapshots(),
      builder: (context, bookingSnapshot) {
        final bookingDocs = bookingSnapshot.data?.docs ?? [];
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final monthCount = bookingDocs.where((bookingDoc) {
          final bookingData = bookingDoc.data() as Map<String, dynamic>;
          final createdAt = bookingData['createdAt'];
          if (createdAt is! Timestamp) return false;
          return createdAt.toDate().isAfter(monthStart);
        }).length;
        return _MetricTile(
          icon: Icons.receipt_long,
          iconColor: Colors.green,
          title: '訂單總數',
          value: bookingDocs.length.toString(),
          subtitle: '本月 $monthCount 筆',
        );
      },
    );
  }
}

class _MembersMetric extends StatelessWidget {
  const _MembersMetric({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .snapshots(),
      builder: (context, memberSnapshot) {
        final memberDocs = memberSnapshot.data?.docs ?? [];
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final monthCount = memberDocs.where((memberDoc) {
          final memberData = memberDoc.data() as Map<String, dynamic>;
          final createdAt = memberData['createdAt'];
          if (createdAt is! Timestamp) return false;
          return createdAt.toDate().isAfter(monthStart);
        }).length;
        return _MetricTile(
          icon: Icons.people_alt_outlined,
          iconColor: Colors.orange,
          title: '會員數',
          value: memberDocs.length.toString(),
          subtitle: '本月新增 $monthCount 人',
        );
      },
    );
  }
}

class _ShopActionButton extends StatelessWidget {
  const _ShopActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.foreground = const Color(0xFF374151),
    this.border = _kCardBorder,
    this.background = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color foreground;
  final Color border;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        disabledForegroundColor: const Color(0xFF9CA3AF),
        disabledBackgroundColor: const Color(0xFFF9FAFB),
        side: BorderSide(
          color: onPressed == null ? const Color(0xFFE5E7EB) : border,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
