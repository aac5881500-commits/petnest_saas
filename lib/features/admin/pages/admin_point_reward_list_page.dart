// 檔案名稱：lib/features/admin/pages/admin_point_reward_list_page.dart
// 功能說明：點數兌換中心。商品管理、待核銷、兌換紀錄與成效分析。
// 🎁 只讀既有資料統計，不改扣點、退點、庫存與核銷邏輯。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/member_point_log_model.dart';
import 'package:petnest_saas/core/models/point_redemption_model.dart';
import 'package:petnest_saas/core/models/point_reward_model.dart';
import 'package:petnest_saas/core/services/coupon_template_service.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/core/services/member_point_service.dart';
import 'package:petnest_saas/core/services/point_redemption_service.dart';
import 'package:petnest_saas/core/services/point_reward_image_service.dart';
import 'package:petnest_saas/core/services/point_reward_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_center_stats.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_redemption_list_page.dart';
import 'admin_point_reward_form_page.dart';

class AdminPointRewardListPage extends StatefulWidget {
  const AdminPointRewardListPage({
    super.key,
    required this.shopId,
    this.initialSection = PointCenterSection.rewards,
  });

  final String shopId;

  /// 由營運設定的不同入口帶入，直接開在對應區塊。
  final PointCenterSection initialSection;

  @override
  State<AdminPointRewardListPage> createState() =>
      _AdminPointRewardListPageState();
}

class _AdminPointRewardListPageState extends State<AdminPointRewardListPage> {
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  final TextEditingController _rewardKeywordController =
      TextEditingController();
  final TextEditingController _historyKeywordController =
      TextEditingController();
  final Map<String, String> _memberLabels = <String, String>{};
  final Set<String> _memberLoading = <String>{};

  List<PointRewardModel> _rewards = const <PointRewardModel>[];
  List<MemberPointLogModel> _logs = const <MemberPointLogModel>[];
  List<PointRedemptionModel> _redemptions = const <PointRedemptionModel>[];
  Map<String, String> _templateNames = const <String, String>{};

  late PointCenterSection _section;
  PointRewardTypeFilter _rewardType = PointRewardTypeFilter.all;
  PointRewardStatusFilter _rewardStatus = PointRewardStatusFilter.all;
  PointHistoryTimeFilter _historyTime = PointHistoryTimeFilter.days30;
  PointRewardTypeFilter _historyType = PointRewardTypeFilter.all;
  PointDeliveryFilter _historyDelivery = PointDeliveryFilter.all;
  String _historyRewardId = '';

  bool _loading = true;
  String _error = '';
  String _busyRewardId = '';

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _listen();
  }

  @override
  void dispose() {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _rewardKeywordController.dispose();
    _historyKeywordController.dispose();
    super.dispose();
  }

  void _listen() {
    void fail(Object error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }

    _subscriptions.add(
      PointRewardService.instance.streamShopRewards(widget.shopId).listen((
        List<PointRewardModel> items,
      ) {
        if (!mounted) {
          return;
        }
        setState(() {
          _rewards = items;
          _loading = false;
        });
      }, onError: fail),
    );
    _subscriptions.add(
      MemberPointService.instance
          .streamShopRewardExchangeLogs(shopId: widget.shopId)
          .listen((List<MemberPointLogModel> items) {
            if (!mounted) {
              return;
            }
            setState(() {
              _logs = items;
              _loading = false;
            });
            _loadMemberProfiles(items);
          }, onError: fail),
    );
    _subscriptions.add(
      PointRedemptionService.instance
          .streamShopRedemptions(shopId: widget.shopId)
          .listen((List<PointRedemptionModel> items) {
            if (!mounted) {
              return;
            }
            setState(() {
              _redemptions = items;
              _loading = false;
            });
          }, onError: fail),
    );
    _subscriptions.add(
      CouponTemplateService.instance
          .streamTemplates(shopId: widget.shopId)
          .listen((List<CouponTemplateModel> items) {
            if (!mounted) {
              return;
            }
            setState(() {
              _templateNames = <String, String>{
                for (final CouponTemplateModel item in items)
                  item.id: item.name.trim().isEmpty ? '未命名優惠券模板' : item.name,
              };
            });
          }, onError: (_) {}),
    );
  }

  Future<void> _loadMemberProfiles(List<MemberPointLogModel> logs) async {
    final List<String> missing = <String>[];
    for (final MemberPointLogModel log in logs) {
      final String userId = log.userId.trim();
      if (userId.isEmpty ||
          _memberLabels.containsKey(userId) ||
          _memberLoading.contains(userId)) {
        continue;
      }
      missing.add(userId);
    }
    if (missing.isEmpty) {
      return;
    }
    final List<String> unique = missing.toSet().toList();
    _memberLoading.addAll(unique);
    try {
      for (var start = 0; start < unique.length; start += 10) {
        final int end = start + 10 > unique.length ? unique.length : start + 10;
        final List<String> chunk = unique.sublist(start, end);
        final QuerySnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection('user_profiles')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
        final Set<String> found = <String>{};
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          found.add(doc.id);
          _memberLabels[doc.id] = pointProfileLabel(doc.data());
        }
        for (final String userId in chunk) {
          if (!found.contains(userId)) {
            _memberLabels[userId] = pointMemberUnavailableLabel;
          }
        }
      }
    } catch (_) {
      for (final String userId in unique) {
        _memberLabels.putIfAbsent(userId, () => pointMemberUnavailableLabel);
      }
    } finally {
      _memberLoading.removeAll(unique);
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _memberLabel(String userId) {
    return _memberLabels[userId] ?? '';
  }

  Future<void> _openRewardForm({PointRewardModel? reward}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) {
          return AdminPointRewardFormPage(
            shopId: widget.shopId,
            reward: reward,
          );
        },
      ),
    );
  }

  Future<void> _openRedemptionCenter() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return AdminPointRedemptionListPage(shopId: widget.shopId);
        },
      ),
    );
  }

  Future<void> _toggleEnabled(PointRewardModel reward, bool enabled) async {
    if (_busyRewardId.isNotEmpty) {
      return;
    }
    setState(() {
      _busyRewardId = reward.id;
    });
    try {
      await PointRewardService.instance.setRewardEnabled(
        shopId: widget.shopId,
        rewardId: reward.id,
        enabled: enabled,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(enabled ? '商品已上架' : '商品已下架')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新商品狀態失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _busyRewardId = '';
        });
      }
    }
  }

  Future<void> _deleteReward(PointRewardModel reward) async {
    if (!canDeletePointReward(reward)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已有會員兌換過的商品不能刪除，請改為下架')));
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('刪除兌換商品'),
          content: Text(
            reward.imageUrl.trim().isEmpty
                ? '確定要刪除「${reward.name}」嗎？'
                : '確定要刪除「${reward.name}」嗎？\n\n商品圖片也會一起永久刪除。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await PointRewardService.instance.deleteReward(
        shopId: widget.shopId,
        rewardId: reward.id,
      );

      bool imageDeleteFailed = false;
      if (reward.imageUrl.trim().isNotEmpty) {
        try {
          await PointRewardImageService.instance.deleteImageByUrl(
            reward.imageUrl,
          );
        } catch (_) {
          imageDeleteFailed = true;
        }
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imageDeleteFailed ? '商品已刪除，但 Storage 圖片清理失敗，請稍後再檢查' : '兌換商品與圖片已刪除',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除商品失敗：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('點數兌換中心'),
        actions: <Widget>[
          IconButton(
            tooltip: '核銷中心',
            onPressed: _openRedemptionCenter,
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          IconButton(
            tooltip: '兌換紀錄',
            onPressed: () {
              setState(() {
                _section = PointCenterSection.history;
              });
            },
            icon: const Icon(Icons.history_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final bool desktop = width >= 720;
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('讀取點數資料失敗：$_error', textAlign: TextAlign.center),
              ),
            );
          }
          return Column(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        desktop ? 20 : 12,
                        12,
                        desktop ? 20 : 12,
                        24,
                      ),
                      children: _body(desktop: desktop, width: width),
                    ),
                  ),
                ),
              ),
              if (!desktop) _mobileCreateBar(),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body({required bool desktop, required double width}) {
    final DateTime now = DateTime.now();
    final PointCenterKpi kpi = summarizePointCenterKpi(
      rewards: _rewards,
      exchangeLogs: _logs,
      redemptions: _redemptions,
      now: now,
    );
    return <Widget>[
      _header(desktop: desktop),
      const SizedBox(height: 10),
      _kpiGrid(desktop: desktop, kpi: kpi),
      const SizedBox(height: 10),
      _sectionChips(),
      const SizedBox(height: 12),
      switch (_section) {
        PointCenterSection.rewards => _rewardSection(
          desktop: desktop,
          width: width,
        ),
        PointCenterSection.pending => _pendingSection(desktop: desktop),
        PointCenterSection.history => _historySection(
          desktop: desktop,
          now: now,
        ),
        PointCenterSection.analytics => _analyticsSection(now: now),
      },
    ];
  }

  Widget _header({required bool desktop}) {
    const Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '點數兌換中心',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text(
          '管理會員可兌換的優惠券、實體商品與領取狀態。',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF4B5563),
            height: 1.35,
          ),
        ),
      ],
    );
    if (!desktop) {
      return copy;
    }
    return Row(
      children: <Widget>[
        const Expanded(child: copy),
        FilledButton.icon(
          onPressed: () => _openRewardForm(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('建立兌換商品'),
        ),
      ],
    );
  }

  Widget _mobileCreateBar() {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: () => _openRewardForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('建立兌換商品'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiGrid({required bool desktop, required PointCenterKpi kpi}) {
    final List<Widget> cards = <Widget>[
      _PointKpiCard(
        label: '上架中商品',
        value: '${kpi.enabledRewards}',
        onTap: () {
          setState(() {
            _section = PointCenterSection.rewards;
            _rewardStatus = PointRewardStatusFilter.enabled;
          });
        },
      ),
      _PointKpiCard(
        label: '本月兌換',
        value: '${kpi.monthExchangeCount}',
        onTap: () {
          setState(() {
            _section = PointCenterSection.history;
            _historyTime = PointHistoryTimeFilter.days30;
          });
        },
      ),
      _PointKpiCard(
        label: '待核銷',
        value: '${kpi.pendingPickupCount}',
        onTap: () {
          setState(() {
            _section = PointCenterSection.pending;
          });
        },
      ),
      _PointKpiCard(
        label: '本月扣除點數',
        value: '${kpi.monthPointsSpent}',
        onTap: () {
          setState(() {
            _section = PointCenterSection.analytics;
            _historyTime = PointHistoryTimeFilter.days30;
          });
        },
      ),
    ];
    if (desktop) {
      return Row(
        children: <Widget>[
          for (int index = 0; index < cards.length; index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == cards.length - 1 ? 0 : 8,
                ),
                child: cards[index],
              ),
            ),
        ],
      );
    }
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 92,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      children: cards,
    );
  }

  Widget _sectionChips() {
    final List<Widget> chips = <Widget>[
      _sectionChip('商品管理', PointCenterSection.rewards),
      _sectionChip('待核銷', PointCenterSection.pending),
      _sectionChip('兌換紀錄', PointCenterSection.history),
      _sectionChip('成效分析', PointCenterSection.analytics),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final Widget chip in chips)
            Padding(padding: const EdgeInsets.only(right: 8), child: chip),
        ],
      ),
    );
  }

  Widget _sectionChip(String label, PointCenterSection section) {
    return FilterChip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      showCheckmark: false,
      selected: _section == section,
      onSelected: (_) {
        setState(() {
          _section = section;
        });
      },
    );
  }

  // ── 商品管理 ─────────────────────────────────────────────

  Widget _rewardSection({required bool desktop, required double width}) {
    final List<PointRewardModel> rewards = filterPointRewards(
      rewards: _rewards,
      keyword: _rewardKeywordController.text,
      type: _rewardType,
      status: _rewardStatus,
    );
    final int columns = width >= 1100 ? 3 : (width >= 760 ? 2 : 1);
    return _PointPanel(
      title: '商品管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (desktop)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: _searchField(
                    controller: _rewardKeywordController,
                    hint: '搜尋商品名稱',
                  ),
                ),
                _typeMenu(
                  value: _rewardType,
                  onChanged: (PointRewardTypeFilter value) {
                    setState(() {
                      _rewardType = value;
                    });
                  },
                ),
                _statusMenu(),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: _searchField(
                    controller: _rewardKeywordController,
                    hint: '搜尋商品名稱',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _openRewardFilterSheet,
                  child: const Text('篩選'),
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (rewards.isEmpty)
            _PointEmptyNote(
              title: _rewards.isEmpty ? '尚未建立兌換商品' : '沒有符合條件的商品',
              message: _rewards.isEmpty
                  ? '建立商品後，會員可使用點數兌換優惠券或到店領取實體商品。'
                  : '調整搜尋或篩選條件後再試一次。',
              actionLabel: _rewards.isEmpty ? '建立第一個商品' : null,
              onAction: _rewards.isEmpty ? () => _openRewardForm() : null,
            )
          else if (columns == 1)
            Column(
              children: rewards
                  .map(
                    (PointRewardModel reward) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _rewardCard(reward),
                    ),
                  )
                  .toList(),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rewards.map((PointRewardModel reward) {
                final double cardWidth =
                    (width - (desktop ? 40 : 24) - 24 - (columns - 1) * 8) /
                    columns;
                return SizedBox(
                  width: cardWidth < 260 ? 260 : cardWidth,
                  child: _rewardCard(reward),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _rewardCard(PointRewardModel reward) {
    final bool busy = _busyRewardId == reward.id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _rewardThumb(reward),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      reward.name.trim().isEmpty ? '未命名商品' : reward.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _PointBadge(
                          label: pointRewardTypeLabel(reward),
                          color: reward.isPhysicalProduct
                              ? const Color(0xFFEF6C00)
                              : const Color(0xFF6A1B9A),
                        ),
                        _PointBadge(
                          label: reward.enabled ? '上架中' : '已下架',
                          color: reward.enabled
                              ? const Color(0xFF2E7D32)
                              : Colors.grey.shade600,
                        ),
                        if (reward.isSoldOut)
                          const _PointBadge(
                            label: '已額滿',
                            color: Color(0xFFC62828),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${reward.pointsCost} 點',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '已兌換 ${pointExchangeLimitLabel(reward)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (reward.isPhysicalProduct) ...<Widget>[
            const SizedBox(height: 2),
            if (reward.usesCentralInventory)
              _InventoryStockLine(
                shopId: widget.shopId,
                itemId: reward.inventoryItemId,
                fallbackName: reward.inventoryItemName,
                fallbackUnit: reward.inventoryUnit,
              )
            else
              Text(
                pointRewardStockLabel(reward),
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 2),
            Text(
              '待核銷 ${_pendingCountOf(reward.id)} 件',
              style: const TextStyle(fontSize: 12),
            ),
          ] else if (reward.isCouponReward) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              '模板：${_templateLabel(reward)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const Text(
              '兌換後立即發券',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Switch.adaptive(
                value: reward.enabled,
                onChanged: busy
                    ? null
                    : (bool value) => _toggleEnabled(reward, value),
              ),
              const Spacer(),
              IconButton(
                tooltip: '編輯',
                visualDensity: VisualDensity.compact,
                onPressed: () => _openRewardForm(reward: reward),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                onSelected: (String value) {
                  if (value == 'delete') {
                    _deleteReward(reward);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'delete',
                      enabled: canDeletePointReward(reward),
                      child: Text(
                        canDeletePointReward(reward) ? '刪除商品' : '已有兌換紀錄，不可刪除',
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rewardThumb(PointRewardModel reward) {
    final String url = reward.imageUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        color: Colors.grey.shade100,
        child: url.isEmpty
            ? Icon(
                reward.isPhysicalProduct
                    ? Icons.inventory_2_outlined
                    : Icons.confirmation_number_outlined,
                size: 22,
                color: Colors.grey.shade700,
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) {
                      return Icon(
                        Icons.image_not_supported_outlined,
                        size: 20,
                        color: Colors.grey.shade600,
                      );
                    },
              ),
      ),
    );
  }

  String _templateLabel(PointRewardModel reward) {
    final String id = reward.couponTemplateId.trim();
    if (id.isEmpty) {
      return '沿用商品內優惠設定';
    }
    return _templateNames[id] ?? '找不到優惠券模板';
  }

  int _pendingCountOf(String rewardId) {
    return _redemptions
        .where(
          (PointRedemptionModel item) =>
              item.rewardId == rewardId &&
              item.status == PointRedemptionStatus.pendingPickup,
        )
        .length;
  }

  Future<void> _openRewardFilterSheet() async {
    PointRewardTypeFilter type = _rewardType;
    PointRewardStatusFilter status = _rewardStatus;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setLocal) {
                return Dialog(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                            '篩選商品',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<PointRewardTypeFilter>(
                            initialValue: type,
                            isDense: true,
                            decoration: const InputDecoration(labelText: '類型'),
                            items: PointRewardTypeFilter.values.map((
                              PointRewardTypeFilter item,
                            ) {
                              return DropdownMenuItem<PointRewardTypeFilter>(
                                value: item,
                                child: Text(_typeFilterLabel(item)),
                              );
                            }).toList(),
                            onChanged: (PointRewardTypeFilter? value) {
                              if (value == null) {
                                return;
                              }
                              setLocal(() => type = value);
                            },
                          ),
                          DropdownButtonFormField<PointRewardStatusFilter>(
                            initialValue: status,
                            isDense: true,
                            decoration: const InputDecoration(labelText: '狀態'),
                            items: PointRewardStatusFilter.values.map((
                              PointRewardStatusFilter item,
                            ) {
                              return DropdownMenuItem<PointRewardStatusFilter>(
                                value: item,
                                child: Text(_statusFilterLabel(item)),
                              );
                            }).toList(),
                            onChanged: (PointRewardStatusFilter? value) {
                              if (value == null) {
                                return;
                              }
                              setLocal(() => status = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _rewardType = type;
                                  _rewardStatus = status;
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text('套用'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }

  // ── 待核銷 ───────────────────────────────────────────────

  Widget _pendingSection({required bool desktop}) {
    final List<PointRedemptionModel> pending = _redemptions
        .where(
          (PointRedemptionModel item) =>
              item.status == PointRedemptionStatus.pendingPickup,
        )
        .toList();
    return _PointPanel(
      title: '待核銷',
      trailing: TextButton(
        onPressed: _openRedemptionCenter,
        child: const Text('開啟核銷中心'),
      ),
      child: pending.isEmpty
          ? const _PointEmptyNote(
              title: '目前沒有待核銷的實體商品',
              message: '會員兌換實體商品後，這裡會顯示領取碼與期限。',
            )
          : Column(
              children: pending.map((PointRedemptionModel item) {
                final Widget info = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.rewardName.trim().isEmpty
                          ? '未命名商品'
                          : item.rewardName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '會員 ${pointMemberLabelOf(redemption: item, userId: item.userId, lookup: _memberLabel)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '兌換 ${formatPointDate(item.createdAt)}　'
                      '期限 ${item.expireAt == null ? '不限' : formatPointDate(item.expireAt!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '領取碼 ${item.pickupCode.isEmpty ? '—' : item.pickupCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
                final Widget action = FilledButton(
                  onPressed: _openRedemptionCenter,
                  child: const Text('前往核銷'),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: desktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: info),
                            const SizedBox(width: 8),
                            action,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            info,
                            const SizedBox(height: 8),
                            SizedBox(width: double.infinity, child: action),
                          ],
                        ),
                );
              }).toList(),
            ),
    );
  }

  // ── 兌換紀錄 ─────────────────────────────────────────────

  Widget _historySection({required bool desktop, required DateTime now}) {
    final List<PointExchangeRow> all = buildPointExchangeRows(
      exchangeLogs: _logs,
      rewards: _rewards,
      redemptions: _redemptions,
      memberLabelOf: _memberLabel,
    );
    final List<PointExchangeRow> rows = filterPointExchangeRows(
      rows: all,
      now: now,
      time: _historyTime,
      rewardId: _historyRewardId,
      type: _historyType,
      delivery: _historyDelivery,
      keyword: _historyKeywordController.text,
    );
    return _PointPanel(
      title: '兌換紀錄',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (desktop)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: _searchField(
                    controller: _historyKeywordController,
                    hint: '搜尋商品或會員',
                  ),
                ),
                _timeMenu(),
                _rewardMenu(),
                _typeMenu(
                  value: _historyType,
                  onChanged: (PointRewardTypeFilter value) {
                    setState(() {
                      _historyType = value;
                    });
                  },
                ),
                _deliveryMenu(),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: _searchField(
                    controller: _historyKeywordController,
                    hint: '搜尋商品或會員',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _openHistoryFilterSheet,
                  child: const Text('篩選'),
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const _PointEmptyNote(
              title: '沒有符合條件的兌換紀錄',
              message: '調整時間或篩選條件，或等待會員兌換後再查看。',
            )
          else if (desktop)
            _historyTable(rows)
          else
            Column(children: rows.map(_historyCard).toList()),
        ],
      ),
    );
  }

  Widget _historyTable(List<PointExchangeRow> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        columnSpacing: 18,
        columns: const <DataColumn>[
          DataColumn(label: Text('商品')),
          DataColumn(label: Text('類型')),
          DataColumn(label: Text('會員')),
          DataColumn(label: Text('扣除點數')),
          DataColumn(label: Text('兌換時間')),
          DataColumn(label: Text('結果')),
        ],
        rows: rows.map((PointExchangeRow row) {
          return DataRow(
            cells: <DataCell>[
              DataCell(Text(row.rewardName)),
              DataCell(Text(row.isPhysical ? '實體商品' : '優惠券')),
              DataCell(Text(_rowMemberLabel(row))),
              DataCell(Text('${row.pointsSpent} 點')),
              DataCell(Text(formatPointDateTime(row.createdAt))),
              DataCell(Text(pointDeliveryLabel(row.delivery))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _historyCard(PointExchangeRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            row.rewardName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${row.isPhysical ? '實體商品' : '優惠券'}　${row.pointsSpent} 點',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '會員 ${_rowMemberLabel(row)}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '${formatPointDateTime(row.createdAt)}　${pointDeliveryLabel(row.delivery)}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _rowMemberLabel(PointExchangeRow row) {
    if (row.memberLabel.trim().isNotEmpty) {
      return row.memberLabel;
    }
    return _memberLoading.contains(row.log.userId.trim())
        ? '載入中'
        : pointMemberUnavailableLabel;
  }

  Future<void> _openHistoryFilterSheet() async {
    PointHistoryTimeFilter time = _historyTime;
    PointRewardTypeFilter type = _historyType;
    PointDeliveryFilter delivery = _historyDelivery;
    String rewardId = _historyRewardId;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setLocal) {
                return Dialog(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                      maxHeight: 460,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(
                        shrinkWrap: true,
                        children: <Widget>[
                          const Text(
                            '篩選紀錄',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<PointHistoryTimeFilter>(
                            initialValue: time,
                            isDense: true,
                            decoration: const InputDecoration(labelText: '時間'),
                            items: PointHistoryTimeFilter.values.map((
                              PointHistoryTimeFilter item,
                            ) {
                              return DropdownMenuItem<PointHistoryTimeFilter>(
                                value: item,
                                child: Text(_timeFilterLabel(item)),
                              );
                            }).toList(),
                            onChanged: (PointHistoryTimeFilter? value) {
                              if (value == null) {
                                return;
                              }
                              setLocal(() => time = value);
                            },
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _rewardMenuValue(rewardId),
                            isDense: true,
                            decoration: const InputDecoration(labelText: '商品'),
                            items: _rewardMenuItems(),
                            onChanged: (String? value) {
                              setLocal(() => rewardId = value ?? '');
                            },
                          ),
                          DropdownButtonFormField<PointRewardTypeFilter>(
                            initialValue: type,
                            isDense: true,
                            decoration: const InputDecoration(labelText: '類型'),
                            items: PointRewardTypeFilter.values.map((
                              PointRewardTypeFilter item,
                            ) {
                              return DropdownMenuItem<PointRewardTypeFilter>(
                                value: item,
                                child: Text(_typeFilterLabel(item)),
                              );
                            }).toList(),
                            onChanged: (PointRewardTypeFilter? value) {
                              if (value == null) {
                                return;
                              }
                              setLocal(() => type = value);
                            },
                          ),
                          DropdownButtonFormField<PointDeliveryFilter>(
                            initialValue: delivery,
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: '實體商品狀態',
                            ),
                            items: PointDeliveryFilter.values.map((
                              PointDeliveryFilter item,
                            ) {
                              return DropdownMenuItem<PointDeliveryFilter>(
                                value: item,
                                child: Text(_deliveryFilterLabel(item)),
                              );
                            }).toList(),
                            onChanged: (PointDeliveryFilter? value) {
                              if (value == null) {
                                return;
                              }
                              setLocal(() => delivery = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _historyTime = time;
                                  _historyType = type;
                                  _historyDelivery = delivery;
                                  _historyRewardId = rewardId;
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text('套用'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }

  // ── 成效分析 ─────────────────────────────────────────────

  Widget _analyticsSection({required DateTime now}) {
    final PointCenterAnalytics analytics = summarizePointCenterAnalytics(
      rewards: _rewards,
      exchangeLogs: _logs,
      redemptions: _redemptions,
      now: now,
    );
    if (!analytics.hasData) {
      return const _PointPanel(
        title: '成效分析',
        child: _PointEmptyNote(
          title: '尚無兌換紀錄',
          message: '建立商品並開放會員兌換後，這裡會顯示成效。',
        ),
      );
    }
    return _PointPanel(
      title: '成效分析',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _metric('累計兌換次數', '${analytics.totalExchangeCount}'),
              _metric('累計扣除點數', '${analytics.totalPointsSpent}'),
              _metric('本月兌換次數', '${analytics.monthExchangeCount}'),
              _metric('本月完成核銷', '${analytics.monthPickedUpCount}'),
              _metric('待核銷', '${analytics.pendingPickupCount}'),
              _metric('取消／過期', '${analytics.cancelledOrExpiredCount}'),
            ],
          ),
          const SizedBox(height: 12),
          const Text('狀態比例', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (analytics.redemptionTotal == 0)
            const Text(
              '目前沒有實體商品兌換紀錄。',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            )
          else ...<Widget>[
            _shareBar(
              '已完成核銷',
              analytics.pickedUpCount,
              analytics.statusShare(analytics.pickedUpCount),
              const Color(0xFF2E7D32),
            ),
            _shareBar(
              '待核銷',
              analytics.pendingPickupCount,
              analytics.statusShare(analytics.pendingPickupCount),
              const Color(0xFFEF6C00),
            ),
            _shareBar(
              '已取消',
              analytics.cancelledCount,
              analytics.statusShare(analytics.cancelledCount),
              const Color(0xFFC62828),
            ),
            _shareBar(
              '已過期',
              analytics.expiredCount,
              analytics.statusShare(analytics.expiredCount),
              const Color(0xFF757575),
            ),
          ],
          const SizedBox(height: 12),
          const Text('商品成效排行', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (analytics.topRewards.isEmpty)
            const Text(
              '尚無兌換資料。',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            )
          else
            ...analytics.topRewards.asMap().entries.map((
              MapEntry<int, PointRewardRank> entry,
            ) {
              return _rankRow(entry.key + 1, entry.value);
            }),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 11)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _shareBar(String label, int count, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              minHeight: 6,
              value: value,
              color: color,
              backgroundColor: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankRow(int rank, PointRewardRank item) {
    final List<String> parts = <String>[
      '兌換 ${item.exchangeCount} 次',
      '扣除 ${item.pointsSpent} 點',
      if (item.hasTotalLimit) '使用率 ${item.usageRateLabel}',
      if (item.isPhysical)
        '已核銷 ${item.pickedUpCount}・待核銷 ${item.pendingCount}・取消 ${item.cancelledCount}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(parts.join('　'), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 共用小元件 ───────────────────────────────────────────

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 18),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _typeMenu({
    required PointRewardTypeFilter value,
    required ValueChanged<PointRewardTypeFilter> onChanged,
  }) {
    return DropdownButton<PointRewardTypeFilter>(
      value: value,
      isDense: true,
      items: PointRewardTypeFilter.values.map((PointRewardTypeFilter item) {
        return DropdownMenuItem<PointRewardTypeFilter>(
          value: item,
          child: Text(_typeFilterLabel(item)),
        );
      }).toList(),
      onChanged: (PointRewardTypeFilter? next) {
        if (next != null) {
          onChanged(next);
        }
      },
    );
  }

  Widget _statusMenu() {
    return DropdownButton<PointRewardStatusFilter>(
      value: _rewardStatus,
      isDense: true,
      items: PointRewardStatusFilter.values.map((PointRewardStatusFilter item) {
        return DropdownMenuItem<PointRewardStatusFilter>(
          value: item,
          child: Text(_statusFilterLabel(item)),
        );
      }).toList(),
      onChanged: (PointRewardStatusFilter? next) {
        if (next == null) {
          return;
        }
        setState(() {
          _rewardStatus = next;
        });
      },
    );
  }

  Widget _timeMenu() {
    return DropdownButton<PointHistoryTimeFilter>(
      value: _historyTime,
      isDense: true,
      items: PointHistoryTimeFilter.values.map((PointHistoryTimeFilter item) {
        return DropdownMenuItem<PointHistoryTimeFilter>(
          value: item,
          child: Text(_timeFilterLabel(item)),
        );
      }).toList(),
      onChanged: (PointHistoryTimeFilter? next) {
        if (next == null) {
          return;
        }
        setState(() {
          _historyTime = next;
        });
      },
    );
  }

  Widget _deliveryMenu() {
    return DropdownButton<PointDeliveryFilter>(
      value: _historyDelivery,
      isDense: true,
      items: PointDeliveryFilter.values.map((PointDeliveryFilter item) {
        return DropdownMenuItem<PointDeliveryFilter>(
          value: item,
          child: Text(_deliveryFilterLabel(item)),
        );
      }).toList(),
      onChanged: (PointDeliveryFilter? next) {
        if (next == null) {
          return;
        }
        setState(() {
          _historyDelivery = next;
        });
      },
    );
  }

  Widget _rewardMenu() {
    return DropdownButton<String>(
      value: _rewardMenuValue(_historyRewardId),
      isDense: true,
      items: _rewardMenuItems(),
      onChanged: (String? value) {
        setState(() {
          _historyRewardId = value ?? '';
        });
      },
    );
  }

  String _rewardMenuValue(String rewardId) {
    final bool exists = _rewards.any(
      (PointRewardModel reward) => reward.id == rewardId,
    );
    return exists ? rewardId : '';
  }

  List<DropdownMenuItem<String>> _rewardMenuItems() {
    return <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: '', child: Text('全部商品')),
      ..._rewards.map((PointRewardModel reward) {
        return DropdownMenuItem<String>(
          value: reward.id,
          child: Text(reward.name.trim().isEmpty ? '未命名商品' : reward.name),
        );
      }),
    ];
  }
}

String _typeFilterLabel(PointRewardTypeFilter value) {
  switch (value) {
    case PointRewardTypeFilter.all:
      return '全部類型';
    case PointRewardTypeFilter.coupon:
      return '優惠券';
    case PointRewardTypeFilter.physical:
      return '實體商品';
  }
}

String _statusFilterLabel(PointRewardStatusFilter value) {
  switch (value) {
    case PointRewardStatusFilter.all:
      return '全部狀態';
    case PointRewardStatusFilter.enabled:
      return '上架中';
    case PointRewardStatusFilter.disabled:
      return '已下架';
    case PointRewardStatusFilter.soldOut:
      return '已額滿';
  }
}

String _timeFilterLabel(PointHistoryTimeFilter value) {
  switch (value) {
    case PointHistoryTimeFilter.days30:
      return '近 30 天';
    case PointHistoryTimeFilter.days90:
      return '近 90 天';
    case PointHistoryTimeFilter.all:
      return '全部時間';
  }
}

String _deliveryFilterLabel(PointDeliveryFilter value) {
  switch (value) {
    case PointDeliveryFilter.all:
      return '全部結果';
    case PointDeliveryFilter.couponIssued:
      return '已發券';
    case PointDeliveryFilter.pendingPickup:
      return '待領取';
    case PointDeliveryFilter.pickedUp:
      return '已核銷';
    case PointDeliveryFilter.cancelled:
      return '已取消';
    case PointDeliveryFilter.expired:
      return '已過期';
  }
}

class _PointPanel extends StatelessWidget {
  const _PointPanel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PointKpiCard extends StatelessWidget {
  const _PointKpiCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointBadge extends StatelessWidget {
  const _PointBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PointEmptyNote extends StatelessWidget {
  const _PointEmptyNote({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 8),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// 中央庫存摘要。庫存本身仍由 InventoryService 管理。
class _InventoryStockLine extends StatelessWidget {
  const _InventoryStockLine({
    required this.shopId,
    required this.itemId,
    required this.fallbackName,
    required this.fallbackUnit,
  });

  final String shopId;
  final String itemId;
  final String fallbackName;
  final String fallbackUnit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<InventoryItemModel?>(
      stream: InventoryService.instance.streamItem(
        shopId: shopId,
        itemId: itemId,
      ),
      builder:
          (BuildContext context, AsyncSnapshot<InventoryItemModel?> snapshot) {
            final InventoryItemModel? item = snapshot.data;
            final String unit = (item?.unit ?? fallbackUnit).trim().isEmpty
                ? '個'
                : (item?.unit ?? fallbackUnit).trim();
            final String name = (item?.name ?? fallbackName).trim().isEmpty
                ? '中央庫存品項'
                : (item?.name ?? fallbackName).trim();
            final String stock = item == null
                ? '讀取中'
                : '${InventoryConstants.formatQuantity(item.currentStock)} $unit';
            return Text(
              '連動庫存：$name　目前 $stock',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            );
          },
    );
  }
}
