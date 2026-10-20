import 'package:flutter/material.dart';
import 'package:petnest_saas/core/legal_pet/shop_profile_lock.dart';
import 'package:petnest_saas/features/shop/pages/shop_basic_info_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/stay_booking_readiness.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_setup_center_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_faq_manage_page.dart';

class ShopOpeningProgress extends StatefulWidget {
  const ShopOpeningProgress({
    super.key,
    required this.shopId,
    required this.shop,
    required this.userId,
    this.readinessStream,
  });
  final String shopId;
  final Map<String, dynamic> shop;
  final String userId;
  final Stream<StayBookingReadiness>? readinessStream;
  @override
  State<ShopOpeningProgress> createState() => _ShopOpeningProgressState();
}

class _ShopOpeningProgressState extends State<ShopOpeningProgress> {
  bool get _basicComplete =>
      isPhoneSetupCompleted(widget.shop) &&
      isAddressSetupCompleted(widget.shop);
  late Stream<StayBookingReadiness> _stream;
  bool? _collapsed;
  String get _key => 'openingOptional:${widget.userId}:${widget.shopId}';
  @override
  void initState() {
    super.initState();
    _stream =
        widget.readinessStream ?? StayBookingReadiness.watch(widget.shopId);
    _load();
  }

  @override
  void didUpdateWidget(covariant ShopOpeningProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.userId != widget.userId) {
      _collapsed = null;
      _stream =
          widget.readinessStream ?? StayBookingReadiness.watch(widget.shopId);
      _load();
    }
  }

  Future<void> _load() async {
    final key = _key;
    final prefs = await SharedPreferences.getInstance();
    if (mounted && key == _key) {
      setState(() => _collapsed = prefs.getBool(key) ?? false);
    }
  }

  Future<void> _collapse(bool value) async {
    setState(() => _collapsed = value);
    await (await SharedPreferences.getInstance()).setBool(_key, value);
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      setState(
        () => _stream =
            widget.readinessStream ?? StayBookingReadiness.watch(widget.shopId),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StreamBuilder<StayBookingReadiness>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!_basicComplete) return _mainCard(null);
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('房型與房間讀取失敗，尚無法確認住宿預約條件'),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _stream =
                            widget.readinessStream ??
                            StayBookingReadiness.watch(widget.shopId),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重試'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('正在確認房型與房間…'),
              ),
            );
          }
          final state = snapshot.data!;
          if (state.ready && StayBookingReadiness.requested(widget.shop)) {
            return const SizedBox.shrink();
          }
          return _mainCard(state);
        },
      ),
      if (_collapsed != null && _basicComplete) _optionalCard(),
    ],
  );

  Widget _mainCard(StayBookingReadiness? state) {
    final colors = Theme.of(context).colorScheme;
    final ready = state?.ready ?? false;
    final current = !_basicComplete
        ? 0
        : ready
        ? 2
        : 1;
    final task = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '開店準備 · 第 ${current + 1} 步',
          style: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '準備開放住宿預約',
          style: TextStyle(
            fontSize: 23,
            height: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          !_basicComplete
              ? '先完成電話與詳細地址，再準備住宿房間。'
              : ready
              ? '房間已準備好，請確認預約設定後手動開放。'
              : state!.reason,
          style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _open(
            !_basicComplete
                ? ShopBasicInfoPage(shopId: widget.shopId)
                : ShopBookingSetupCenterPage(
                    shopId: widget.shopId,
                    initialTab: ready
                        ? ShopBookingSetupTab.booking
                        : ShopBookingSetupTab.roomTypes,
                  ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: Text(
            !_basicComplete
                ? '前往完善基本資料'
                : ready
                ? '前往預約設定'
                : state!.action,
          ),
        ),
      ],
    );
    final steps = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(3, (i) {
          final done = i < current;
          final active = i == current;
          final color = done
              ? const Color(0xFF23846B)
              : active
              ? colors.primary
              : const Color(0xFF94A3B8);
          return Padding(
            padding: EdgeInsets.symmetric(vertical: i == 1 ? 12 : 0),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : active
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: color,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ['基本資料', '房型與房間', '開放住宿預約'][i],
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  done
                      ? '已完成'
                      : active
                      ? '進行中'
                      : '待完成',
                  style: TextStyle(color: color, fontSize: 11),
                ),
              ],
            ),
          );
        }),
      ),
    );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.primary.withValues(alpha: .18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 700
              ? Row(
                  children: [
                    Expanded(flex: 6, child: task),
                    const SizedBox(width: 28),
                    Expanded(flex: 5, child: steps),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [task, const SizedBox(height: 18), steps],
                ),
        ),
      ),
    );
  }

  Widget _optionalCard() {
    if (_collapsed!) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _collapse(false),
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: const Text('豐富你的店家介紹（展開）'),
        ),
      );
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE4E9EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '豐富你的店家介紹',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => _collapse(true),
                  child: const Text('稍後再設定'),
                ),
              ],
            ),
            const Text(
              '選填 · 可以依需求慢慢完善，不影響繼續操作後台',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (!ShopPlanService.isPaidActive(widget.shop))
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('以下介紹功能需升級方案解鎖。', style: TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 4
                    : constraints.maxWidth >= 520
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _option(
                      width,
                      Icons.apartment_rounded,
                      '環境介紹',
                      '展示住宿空間與環境照片',
                      ShopPlanService.canUseEnvironment(widget.shop),
                      () => ShopEnvironmentManagePage(shopId: widget.shopId),
                    ),
                    _option(
                      width,
                      Icons.favorite_border_rounded,
                      '關於我們管理',
                      '分享店家特色與照護理念',
                      ShopPlanService.canUseAboutUs(widget.shop),
                      () => ShopAboutManagePage(shopId: widget.shopId),
                    ),
                    _option(
                      width,
                      Icons.campaign_outlined,
                      '公告管理',
                      '發布消息與入住注意事項',
                      ShopPlanService.canUseAnnouncement(widget.shop),
                      () => ShopAnnouncementManagePage(shopId: widget.shopId),
                    ),
                    _option(
                      width,
                      Icons.help_outline_rounded,
                      '常見問題管理',
                      '解答顧客常見的疑問',
                      ShopPlanService.canUseFaq(widget.shop),
                      () => ShopFaqManagePage(shopId: widget.shopId),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    double width,
    IconData icon,
    String title,
    String description,
    bool enabled,
    Widget Function() page,
  ) => SizedBox(
    width: width,
    child: OutlinedButton(
      onPressed: enabled ? () => _open(page()) : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(14),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xFFE4E9EF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
