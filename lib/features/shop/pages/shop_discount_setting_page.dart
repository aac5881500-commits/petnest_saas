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
import 'package:petnest_saas/features/admin/pages/admin_coupon_template_form_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_discount_campaign_form_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_special_date_surcharge_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/discount_hub_host.dart';

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
    this.coupons = const <MemberCouponModel>[],
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
  final List<MemberCouponModel> coupons;
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

  int get usableCouponCount {
    return coupons
        .where(
          (MemberCouponModel item) =>
              item.status == MemberCouponStatus.available,
        )
        .length;
  }

  List<DiscountCampaignModel> get campaignsEnabledFirst {
    final List<DiscountCampaignModel> items = List<DiscountCampaignModel>.from(
      campaigns,
    );
    items.sort((DiscountCampaignModel a, DiscountCampaignModel b) {
      final bool aOn = DiscountCampaignCalculator.isCampaignCurrentlyActive(a);
      final bool bOn = DiscountCampaignCalculator.isCampaignCurrentlyActive(b);
      if (aOn != bOn) {
        return aOn ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return items;
  }

  _HubSnapshot copyWith({
    List<SpecialDateSurchargeModel>? surcharges,
    List<DiscountCampaignModel>? campaigns,
    List<CouponTemplateModel>? templates,
    List<MemberCouponModel>? coupons,
    int? issuedCouponCount,
    int? enabledRewards,
    int? pendingPickups,
    int? monthExchangeCount,
    String? errorMessage,
    bool? loading,
  }) {
    return _HubSnapshot(
      surcharges: surcharges ?? this.surcharges,
      campaigns: campaigns ?? this.campaigns,
      templates: templates ?? this.templates,
      coupons: coupons ?? this.coupons,
      issuedCouponCount: issuedCouponCount ?? this.issuedCouponCount,
      enabledRewards: enabledRewards ?? this.enabledRewards,
      pendingPickups: pendingPickups ?? this.pendingPickups,
      monthExchangeCount: monthExchangeCount ?? this.monthExchangeCount,
      errorMessage: errorMessage,
      loading: loading ?? this.loading,
    );
  }
}

enum _LeftTab { all, price, campaigns, coupons, points }

class _DiscountSettingHub extends StatefulWidget {
  const _DiscountSettingHub({required this.shopId});

  final String shopId;

  @override
  State<_DiscountSettingHub> createState() => _DiscountSettingHubState();
}

class _DiscountSettingHubState extends State<_DiscountSettingHub> {
  final Set<String> _expandedGroups = <String>{};
  final Set<String> _sectionExpanded = <String>{};
  _LeftTab _leftTab = _LeftTab.all;
  _HubSnapshot _snapshot = const _HubSnapshot();
  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];
  String? _busySurchargeId;
  String? _busyCampaignId;

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
            next = next.copyWith(surcharges: items, loading: false);
            emit();
          }, onError: fail),
    );
    _subs.add(
      DiscountCampaignService.instance.streamCampaigns(widget.shopId).listen((
        List<DiscountCampaignModel> items,
      ) {
        next = next.copyWith(campaigns: items, loading: false);
        emit();
      }, onError: fail),
    );
    _subs.add(
      CouponTemplateService.instance
          .streamTemplates(shopId: widget.shopId)
          .listen((List<CouponTemplateModel> items) {
            next = next.copyWith(templates: items, loading: false);
            emit();
          }, onError: fail),
    );
    _subs.add(
      MemberCouponService.instance.streamShopCoupons(widget.shopId).listen((
        List<MemberCouponModel> items,
      ) {
        next = next.copyWith(
          coupons: items,
          issuedCouponCount: items.length,
          loading: false,
        );
        emit();
      }, onError: fail),
    );
    _subs.add(
      PointRewardService.instance.streamEnabledRewards(widget.shopId).listen((
        List<PointRewardModel> items,
      ) {
        next = next.copyWith(enabledRewards: items.length, loading: false);
        emit();
      }, onError: fail),
    );
    _subs.add(
      PointRedemptionService.instance
          .streamPendingPickups(shopId: widget.shopId)
          .listen((List<PointRedemptionModel> items) {
            next = next.copyWith(pendingPickups: items.length, loading: false);
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
            next = next.copyWith(monthExchangeCount: count, loading: false);
            emit();
          }, onError: fail),
    );
  }

  Future<void> _openSurcharge({SpecialDateSurchargeModel? item}) async {
    await presentDiscountEditor<void>(
      context: context,
      child: ShopSpecialDateSurchargeFormPage(
        shopId: widget.shopId,
        surcharge: item,
      ),
    );
  }

  Future<void> _openCampaign({DiscountCampaignModel? campaign}) async {
    if (campaign == null) {
      await presentDiscountEditor<void>(
        context: context,
        child: ShopDiscountCampaignComposer(shopId: widget.shopId),
      );
      return;
    }
    await presentDiscountEditor<void>(
      context: context,
      child: ShopDiscountCampaignFormPage(
        shopId: widget.shopId,
        campaignType: campaign.type,
        campaign: campaign,
      ),
    );
  }

  Future<void> _openCouponForm({CouponTemplateModel? template}) async {
    await presentDiscountEditor<void>(
      context: context,
      child: AdminCouponTemplateFormPage(
        shopId: widget.shopId,
        template: template,
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

  void _selectTab(_LeftTab tab) {
    setState(() {
      _leftTab = tab;
    });
  }

  Future<void> _toggleSurcharge(
    SpecialDateSurchargeModel item,
    bool enabled,
  ) async {
    if (_busySurchargeId != null) {
      return;
    }
    setState(() {
      _busySurchargeId = item.id;
    });
    try {
      await SpecialDateSurchargeService.instance.setEnabled(
        shopId: widget.shopId,
        surchargeId: item.id,
        enabled: enabled,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ChatErrorProbe.userFacing(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busySurchargeId = null;
        });
      }
    }
  }

  Future<void> _deleteSurcharge(SpecialDateSurchargeModel item) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除特殊日期加價'),
          content: Text('確定要刪除「${item.name}」嗎？已成立訂單金額不會被改寫。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) {
      return;
    }
    try {
      await SpecialDateSurchargeService.instance.deleteSurcharge(
        shopId: widget.shopId,
        surchargeId: item.id,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ChatErrorProbe.userFacing(error))));
    }
  }

  Future<void> _toggleCampaign(DiscountCampaignModel item, bool enabled) async {
    if (_busyCampaignId != null) {
      return;
    }
    setState(() {
      _busyCampaignId = item.id;
    });
    try {
      await DiscountCampaignService.instance.setCampaignEnabled(
        shopId: widget.shopId,
        campaignId: item.id,
        enabled: enabled,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ChatErrorProbe.userFacing(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busyCampaignId = null;
        });
      }
    }
  }

  Future<void> _deleteCampaign(DiscountCampaignModel item) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除優惠活動'),
          content: Text('確定要刪除「${item.name}」嗎？已成立訂單不會被改寫。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) {
      return;
    }
    try {
      await DiscountCampaignService.instance.deleteCampaign(
        shopId: widget.shopId,
        campaignId: item.id,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ChatErrorProbe.userFacing(error))));
    }
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
        final Widget tools = _ToolsColumn(
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
          onSelectPrice: () => _selectTab(_LeftTab.price),
          onSelectCampaigns: () => _selectTab(_LeftTab.campaigns),
          onSelectCoupons: () => _selectTab(_LeftTab.coupons),
          onCreateSurcharge: () => _openSurcharge(),
          onCreateCampaign: () => _openCampaign(),
          onCreateCoupon: () => _openCouponForm(),
        );
        final Widget overview = _OverviewColumn(
          snapshot: _snapshot,
          tab: _leftTab,
          onTab: _selectTab,
          sectionExpanded: _sectionExpanded,
          onToggleSection: (String id) {
            setState(() {
              if (_sectionExpanded.contains(id)) {
                _sectionExpanded.remove(id);
              } else {
                _sectionExpanded.add(id);
              }
            });
          },
          busySurchargeId: _busySurchargeId,
          busyCampaignId: _busyCampaignId,
          onSurcharge: (SpecialDateSurchargeModel item) {
            _openSurcharge(item: item);
          },
          onToggleSurcharge: _toggleSurcharge,
          onDeleteSurcharge: _deleteSurcharge,
          onCampaign: (DiscountCampaignModel item) {
            _openCampaign(campaign: item);
          },
          onToggleCampaign: _toggleCampaign,
          onDeleteCampaign: _deleteCampaign,
          onCoupon: (CouponTemplateModel item) {
            _openCouponForm(template: item);
          },
          onCreateSurcharge: () => _openSurcharge(),
          onCreateCampaign: () => _openCampaign(),
          onOpenCouponDetails: _openCoupons,
        );
        if (desktop) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(flex: 42, child: overview),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 58,
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
            _MobileStats(
              snapshot: _snapshot,
              onSurcharge: () => _showMobilePreview(_LeftTab.price),
              onCampaign: () => _showMobilePreview(_LeftTab.campaigns),
              onCoupon: () => _showMobilePreview(_LeftTab.coupons),
            ),
            const SizedBox(height: 16),
            tools,
          ],
        );
      },
    );
  }

  Future<void> _showMobilePreview(_LeftTab tab) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: _OverviewColumn(
              snapshot: _snapshot,
              tab: tab,
              onTab: (_) {},
              hideTabs: true,
              sectionExpanded: const <String>{
                'surcharge',
                'campaign',
                'coupon',
                'points',
              },
              onToggleSection: (_) {},
              busySurchargeId: _busySurchargeId,
              busyCampaignId: _busyCampaignId,
              onSurcharge: (SpecialDateSurchargeModel item) {
                Navigator.pop(context);
                _openSurcharge(item: item);
              },
              onToggleSurcharge: _toggleSurcharge,
              onDeleteSurcharge: _deleteSurcharge,
              onCampaign: (DiscountCampaignModel item) {
                Navigator.pop(context);
                _openCampaign(campaign: item);
              },
              onToggleCampaign: _toggleCampaign,
              onDeleteCampaign: _deleteCampaign,
              onCoupon: (CouponTemplateModel item) {
                Navigator.pop(context);
                _openCouponForm(template: item);
              },
              onCreateSurcharge: () {
                Navigator.pop(context);
                _openSurcharge();
              },
              onCreateCampaign: () {
                Navigator.pop(context);
                _openCampaign();
              },
              onOpenCouponDetails: () {
                Navigator.pop(context);
                _openCoupons();
              },
            ),
          ),
        );
      },
    );
  }
}

class _MobileStats extends StatelessWidget {
  const _MobileStats({
    required this.snapshot,
    required this.onSurcharge,
    required this.onCampaign,
    required this.onCoupon,
  });

  final _HubSnapshot snapshot;
  final VoidCallback onSurcharge;
  final VoidCallback onCampaign;
  final VoidCallback onCoupon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _MiniStat(
            color: Colors.deepOrange,
            label: '特殊日期加價',
            value: '${snapshot.enabledSurcharges.length}',
            onTap: onSurcharge,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            color: Colors.green,
            label: '啟用活動',
            value: '${snapshot.enabledCampaigns.length}',
            onTap: onCampaign,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            color: Colors.deepPurple,
            label: '可用券模板',
            value: '${snapshot.enabledTemplateCount}',
            onTap: onCoupon,
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
    required this.onTap,
  });

  final MaterialColor color;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
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
        ),
      ),
    );
  }
}

class _OverviewColumn extends StatelessWidget {
  const _OverviewColumn({
    required this.snapshot,
    required this.tab,
    required this.onTab,
    required this.sectionExpanded,
    required this.onToggleSection,
    required this.busySurchargeId,
    required this.busyCampaignId,
    required this.onSurcharge,
    required this.onToggleSurcharge,
    required this.onDeleteSurcharge,
    required this.onCampaign,
    required this.onToggleCampaign,
    required this.onDeleteCampaign,
    required this.onCoupon,
    required this.onCreateSurcharge,
    required this.onCreateCampaign,
    required this.onOpenCouponDetails,
    this.hideTabs = false,
  });

  final _HubSnapshot snapshot;
  final _LeftTab tab;
  final ValueChanged<_LeftTab> onTab;
  final Set<String> sectionExpanded;
  final ValueChanged<String> onToggleSection;
  final String? busySurchargeId;
  final String? busyCampaignId;
  final ValueChanged<SpecialDateSurchargeModel> onSurcharge;
  final void Function(SpecialDateSurchargeModel item, bool enabled)
  onToggleSurcharge;
  final ValueChanged<SpecialDateSurchargeModel> onDeleteSurcharge;
  final ValueChanged<DiscountCampaignModel> onCampaign;
  final void Function(DiscountCampaignModel item, bool enabled)
  onToggleCampaign;
  final ValueChanged<DiscountCampaignModel> onDeleteCampaign;
  final ValueChanged<CouponTemplateModel> onCoupon;
  final VoidCallback onCreateSurcharge;
  final VoidCallback onCreateCampaign;
  final VoidCallback onOpenCouponDetails;
  final bool hideTabs;

  List<T> _visible<T>(List<T> items, String key) {
    if (sectionExpanded.contains(key) || items.length <= 5) {
      return items;
    }
    return items.take(5).toList();
  }

  Widget _more(List<dynamic> items, String key) {
    if (items.length <= 5) {
      return const SizedBox.shrink();
    }
    final bool open = sectionExpanded.contains(key);
    return TextButton(
      onPressed: () => onToggleSection(key),
      child: Text(open ? '收合' : '展開全部 ${items.length} 筆'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showPrice = tab == _LeftTab.all || tab == _LeftTab.price;
    final bool showCampaign = tab == _LeftTab.all || tab == _LeftTab.campaigns;
    final bool showCoupon = tab == _LeftTab.all || tab == _LeftTab.coupons;
    final bool showPoints = tab == _LeftTab.all || tab == _LeftTab.points;
    final List<SpecialDateSurchargeModel> surcharges = tab == _LeftTab.all
        ? snapshot.enabledSurcharges
        : snapshot.surcharges;
    final List<DiscountCampaignModel> campaigns = tab == _LeftTab.all
        ? snapshot.enabledCampaigns
        : snapshot.campaignsEnabledFirst;
    final List<CouponTemplateModel> templates = tab == _LeftTab.all
        ? snapshot.templates
              .where((CouponTemplateModel item) => item.enabled)
              .toList()
        : snapshot.templates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          '目前生效的價格與優惠',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        if (!hideTabs) ...<Widget>[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _tabChip(
                  '全部',
                  _LeftTab.all,
                  snapshot.surcharges.length +
                      snapshot.campaigns.length +
                      snapshot.templates.length,
                ),
                _tabChip('價格規則', _LeftTab.price, snapshot.surcharges.length),
                _tabChip('自動優惠', _LeftTab.campaigns, snapshot.campaigns.length),
                _tabChip('優惠券', _LeftTab.coupons, snapshot.templates.length),
                _tabChip('點數與兌換', _LeftTab.points, snapshot.enabledRewards),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: <Widget>[
              if (showPrice) ..._surchargeBlock(surcharges),
              if (showCampaign) ..._campaignBlock(campaigns),
              if (showCoupon) ..._couponBlock(templates),
              if (showPoints) _pointsBlock(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabChip(String label, _LeftTab value, int count) {
    final bool selected = tab == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text('$label $count'),
        onSelected: (_) => onTab(value),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  List<Widget> _surchargeBlock(List<SpecialDateSurchargeModel> items) {
    return <Widget>[
      const Text('特殊日期加價', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      if (items.isEmpty)
        _EmptyCard(
          title: '尚未設定特殊日期加價',
          actionLabel: '新增加價規則',
          color: Colors.deepOrange,
          onPressed: onCreateSurcharge,
        )
      else ...<Widget>[
        ..._visible(items, 'surcharge').map(_surchargeCard),
        _more(items, 'surcharge'),
      ],
      const SizedBox(height: 12),
    ];
  }

  Widget _surchargeCard(SpecialDateSurchargeModel item) {
    final int days = item.endDate.difference(item.startDate).inDays.abs() + 1;
    final String amount = item.appliesToAccommodation && item.appliesToDaycare
        ? '住宿每晚 +NT\$${item.amountPerNight}・安親每次 +NT\$${item.amountPerNight}'
        : item.appliesToDaycare
        ? '每次／每場 +NT\$${item.amountPerNight}'
        : '每晚 +NT\$${item.amountPerNight}';
    return _ManageCard(
      color: Colors.deepOrange,
      title: item.name,
      lines: <String>[
        '${_dateText(item.startDate)} ～ ${_dateText(item.endDate)}（$days 天）',
        amount,
        '適用服務：${PolicyApplicableService.displayLabel(item.applicableServices)}',
        '適用範圍：${item.roomTypeIds.isEmpty ? '全部房型／方案' : '指定房型／方案'}',
        '可與自動優惠併用：${item.allowCampaignDiscount ? '是' : '否'}',
        '可使用優惠券：${item.allowCoupon ? '是' : '否'}',
        item.enabled ? '啟用中' : '已停用',
      ],
      enabled: item.enabled,
      busy: busySurchargeId == item.id,
      onTap: () => onSurcharge(item),
      onEdit: () => onSurcharge(item),
      onToggle: (bool value) => onToggleSurcharge(item, value),
      onDelete: () => onDeleteSurcharge(item),
    );
  }

  List<Widget> _campaignBlock(List<DiscountCampaignModel> items) {
    return <Widget>[
      const Text('自動優惠活動', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      if (items.isEmpty)
        _EmptyCard(
          title: '尚未建立自動優惠',
          actionLabel: '新增優惠活動',
          color: Colors.green,
          onPressed: onCreateCampaign,
        )
      else ...<Widget>[
        ..._visible(items, 'campaign').map(_campaignCard),
        _more(items, 'campaign'),
      ],
      const SizedBox(height: 12),
    ];
  }

  Widget _campaignCard(DiscountCampaignModel item) {
    final String benefit = DiscountCampaignCustomerCopy.benefitLine(item);
    final String max = item.hasMaximumDiscount
        ? '，最高折抵 NT\$${item.maximumDiscountAmount}'
        : '';
    return _ManageCard(
      color: Colors.green,
      title: item.name,
      lines: <String>[
        _campaignTypeName(item.type),
        '$benefit$max',
        '適用服務：${PolicyApplicableService.displayLabel(item.applicableServices)}',
        '計算範圍：${DiscountCampaignCustomerCopy.applyTargetLabel(item.applyTarget)}',
        _campaignCondition(item),
        '每位會員 ${item.memberUsageLimit == 0 ? '不限次數' : '${item.memberUsageLimit} 次'}'
            '・總名額 ${item.totalUsageLimit == 0 ? '不限' : '${item.totalUsageLimit}'}',
        '可與優惠券併用：${item.allowCouponTogether ? '是' : '否'}',
        DiscountCampaignCalculator.isCampaignCurrentlyActive(item)
            ? '啟用中'
            : '已停用',
      ],
      enabled: item.enabled,
      busy: busyCampaignId == item.id,
      onTap: () => onCampaign(item),
      onEdit: () => onCampaign(item),
      onToggle: (bool value) => onToggleCampaign(item, value),
      onDelete: () => onDeleteCampaign(item),
    );
  }

  List<Widget> _couponBlock(List<CouponTemplateModel> items) {
    return <Widget>[
      const Text('優惠券模板', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('尚未建立優惠券模板'),
        )
      else ...<Widget>[
        ..._visible(items, 'coupon').map((CouponTemplateModel item) {
          final int issued = snapshot.coupons
              .where((MemberCouponModel coupon) => coupon.name == item.name)
              .length;
          final int usable = snapshot.coupons
              .where(
                (MemberCouponModel coupon) =>
                    coupon.name == item.name &&
                    coupon.status == MemberCouponStatus.available,
              )
              .length;
          return _ManageCard(
            color: Colors.deepPurple,
            title: item.name,
            lines: <String>[
              _couponBody(item),
              '有效期限：${item.validDays <= 0 ? '永久有效' : '領取後 ${item.validDays} 天'}',
              '已發放 $issued 張・可使用 $usable 張',
              item.enabled ? '啟用中' : '已停用',
            ],
            enabled: item.enabled,
            showSwitch: false,
            onTap: () => onCoupon(item),
            onEdit: () => onCoupon(item),
          );
        }),
        _more(items, 'coupon'),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: onOpenCouponDetails,
          child: const Text('發券與會員券紀錄'),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _pointsBlock() {
    return _ManageCard(
      color: Colors.blue,
      title: '點數與兌換',
      lines: <String>[
        '上架中 ${snapshot.enabledRewards} 個商品',
        '待核銷 ${snapshot.pendingPickups} 件',
        '本月兌換 ${snapshot.monthExchangeCount} 筆',
        '僅店內自取，不提供宅配',
      ],
      enabled: true,
      showSwitch: false,
      showEdit: false,
      onTap: () {},
    );
  }
}

String _dateText(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _campaignTypeName(DiscountCampaignType type) {
  return switch (type) {
    DiscountCampaignType.newMember => '新會員優惠',
    DiscountCampaignType.longStay => '長住優惠',
    DiscountCampaignType.stayDate => '指定服務日期優惠',
    DiscountCampaignType.roomType => '指定房型／安親方案優惠',
    DiscountCampaignType.minimumAmount => '滿額優惠',
    DiscountCampaignType.limitedTime => '限時下單優惠',
    DiscountCampaignType.googleReview => 'Google 評論優惠',
  };
}

String _campaignCondition(DiscountCampaignModel item) {
  final List<String> parts = <String>[];
  if (item.type == DiscountCampaignType.newMember) {
    parts.add('新會員');
  }
  if (item.minimumAmount > 0) {
    parts.add('最低金額 NT\$${item.minimumAmount}');
  }
  if (item.hasDateRange) {
    parts.add('指定日期');
  }
  if (item.hasRoomTypeLimit) {
    parts.add('指定房型／方案');
  }
  if (item.type == DiscountCampaignType.limitedTime) {
    parts.add('限時下單');
  }
  if (item.minimumNights > 0) {
    parts.add('滿 ${item.minimumNights} 晚');
  }
  return parts.isEmpty ? '無額外條件' : '主要條件：${parts.join('、')}';
}

String _couponBody(CouponTemplateModel item) {
  switch (item.type) {
    case MemberCouponType.percent:
      return DiscountCampaignCustomerCopy.percentOffLabel(item.discountValue);
    case MemberCouponType.fixedAmount:
      return '折抵 NT\$${item.discountValue.round()}';
    case MemberCouponType.freeStay:
      return '免費住宿 ${item.freeStayNights} 晚';
    case MemberCouponType.freeService:
      return item.serviceName.isEmpty ? '免費服務' : item.serviceName;
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

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.color,
    required this.title,
    required this.lines,
    required this.enabled,
    required this.onTap,
    this.onEdit,
    this.onToggle,
    this.onDelete,
    this.busy = false,
    this.showSwitch = true,
    this.showEdit = true,
  });

  final MaterialColor color;
  final String title;
  final List<String> lines;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onDelete;
  final bool busy;
  final bool showSwitch;
  final bool showEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
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
                    if (busy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (showSwitch && onToggle != null)
                      Switch(value: enabled, onChanged: onToggle),
                  ],
                ),
                ...lines.map(
                  (String line) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    if (showEdit)
                      TextButton(onPressed: onEdit, child: const Text('編輯')),
                    const Spacer(),
                    if (onDelete != null)
                      PopupMenuButton<String>(
                        onSelected: (String value) {
                          if (value == 'delete') {
                            onDelete!();
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('刪除'),
                            ),
                          ];
                        },
                      ),
                  ],
                ),
              ],
            ),
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
    required this.onSelectPrice,
    required this.onSelectCampaigns,
    required this.onSelectCoupons,
    required this.onCreateSurcharge,
    required this.onCreateCampaign,
    required this.onCreateCoupon,
  });

  final String shopId;
  final _HubSnapshot snapshot;
  final Set<String> expandedGroups;
  final bool desktop;
  final ValueChanged<String> onToggleGroup;
  final VoidCallback onSelectPrice;
  final VoidCallback onSelectCampaigns;
  final VoidCallback onSelectCoupons;
  final VoidCallback onCreateSurcharge;
  final VoidCallback onCreateCampaign;
  final VoidCallback onCreateCoupon;

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
              onTap: onSelectPrice,
              actionLabel: '新增加價規則',
              onAction: onCreateSurcharge,
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
              onTap: onSelectCampaigns,
              actionLabel: '新增優惠活動',
              onAction: onCreateCampaign,
            ),
            _ToolRow(
              icon: Icons.confirmation_number_outlined,
              color: Colors.deepPurple,
              title: '優惠券模板',
              description: '製作後發放給會員使用，不會自動套用。',
              badge: snapshot.templates.isEmpty
                  ? '尚無設定'
                  : '${snapshot.enabledTemplateCount} 種券模板 · 已發放 ${snapshot.issuedCouponCount} 張',
              onTap: onSelectCoupons,
              actionLabel: '製作優惠券',
              onAction: onCreateCoupon,
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
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final MaterialColor color;
  final String title;
  final String description;
  final String badge;
  final VoidCallback onTap;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            if (actionLabel != null && onAction != null)
              FilledButton(onPressed: onAction, child: Text(actionLabel!))
            else
              const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
