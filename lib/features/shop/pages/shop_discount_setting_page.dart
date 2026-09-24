// 檔案名稱：lib/features/shop/pages/shop_discount_setting_page.dart
// 功能說明：優惠設定入口：價格規則、優惠與優惠券、點數兌換概覽與管理工具。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/models/member_point_log_model.dart';
import 'package:petnest_saas/core/models/point_redemption_model.dart';
import 'package:petnest_saas/core/models/point_reward_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/special_date_surcharge_model.dart';
import 'package:petnest_saas/core/services/coupon_template_service.dart';
import 'package:petnest_saas/core/services/discount_campaign_calculator.dart';
import 'package:petnest_saas/core/services/discount_campaign_customer_copy.dart';
import 'package:petnest_saas/core/services/discount_campaign_service.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/member_point_service.dart';
import 'package:petnest_saas/core/services/point_redemption_service.dart';
import 'package:petnest_saas/core/services/point_reward_service.dart';
import 'package:petnest_saas/core/services/special_date_surcharge_service.dart';
import 'package:petnest_saas/core/widgets/point_module_visibility.dart';
import 'package:petnest_saas/features/admin/pages/admin_coupon_template_list_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_exchange_history_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_redemption_list_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_reward_list_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_discount_campaign_form_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_discount_campaign_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_special_date_surcharge_form_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_special_date_surcharge_page.dart';

class ShopDiscountSettingPage extends StatelessWidget {
  const ShopDiscountSettingPage({
    super.key,
    required this.shopId,
    this.embedded = false,
  });

  final String shopId;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final Widget content = _DiscountSettingHub(shopId: shopId);
    if (embedded) {
      return ColoredBox(color: Colors.grey.shade100, child: content);
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('優惠設定')),
      body: content,
    );
  }
}

class _HubSnapshot {
  const _HubSnapshot({
    this.surcharges = const <SpecialDateSurchargeModel>[],
    this.campaigns = const <DiscountCampaignModel>[],
    this.templates = const <CouponTemplateModel>[],
    this.issuedCouponCount = 0,
    this.enabledRewards = 0,
    this.pendingPickups = 0,
    this.monthExchangeCount = 0,
    this.errorMessage,
    this.loading = true,
  });

  final List<SpecialDateSurchargeModel> surcharges;
  final List<DiscountCampaignModel> campaigns;
  final List<CouponTemplateModel> templates;
  final int issuedCouponCount;
  final int enabledRewards;
  final int pendingPickups;
  final int monthExchangeCount;
  final String? errorMessage;
  final bool loading;

  List<SpecialDateSurchargeModel> get enabledSurcharges {
    return surcharges
        .where((SpecialDateSurchargeModel item) => item.enabled)
        .toList();
  }

  List<DiscountCampaignModel> get enabledCampaigns {
    return campaigns.where((DiscountCampaignModel item) {
      return DiscountCampaignCalculator.isCampaignCurrentlyActive(item);
    }).toList();
  }

  int get enabledTemplateCount {
    return templates.where((CouponTemplateModel item) => item.enabled).length;
  }
}

class _DiscountSettingHub extends StatefulWidget {
  const _DiscountSettingHub({required this.shopId});

  final String shopId;

  @override
  State<_DiscountSettingHub> createState() => _DiscountSettingHubState();
}

class _DiscountSettingHubState extends State<_DiscountSettingHub> {
  final GlobalKey _toolsKey = GlobalKey();
  final Set<String> _expandedGroups = <String>{};
  _HubSnapshot _snapshot = const _HubSnapshot();
  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant _DiscountSettingHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _listen();
    }
  }

  @override
  void dispose() {
    for (final StreamSubscription<dynamic> sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  void _listen() {
    for (final StreamSubscription<dynamic> sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    setState(() {
      _snapshot = const _HubSnapshot();
    });

    void fail(Object error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = _HubSnapshot(
          errorMessage: ChatErrorProbe.userFacing(error),
          loading: false,
        );
      });
    }

    _HubSnapshot next = const _HubSnapshot(loading: false);

    void emit() {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = next;
      });
    }

    _subs.add(
      SpecialDateSurchargeService.instance
          .streamSurcharges(widget.shopId)
          .listen((List<SpecialDateSurchargeModel> items) {
            next = _HubSnapshot(
              surcharges: items,
              campaigns: next.campaigns,
              templates: next.templates,
              issuedCouponCount: next.issuedCouponCount,
              enabledRewards: next.enabledRewards,
              pendingPickups: next.pendingPickups,
              monthExchangeCount: next.monthExchangeCount,
              loading: false,
            );
            emit();
          }, onError: fail),
    );
    _subs.add(
      DiscountCampaignService.instance.streamCampaigns(widget.shopId).listen((
        List<DiscountCampaignModel> items,
      ) {
        next = _HubSnapshot(
          surcharges: next.surcharges,
          campaigns: items,
          templates: next.templates,
          issuedCouponCount: next.issuedCouponCount,
          enabledRewards: next.enabledRewards,
          pendingPickups: next.pendingPickups,
          monthExchangeCount: next.monthExchangeCount,
          loading: false,
        );
        emit();
      }, onError: fail),
    );
    _subs.add(
      CouponTemplateService.instance
          .streamTemplates(shopId: widget.shopId)
          .listen((List<CouponTemplateModel> items) {
            next = _HubSnapshot(
              surcharges: next.surcharges,
              campaigns: next.campaigns,
              templates: items,
              issuedCouponCount: next.issuedCouponCount,
              enabledRewards: next.enabledRewards,
              pendingPickups: next.pendingPickups,
              monthExchangeCount: next.monthExchangeCount,
              loading: false,
            );
            emit();
          }, onError: fail),
    );
    _subs.add(
      MemberCouponService.instance.streamShopCoupons(widget.shopId).listen((
        List<MemberCouponModel> items,
      ) {
        next = _HubSnapshot(
          surcharges: next.surcharges,
          campaigns: next.campaigns,
          templates: next.templates,
          issuedCouponCount: items.length,
          enabledRewards: next.enabledRewards,
          pendingPickups: next.pendingPickups,
          monthExchangeCount: next.monthExchangeCount,
          loading: false,
        );
        emit();
      }, onError: fail),
    );
    _subs.add(
      PointRewardService.instance.streamEnabledRewards(widget.shopId).listen((
        List<PointRewardModel> items,
      ) {
        next = _HubSnapshot(
          surcharges: next.surcharges,
          campaigns: next.campaigns,
          templates: next.templates,
          issuedCouponCount: next.issuedCouponCount,
          enabledRewards: items.length,
          pendingPickups: next.pendingPickups,
          monthExchangeCount: next.monthExchangeCount,
          loading: false,
        );
        emit();
      }, onError: fail),
    );
    _subs.add(
      PointRedemptionService.instance
          .streamPendingPickups(shopId: widget.shopId)
          .listen((List<PointRedemptionModel> items) {
            next = _HubSnapshot(
              surcharges: next.surcharges,
              campaigns: next.campaigns,
              templates: next.templates,
              issuedCouponCount: next.issuedCouponCount,
              enabledRewards: next.enabledRewards,
              pendingPickups: items.length,
              monthExchangeCount: next.monthExchangeCount,
              loading: false,
            );
            emit();
          }, onError: fail),
    );
    _subs.add(
      MemberPointService.instance
          .streamShopRewardExchangeLogs(shopId: widget.shopId)
          .listen((List<MemberPointLogModel> items) {
            final DateTime now = DateTime.now();
            final int count = items.where((MemberPointLogModel log) {
              return log.createdAt.year == now.year &&
                  log.createdAt.month == now.month;
            }).length;
            next = _HubSnapshot(
              surcharges: next.surcharges,
              campaigns: next.campaigns,
              templates: next.templates,
              issuedCouponCount: next.issuedCouponCount,
              enabledRewards: next.enabledRewards,
              pendingPickups: next.pendingPickups,
              monthExchangeCount: count,
              loading: false,
            );
            emit();
          }, onError: fail),
    );
  }

  Future<void> _openSurcharge({SpecialDateSurchargeModel? item}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ShopSpecialDateSurchargeFormPage(
            shopId: widget.shopId,
            surcharge: item,
          );
        },
      ),
    );
  }

  Future<void> _openSurchargeList() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ShopSpecialDateSurchargePage(shopId: widget.shopId);
        },
      ),
    );
  }

  Future<void> _openCampaign({DiscountCampaignModel? campaign}) async {
    if (campaign == null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return ShopDiscountCampaignPage(shopId: widget.shopId);
          },
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ShopDiscountCampaignFormPage(
            shopId: widget.shopId,
            campaignType: campaign.type,
            campaign: campaign,
          );
        },
      ),
    );
  }

  Future<void> _openCoupons() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return AdminCouponTemplateListPage(shopId: widget.shopId);
        },
      ),
    );
  }

  void _showAllSettings() {
    setState(() {
      _expandedGroups.addAll(<String>['price', 'promo', 'points']);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _toolsKey.currentContext;
      if (target == null) {
        return;
      }
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_snapshot.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '讀取優惠設定失敗，請稍後再試。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade800, height: 1.5),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _listen, child: const Text('重試')),
            ],
          ),
        ),
      );
    }
    if (_snapshot.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= 980;
        final Widget tools = KeyedSubtree(
          key: _toolsKey,
          child: _ToolsColumn(
            shopId: widget.shopId,
            snapshot: _snapshot,
            expandedGroups: _expandedGroups,
            desktop: desktop,
            onToggleGroup: (String id) {
              setState(() {
                if (_expandedGroups.contains(id)) {
                  _expandedGroups.remove(id);
                } else {
                  _expandedGroups.add(id);
                }
              });
            },
            onOpenSurcharge: _openSurchargeList,
            onOpenCampaigns: () => _openCampaign(),
            onOpenCoupons: _openCoupons,
          ),
        );
        if (desktop) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: _OverviewColumn(
                          snapshot: _snapshot,
                          onSurcharge: (SpecialDateSurchargeModel item) {
                            _openSurcharge(item: item);
                          },
                          onCampaign: (DiscountCampaignModel item) {
                            _openCampaign(campaign: item);
                          },
                          onCoupons: _openCoupons,
                          onCreateSurcharge: () => _openSurcharge(),
                          onCreateCampaign: () => _openCampaign(),
                          onShowAll: _showAllSettings,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(child: tools),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: <Widget>[
            _MobileStats(snapshot: _snapshot),
            const SizedBox(height: 16),
            tools,
          ],
        );
      },
    );
  }
}

class _MobileStats extends StatelessWidget {
  const _MobileStats({required this.snapshot});

  final _HubSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _MiniStat(
            color: Colors.deepOrange,
            label: '特殊日期加價',
            value: '${snapshot.enabledSurcharges.length}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            color: Colors.green,
            label: '啟用活動',
            value: '${snapshot.enabledCampaigns.length}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            color: Colors.deepPurple,
            label: '可用券模板',
            value: '${snapshot.enabledTemplateCount}',
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.color,
    required this.label,
    required this.value,
  });

  final MaterialColor color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: color.shade700),
          ),
        ],
      ),
    );
  }
}

class _OverviewColumn extends StatelessWidget {
  const _OverviewColumn({
    required this.snapshot,
    required this.onSurcharge,
    required this.onCampaign,
    required this.onCoupons,
    required this.onCreateSurcharge,
    required this.onCreateCampaign,
    required this.onShowAll,
  });

  final _HubSnapshot snapshot;
  final ValueChanged<SpecialDateSurchargeModel> onSurcharge;
  final ValueChanged<DiscountCampaignModel> onCampaign;
  final VoidCallback onCoupons;
  final VoidCallback onCreateSurcharge;
  final VoidCallback onCreateCampaign;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final List<SpecialDateSurchargeModel> surcharges = snapshot
        .enabledSurcharges
        .take(3)
        .toList();
    final List<DiscountCampaignModel> campaigns = snapshot.enabledCampaigns
        .take(3)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '目前生效的價格與優惠',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (surcharges.isEmpty)
          _EmptyCard(
            title: '尚未設定特殊日期加價',
            actionLabel: '新增加價規則',
            color: Colors.deepOrange,
            onPressed: onCreateSurcharge,
          )
        else
          ...surcharges.map((SpecialDateSurchargeModel item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OverviewTapCard(
                color: Colors.deepOrange,
                title: item.name,
                tag: '特殊日期加價',
                body:
                    '${item.startDate.month}/${item.startDate.day}–'
                    '${item.endDate.month}/${item.endDate.day} · 每晚 +NT\$${item.amountPerNight}',
                footer: PolicyApplicableService.displayLabel(
                  item.applicableServices,
                ),
                status: '啟用中',
                onTap: () => onSurcharge(item),
              ),
            );
          }),
        if (campaigns.isEmpty)
          _EmptyCard(
            title: '尚未設定自動優惠',
            actionLabel: '建立優惠活動',
            color: Colors.green,
            onPressed: onCreateCampaign,
          )
        else
          ...campaigns.map((DiscountCampaignModel item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OverviewTapCard(
                color: Colors.green,
                title: item.name,
                tag: '自動優惠',
                body: DiscountCampaignCustomerCopy.benefitLine(item),
                footer: PolicyApplicableService.displayLabel(
                  item.applicableServices,
                ),
                status: '啟用中',
                onTap: () => onCampaign(item),
              ),
            );
          }),
        _OverviewTapCard(
          color: Colors.deepPurple,
          title: '可用優惠券',
          tag: '優惠券統計',
          body:
              '${snapshot.enabledTemplateCount} 種 · 已發放 ${snapshot.issuedCouponCount} 張',
          footer: snapshot.enabledTemplateCount == 0 ? '尚無啟用模板' : '',
          status: snapshot.enabledTemplateCount > 0 ? '啟用中' : '尚無設定',
          onTap: onCoupons,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onShowAll, child: const Text('查看全部設定')),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.actionLabel,
    required this.color,
    required this.onPressed,
  });

  final String title;
  final String actionLabel;
  final MaterialColor color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color.shade800,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _OverviewTapCard extends StatelessWidget {
  const _OverviewTapCard({
    required this.color,
    required this.title,
    required this.tag,
    required this.body,
    required this.footer,
    required this.status,
    required this.onTap,
  });

  final MaterialColor color;
  final String title;
  final String tag;
  final String body;
  final String footer;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.22)),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 11,
                        color: color.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(body, style: TextStyle(color: Colors.grey.shade800)),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  if (footer.isNotEmpty)
                    Expanded(
                      child: Text(
                        footer,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolsColumn extends StatelessWidget {
  const _ToolsColumn({
    required this.shopId,
    required this.snapshot,
    required this.expandedGroups,
    required this.desktop,
    required this.onToggleGroup,
    required this.onOpenSurcharge,
    required this.onOpenCampaigns,
    required this.onOpenCoupons,
  });

  final String shopId;
  final _HubSnapshot snapshot;
  final Set<String> expandedGroups;
  final bool desktop;
  final ValueChanged<String> onToggleGroup;
  final VoidCallback onOpenSurcharge;
  final VoidCallback onOpenCampaigns;
  final VoidCallback onOpenCoupons;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (desktop)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '管理工具',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '自動優惠會在訂單符合條件時直接折抵；優惠券可發放給會員後使用。',
            style: TextStyle(height: 1.45),
          ),
        ),
        const SizedBox(height: 14),
        _GroupCard(
          id: 'price',
          title: '價格規則',
          description: '設定連假、節日或指定日期的住宿／安親加價規則。',
          color: Colors.deepOrange,
          expanded: desktop || expandedGroups.contains('price'),
          desktop: desktop,
          onHeaderTap: () => onToggleGroup('price'),
          children: <Widget>[
            _ToolRow(
              icon: Icons.add_circle_outline,
              color: Colors.deepOrange,
              title: '特殊日期加價',
              description: '設定連假、節日或指定日期的住宿／安親加價規則。',
              badge: snapshot.enabledSurcharges.isEmpty
                  ? '尚無設定'
                  : '${snapshot.enabledSurcharges.length} 個規則啟用中',
              onTap: onOpenSurcharge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GroupCard(
          id: 'promo',
          title: '優惠與優惠券',
          description: '自動優惠在訂單符合條件時套用；優惠券須先發放給會員後使用。',
          color: Colors.green,
          expanded: desktop || expandedGroups.contains('promo'),
          desktop: desktop,
          onHeaderTap: () => onToggleGroup('promo'),
          children: <Widget>[
            _ToolRow(
              icon: Icons.local_offer_outlined,
              color: Colors.green,
              title: '自動優惠活動',
              description: '訂單符合條件時自動折抵，可指定住宿、安親或兩者。',
              badge: snapshot.enabledCampaigns.isEmpty
                  ? '尚無設定'
                  : '${snapshot.enabledCampaigns.length} 個活動啟用中',
              onTap: onOpenCampaigns,
            ),
            _ToolRow(
              icon: Icons.confirmation_number_outlined,
              color: Colors.deepPurple,
              title: '優惠券模板',
              description: '製作後發放給會員使用，不會自動套用。',
              badge: snapshot.templates.isEmpty
                  ? '尚無設定'
                  : '${snapshot.enabledTemplateCount} 種券模板 · 已發放 ${snapshot.issuedCouponCount} 張',
              onTap: onOpenCoupons,
            ),
          ],
        ),
        const SizedBox(height: 12),
        PointModuleVisibility(
          shopId: shopId,
          enabledChild: _GroupCard(
            id: 'points',
            title: '點數與兌換',
            description: '店內自取商品、庫存與核銷。不提供宅配。',
            color: Colors.blue,
            expanded: desktop || expandedGroups.contains('points'),
            desktop: desktop,
            onHeaderTap: () => onToggleGroup('points'),
            children: <Widget>[
              _ToolRow(
                icon: Icons.redeem_outlined,
                color: Colors.blue,
                title: '點數兌換商品管理',
                description: '管理可兌換的優惠券、住宿券與店內自取實體商品。',
                badge: snapshot.enabledRewards == 0
                    ? '尚無設定'
                    : '${snapshot.enabledRewards} 個商品上架中',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return AdminPointRewardListPage(shopId: shopId);
                      },
                    ),
                  );
                },
              ),
              _ToolRow(
                icon: Icons.inventory_2_outlined,
                color: Colors.blue,
                title: '實體商品核銷中心',
                description: '待領取商品核銷、取消兌換與退回點數。',
                badge: '待核銷 ${snapshot.pendingPickups} 件',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return AdminPointRedemptionListPage(shopId: shopId);
                      },
                    ),
                  );
                },
              ),
              _ToolRow(
                icon: Icons.history_outlined,
                color: Colors.blue,
                title: '點數兌換紀錄',
                description: '查看本月與歷史兌換、扣點與發券結果。',
                badge: snapshot.monthExchangeCount == 0
                    ? '尚無設定'
                    : '本月 ${snapshot.monthExchangeCount} 筆紀錄',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return AdminPointExchangeHistoryPage(shopId: shopId);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.id,
    required this.title,
    required this.description,
    required this.color,
    required this.expanded,
    required this.desktop,
    required this.onHeaderTap,
    required this.children,
  });

  final String id;
  final String title;
  final String description;
  final MaterialColor color;
  final bool expanded;
  final bool desktop;
  final VoidCallback onHeaderTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: desktop ? null : onHeaderTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: color.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!desktop)
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: color.shade700,
                    ),
                ],
              ),
            ),
          ),
          if (expanded) ...children,
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final MaterialColor color;
  final String title;
  final String description;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 8, 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
