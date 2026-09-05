// 檔案名稱：lib/features/admin/pages/admin_point_redemption_list_page.dart
// 功能說明：顯示店家實體商品兌換紀錄、依狀態分類
// 🎁 後台實體商品領取核銷頁
// 使用領取碼搜尋，並讓店員確認完成商品交付。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/models/point_redemption_model.dart';
import 'package:petnest_saas/core/services/point_redemption_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class AdminPointRedemptionListPage extends StatefulWidget {
  const AdminPointRedemptionListPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminPointRedemptionListPage> createState() =>
      _AdminPointRedemptionListPageState();
}

class _AdminPointRedemptionListPageState
    extends State<AdminPointRedemptionListPage> {
  final TextEditingController _pickupCodeController = TextEditingController();

  final TextEditingController _memberSearchController = TextEditingController();

  PointRedemptionModel? _searchedRedemption;

  bool _isSearching = false;
  bool _isPickingUp = false;
  bool _isCancelling = false;
  bool _isMarkingExpired = false;

  bool _loadingPermission = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loadingPermission = false;
        _hasPermission = false;
      });
      return;
    }

    try {
      final Map<String, dynamic>? memberData = await ShopService.instance
          .getUserMemberInShop(shopId: widget.shopId, uid: user.uid);

      final bool hasPermission = ShopService.instance.hasPermission(
        memberData,
        ShopPermissionKeys.managePointRedemptions,
      );

      if (!mounted) return;

      setState(() {
        _loadingPermission = false;
        _hasPermission = hasPermission;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingPermission = false;
        _hasPermission = false;
      });
    }
  }

  @override
  void dispose() {
    _pickupCodeController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchPickupCode() async {
    final String pickupCode = _pickupCodeController.text.trim().toUpperCase();

    if (pickupCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先輸入領取碼')));
      return;
    }

    setState(() {
      _isSearching = true;
      _searchedRedemption = null;
    });

    try {
      final PointRedemptionModel? redemption = await PointRedemptionService
          .instance
          .findPendingByPickupCode(
            shopId: widget.shopId,
            pickupCode: pickupCode,
          );

      if (!mounted) return;

      setState(() {
        _searchedRedemption = redemption;
      });

      if (redemption == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('找不到此領取碼，或商品已經完成領取')));
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('搜尋領取碼失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _pickupCodeController.clear();

    setState(() {
      _searchedRedemption = null;
    });
  }

  List<PointRedemptionModel> _filterMemberSearch(
    List<PointRedemptionModel> redemptions,
  ) {
    final String keyword = _memberSearchController.text
        .trim()
        .toLowerCase()
        .replaceAll(' ', '');

    if (keyword.isEmpty) {
      return redemptions;
    }

    return redemptions.where((PointRedemptionModel redemption) {
      final String memberName = redemption.memberName
          .trim()
          .toLowerCase()
          .replaceAll(' ', '');

      final String memberPhone = redemption.memberPhone
          .trim()
          .toLowerCase()
          .replaceAll(' ', '')
          .replaceAll('-', '');

      final String pickupCode = redemption.pickupCode
          .trim()
          .toLowerCase()
          .replaceAll(' ', '');

      final String normalizedKeyword = keyword.replaceAll('-', '');

      return memberName.contains(keyword) ||
          memberPhone.contains(normalizedKeyword) ||
          pickupCode.contains(keyword);
    }).toList();
  }

  Future<void> _confirmPickup(PointRedemptionModel redemption) async {
    if (redemption.hasExpired) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此商品已超過領取期限，無法完成交付')));
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認完成商品交付'),
          content: Text(
            '請確認已將以下商品交付給會員：\n\n'
            '商品：${redemption.rewardName}\n'
            '會員：${_memberName(redemption)}\n'
            '領取碼：${redemption.pickupCode}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('完成交付'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isPickingUp = true;
    });

    try {
      await PointRedemptionService.instance.markAsPickedUp(
        shopId: widget.shopId,
        redemptionId: redemption.id,
      );

      if (!mounted) return;

      _pickupCodeController.clear();

      setState(() {
        _searchedRedemption = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商品已完成交付')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('完成商品交付失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isPickingUp = false;
        });
      }
    }
  }

  Future<void> _cancelRedemption(PointRedemptionModel redemption) async {
    final TextEditingController reasonController = TextEditingController();

    bool refundPoints = true;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                return AlertDialog(
                  title: const Text('取消商品兌換'),
                  content: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '商品：${redemption.rewardName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text('會員：${_memberName(redemption)}'),
                        const SizedBox(height: 16),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '取消原因',
                            hintText: '例如：會員主動取消兌換',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('退回兌換點數'),
                          subtitle: Text(
                            refundPoints
                                ? '將退回 ${redemption.pointsCost} 點給會員'
                                : '取消後不會退回點數',
                          ),
                          value: refundPoints,
                          onChanged: (bool value) {
                            setDialogState(() {
                              refundPoints = value;
                            });
                          },
                        ),
                        if (!refundPoints)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '注意：選擇不退點後，會員使用的 '
                              '${redemption.pointsCost} 點不會返還。',
                              style: TextStyle(color: Colors.orange.shade900),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('返回'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final String reason = reasonController.text.trim();

                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('請填寫取消原因')),
                          );
                          return;
                        }

                        Navigator.of(dialogContext).pop(<String, dynamic>{
                          'reason': reason,
                          'refundPoints': refundPoints,
                        });
                      },
                      child: const Text('確認取消'),
                    ),
                  ],
                );
              },
        );
      },
    );

    reasonController.dispose();

    if (result == null) return;

    final String reason = (result['reason'] as String?)?.trim() ?? '';

    final bool shouldRefundPoints = result['refundPoints'] == true;

    if (reason.isEmpty) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      await PointRedemptionService.instance.cancelRedemption(
        shopId: widget.shopId,
        redemptionId: redemption.id,
        reason: reason,
        refundPoints: shouldRefundPoints,
      );

      if (!mounted) return;

      _pickupCodeController.clear();

      setState(() {
        _searchedRedemption = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(shouldRefundPoints ? '兌換已取消，點數已退回會員' : '兌換已取消，本次未退回點數'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('取消兌換失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  Future<void> _markAsExpired(PointRedemptionModel redemption) async {
    if (!redemption.hasExpired) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此商品尚未超過領取期限')));
      return;
    }

    if (redemption.status != PointRedemptionStatus.pendingPickup) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('只有待領取商品可以標記過期')));
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認標記過期'),
          content: Text(
            '商品：${redemption.rewardName}\n'
            '會員：${_memberName(redemption)}\n'
            '領取碼：${redemption.pickupCode}\n\n'
            '標記過期後，會員將無法再領取此商品。\n'
            '目前不會自動退回點數。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('返回'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('確認標記過期'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isMarkingExpired = true;
    });

    try {
      await PointRedemptionService.instance.markAsExpired(
        shopId: widget.shopId,
        redemptionId: redemption.id,
      );

      if (!mounted) return;

      _pickupCodeController.clear();

      setState(() {
        _searchedRedemption = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商品已標記為過期')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('標記過期失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingExpired = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPermission) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('權限限制')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('你沒有實體商品核銷權限', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final String normalizedShopId = widget.shopId.trim();

    if (normalizedShopId.isEmpty) {
      return const Scaffold(body: Center(child: Text('找不到目前店家資料')));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('實體商品領取'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: '待領取'),
              Tab(text: '已領取'),
              Tab(text: '已取消'),
              Tab(text: '已過期'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            _buildSearchSection(),
            Expanded(
              child: StreamBuilder<List<PointRedemptionModel>>(
                stream: PointRedemptionService.instance.streamShopRedemptions(
                  shopId: normalizedShopId,
                ),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<PointRedemptionModel>> snapshot,
                    ) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '讀取實體商品紀錄失敗\n${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final List<PointRedemptionModel> redemptions =
                          _filterMemberSearch(snapshot.data!);

                      final List<PointRedemptionModel> pendingRedemptions =
                          redemptions
                              .where(
                                (PointRedemptionModel redemption) =>
                                    redemption.status ==
                                        PointRedemptionStatus.pendingPickup &&
                                    !redemption.hasExpired,
                              )
                              .toList();

                      final List<PointRedemptionModel> pickedUpRedemptions =
                          redemptions
                              .where(
                                (PointRedemptionModel redemption) =>
                                    redemption.status ==
                                    PointRedemptionStatus.pickedUp,
                              )
                              .toList();

                      final List<PointRedemptionModel> cancelledRedemptions =
                          redemptions
                              .where(
                                (PointRedemptionModel redemption) =>
                                    redemption.status ==
                                    PointRedemptionStatus.cancelled,
                              )
                              .toList();

                      final List<PointRedemptionModel>
                      expiredRedemptions = redemptions
                          .where(
                            (PointRedemptionModel redemption) =>
                                redemption.status ==
                                    PointRedemptionStatus.expired ||
                                (redemption.status ==
                                        PointRedemptionStatus.pendingPickup &&
                                    redemption.hasExpired),
                          )
                          .toList();

                      return TabBarView(
                        children: <Widget>[
                          _RedemptionList(
                            redemptions: pendingRedemptions,
                            emptyText: '目前沒有待領取商品',
                            showPickupButton: true,
                            showCancelButton: true,
                            isPickingUp: _isPickingUp,
                            isCancelling: _isCancelling,
                            onPickup: _confirmPickup,
                            onCancel: _cancelRedemption,
                          ),
                          _RedemptionList(
                            redemptions: pickedUpRedemptions,
                            emptyText: '目前沒有已領取商品',
                          ),
                          _RedemptionList(
                            redemptions: cancelledRedemptions,
                            emptyText: '目前沒有已取消商品',
                          ),
                          _RedemptionList(
                            redemptions: expiredRedemptions,
                            emptyText: '目前沒有已過期商品',
                            showMarkExpiredButton: true,
                            isMarkingExpired: _isMarkingExpired,
                            onMarkExpired: _markAsExpired,
                          ),
                        ],
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _memberSearchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: '搜尋會員姓名、電話或領取碼',
                hintText: '例如：林、09、AB12CD',
                prefixIcon: const Icon(Icons.person_search_outlined),
                suffixIcon: _memberSearchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除搜尋',
                        onPressed: () {
                          _memberSearchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _pickupCodeController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: '輸入領取碼',
                      hintText: '例如：AB12CD',
                      prefixIcon: const Icon(Icons.qr_code_scanner_outlined),
                      suffixIcon: _pickupCodeController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      _searchPickupCode();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _isSearching ? null : _searchPickupCode,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: const Text('搜尋'),
                ),
              ],
            ),
            if (_searchedRedemption != null) ...<Widget>[
              const SizedBox(height: 14),
              _SearchResultCard(
                redemption: _searchedRedemption!,
                isPickingUp: _isPickingUp,
                onPickup: () {
                  _confirmPickup(_searchedRedemption!);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _memberName(PointRedemptionModel redemption) {
    final String memberName = redemption.memberName.trim();

    if (memberName.isNotEmpty) {
      return memberName;
    }

    return '未提供會員姓名';
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.redemption,
    required this.isPickingUp,
    required this.onPickup,
  });

  final PointRedemptionModel redemption;
  final bool isPickingUp;
  final VoidCallback onPickup;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.check_circle_outline),
                SizedBox(width: 8),
                Text('找到待領取商品', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              redemption.rewardName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('會員：${_memberName(redemption)}'),
            Text('電話：${_memberPhone(redemption)}'),
            Text('領取碼：${redemption.pickupCode}'),
            Text('領取期限：${_expireAtText(redemption.expireAt)}'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isPickingUp ? null : onPickup,
                icon: isPickingUp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.inventory_2_outlined),
                label: const Text('確認完成商品交付'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RedemptionList extends StatelessWidget {
  const _RedemptionList({
    required this.redemptions,
    required this.emptyText,
    this.showPickupButton = false,
    this.showCancelButton = false,
    this.showMarkExpiredButton = false,
    this.isPickingUp = false,
    this.isCancelling = false,
    this.isMarkingExpired = false,
    this.onPickup,
    this.onCancel,
    this.onMarkExpired,
  });

  final List<PointRedemptionModel> redemptions;
  final String emptyText;
  final bool showPickupButton;
  final bool showCancelButton;
  final bool showMarkExpiredButton;

  final bool isPickingUp;
  final bool isCancelling;
  final bool isMarkingExpired;

  final ValueChanged<PointRedemptionModel>? onPickup;
  final ValueChanged<PointRedemptionModel>? onCancel;
  final ValueChanged<PointRedemptionModel>? onMarkExpired;

  @override
  Widget build(BuildContext context) {
    if (redemptions.isEmpty) {
      return _EmptyView(text: emptyText);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: redemptions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final PointRedemptionModel redemption = redemptions[index];

        return _RedemptionCard(
          redemption: redemption,
          showPickupButton: showPickupButton,
          showCancelButton: showCancelButton,
          showMarkExpiredButton: showMarkExpiredButton,
          isPickingUp: isPickingUp,
          isCancelling: isCancelling,
          isMarkingExpired: isMarkingExpired,
          onPickup: onPickup == null
              ? null
              : () {
                  onPickup!(redemption);
                },
          onCancel: onCancel == null
              ? null
              : () {
                  onCancel!(redemption);
                },
          onMarkExpired: onMarkExpired == null
              ? null
              : () {
                  onMarkExpired!(redemption);
                },
        );
      },
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({
    required this.redemption,
    required this.showPickupButton,
    required this.showCancelButton,
    required this.showMarkExpiredButton,
    required this.isPickingUp,
    required this.isCancelling,
    required this.isMarkingExpired,
    required this.onPickup,
    required this.onCancel,
    required this.onMarkExpired,
  });

  final PointRedemptionModel redemption;

  final bool showPickupButton;
  final bool showCancelButton;
  final bool showMarkExpiredButton;

  final bool isPickingUp;
  final bool isCancelling;
  final bool isMarkingExpired;

  final VoidCallback? onPickup;
  final VoidCallback? onCancel;
  final VoidCallback? onMarkExpired;
  @override
  Widget build(BuildContext context) {
    final bool expired =
        redemption.status == PointRedemptionStatus.expired ||
        (redemption.status == PointRedemptionStatus.pendingPickup &&
            redemption.hasExpired);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _RewardImage(imageUrl: redemption.rewardImageUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        redemption.rewardName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _StatusChip(status: redemption.status, expired: expired),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.person_outline,
              text: '會員：${_memberName(redemption)}',
            ),
            const SizedBox(height: 7),
            _InfoRow(
              icon: Icons.phone_outlined,
              text: '電話：${_memberPhone(redemption)}',
            ),
            const SizedBox(height: 7),
            _InfoRow(
              icon: Icons.confirmation_number_outlined,
              text: '領取碼：${redemption.pickupCode}',
            ),
            const SizedBox(height: 7),
            _InfoRow(
              icon: Icons.paid_outlined,
              text: '使用 ${redemption.pointsCost} 點兌換',
            ),
            const SizedBox(height: 7),
            _InfoRow(
              icon: Icons.schedule_outlined,
              text: '建立時間：${_dateTimeText(redemption.createdAt)}',
            ),
            const SizedBox(height: 7),
            _InfoRow(
              icon: expired
                  ? Icons.event_busy_outlined
                  : Icons.event_available_outlined,
              text: '領取期限：${_expireAtText(redemption.expireAt)}',
            ),
            if (redemption.fulfillmentNote.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 7),
              _InfoRow(
                icon: Icons.storefront_outlined,
                text: '領取說明：${redemption.fulfillmentNote.trim()}',
              ),
            ],
            if (redemption.pickedUpAt != null) ...<Widget>[
              const SizedBox(height: 7),
              _InfoRow(
                icon: Icons.check_circle_outline,
                text: '領取時間：${_dateTimeText(redemption.pickedUpAt!)}',
              ),
            ],
            if (redemption.status == PointRedemptionStatus.cancelled &&
                redemption.cancelReason.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 7),
              _InfoRow(
                icon: Icons.info_outline,
                text: '取消原因：${redemption.cancelReason.trim()}',
              ),
            ],
            if (redemption.status == PointRedemptionStatus.cancelled) ...[
              const SizedBox(height: 7),
              _InfoRow(
                icon: Icons.currency_exchange_outlined,
                text: redemption.pointsRefunded ? '點數已退回' : '點數尚未退回',
              ),
            ],
            if ((showPickupButton || showCancelButton) && !expired) ...<Widget>[
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  if (showCancelButton)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isPickingUp || isCancelling
                            ? null
                            : onCancel,
                        icon: isCancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: const Text('取消兌換'),
                      ),
                    ),
                  if (showCancelButton && showPickupButton)
                    const SizedBox(width: 10),
                  if (showPickupButton)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isPickingUp || isCancelling
                            ? null
                            : onPickup,
                        icon: isPickingUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.inventory_2_outlined),
                        label: const Text('完成交付'),
                      ),
                    ),
                ],
              ),
            ],
            if (expired) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '此商品已超過領取期限，無法直接完成交付。',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showMarkExpiredButton &&
                  redemption.status ==
                      PointRedemptionStatus.pendingPickup) ...<Widget>[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isMarkingExpired ? null : onMarkExpired,
                    icon: isMarkingExpired
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_busy_outlined),
                    label: const Text('正式標記為已過期'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RewardImage extends StatelessWidget {
  const _RewardImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final String normalizedImageUrl = imageUrl.trim();

    if (normalizedImageUrl.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.inventory_2_outlined, color: Colors.grey.shade600),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        normalizedImageUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return Container(
                width: 72,
                height: 72,
                color: Colors.grey.shade200,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey.shade600,
                ),
              );
            },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.expired});

  final PointRedemptionStatus status;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color backgroundColor;
    final Color foregroundColor;

    if (expired) {
      text = '已過期';
      backgroundColor = Colors.red.shade50;
      foregroundColor = Colors.red.shade700;
    } else {
      switch (status) {
        case PointRedemptionStatus.pendingPickup:
          text = '待領取';
          backgroundColor = Colors.orange.shade50;
          foregroundColor = Colors.orange.shade800;
          break;
        case PointRedemptionStatus.pickedUp:
          text = '已領取';
          backgroundColor = Colors.green.shade50;
          foregroundColor = Colors.green.shade700;
          break;
        case PointRedemptionStatus.cancelled:
          text = '已取消';
          backgroundColor = Colors.grey.shade200;
          foregroundColor = Colors.grey.shade700;
          break;
        case PointRedemptionStatus.expired:
          text = '已過期';
          backgroundColor = Colors.red.shade50;
          foregroundColor = Colors.red.shade700;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 19, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inventory_2_outlined,
              size: 68,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

String _memberName(PointRedemptionModel redemption) {
  final String memberName = redemption.memberName.trim();

  if (memberName.isNotEmpty) {
    return memberName;
  }

  return '未提供';
}

String _memberPhone(PointRedemptionModel redemption) {
  final String memberPhone = redemption.memberPhone.trim();

  if (memberPhone.isNotEmpty) {
    return memberPhone;
  }

  return '未提供';
}

String _expireAtText(DateTime? expireAt) {
  if (expireAt == null) {
    return '永久有效';
  }

  return _dateTimeText(expireAt);
}

String _dateTimeText(DateTime dateTime) {
  final DateTime localDateTime = dateTime.toLocal();

  String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  return '${localDateTime.year}/'
      '${twoDigits(localDateTime.month)}/'
      '${twoDigits(localDateTime.day)} '
      '${twoDigits(localDateTime.hour)}:'
      '${twoDigits(localDateTime.minute)}';
}
