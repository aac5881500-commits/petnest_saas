import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/shop_intro_content_status.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
import 'package:petnest_saas/core/legal_pet/shop_profile_lock.dart';
import 'package:petnest_saas/features/shop/pages/shop_basic_info_page.dart';
import 'package:petnest_saas/core/services/shop_intro_guide_progress.dart';
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
    this.loadStayPolicy,
    this.loadIntroStatus,
  });
  final String shopId;
  final Map<String, dynamic> shop;
  final String userId;
  final Stream<StayBookingReadiness>? readinessStream;
  final Future<bool> Function()? loadStayPolicy;
  final Future<Map<String, ShopIntroContentStatus>> Function(String)?
  loadIntroStatus;
  @override
  State<ShopOpeningProgress> createState() => _ShopOpeningProgressState();
}

class _ShopOpeningProgressState extends State<ShopOpeningProgress> {
  bool get _basicComplete =>
      isPhoneSetupCompleted(widget.shop) &&
      isAddressSetupCompleted(widget.shop);
  late Stream<StayBookingReadiness> _stream;
  ShopIntroGuideProgress? _introProgress;
  late Future<void> _introPreferences;
  bool _introSaving = false;
  String? _introPreferenceError;
  AsyncSnapshot<bool> _policyState = const AsyncSnapshot.waiting();
  int _policyRequest = 0;
  bool _canManagePolicy = false;
  Map<String, ShopIntroContentStatus> _intro = {};
  int _introRequest = 0;
  bool _introRefreshing = false;
  ShopDashboardNavigation? _introNavigation;
  bool _introHadDetail = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigation = ShopDashboardNavigationScope.maybeOf(
      context,
    )?.navigation;
    if (navigation != _introNavigation) {
      _introNavigation?.removeListener(_onIntroNavigation);
      _introNavigation = navigation;
      _introHadDetail = navigation?.hasDetail ?? false;
      navigation?.addListener(_onIntroNavigation);
    }
  }

  void _onIntroReturned() {
    if (mounted && ShopIntroContent.returned.value?.$1 == widget.shopId) {
      _reloadIntro();
    }
  }

  void _onIntroNavigation() {
    final detail = _introNavigation?.hasDetail ?? false;
    if (mounted && _introHadDetail && !detail) _reloadIntro();
    _introHadDetail = detail;
  }

  @override
  void dispose() {
    ShopIntroContent.returned.removeListener(_onIntroReturned);
    _introRequest++;
    _introNavigation?.removeListener(_onIntroNavigation);
    super.dispose();
  }

  Future<void> _reloadIntro() async {
    final scope = _key;
    await _introPreferences;
    if (!mounted ||
        scope != _key ||
        _introProgress == null ||
        _introProgress!.ended) {
      return;
    }
    final request = ++_introRequest;
    final shopId = widget.shopId, userId = widget.userId;
    setState(() => _introRefreshing = true);
    Map<String, ShopIntroContentStatus> result;
    try {
      result =
          await (widget.loadIntroStatus?.call(shopId) ??
              ShopIntroContent.load(shopId));
    } catch (_) {
      result = {
        for (final key in ShopIntroContent.keys)
          key: ShopIntroContentStatus.failed,
      };
    }
    if (!mounted ||
        request != _introRequest ||
        widget.shopId != shopId ||
        widget.userId != userId) {
      return;
    }
    final completed = result.entries
        .where(
          (e) =>
              e.value == ShopIntroContentStatus.configured ||
              e.value == ShopIntroContentStatus.unpublished,
        )
        .map((e) => e.key)
        .where((id) => !_introProgress!.handled(id))
        .toSet();
    if (completed.isNotEmpty) await _saveIntro(completed: completed);
    if (!mounted || request != _introRequest || scope != _key) return;
    setState(() {
      _intro = result;
      _introRefreshing = false;
    });
  }

  Future<void> _loadPolicyPermission() async {
    final shopId = widget.shopId;
    final userId = widget.userId;
    try {
      final member = await ShopService.instance.getUserMemberInShop(
        shopId: shopId,
        uid: userId,
      );
      if (mounted && widget.shopId == shopId && widget.userId == userId) {
        setState(
          () => _canManagePolicy = ShopService.instance.hasPermission(
            member,
            ShopPermissionKeys.managePolicy,
          ),
        );
      }
    } catch (_) {
      /* No edit permission is granted on read failure. */
    }
  }

  Future<void> _reloadPolicy() async {
    final request = ++_policyRequest;
    setState(() => _policyState = const AsyncSnapshot.waiting());
    try {
      final ready =
          await (widget.loadStayPolicy?.call() ??
              ShopPolicyService.instance.hasEffectiveStayPolicy(widget.shopId));
      if (mounted && request == _policyRequest) {
        setState(
          () => _policyState = AsyncSnapshot.withData(
            ConnectionState.done,
            ready,
          ),
        );
      }
    } catch (e, stack) {
      if (mounted && request == _policyRequest) {
        setState(
          () => _policyState = AsyncSnapshot.withError(
            ConnectionState.done,
            e,
            stack,
          ),
        );
      }
    }
  }

  String get _key => 'openingOptional:${widget.userId}:${widget.shopId}';
  @override
  void initState() {
    super.initState();
    _reloadPolicy();
    _loadPolicyPermission();
    _stream =
        widget.readinessStream ?? StayBookingReadiness.watch(widget.shopId);
    _introPreferences = _load();
    ShopIntroContent.returned.addListener(_onIntroReturned);
    _reloadIntro();
  }

  @override
  void didUpdateWidget(covariant ShopOpeningProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadStayPolicy != widget.loadStayPolicy &&
        oldWidget.shopId == widget.shopId &&
        oldWidget.userId == widget.userId) {
      _reloadPolicy();
    }
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.userId != widget.userId) {
      _introProgress = null;
      _introPreferenceError = null;
      _introPreferences = _load();
      _canManagePolicy = false;
      _intro = {};
      _reloadIntro();
      _reloadPolicy();
      _loadPolicyPermission();
      _stream =
          widget.readinessStream ?? StayBookingReadiness.watch(widget.shopId);
    }
  }

  Future<void> _load() async {
    final key = _key;
    try {
      final progress = await ShopIntroGuideProgress.load(
        widget.shopId,
        widget.userId,
      );
      if (mounted && key == _key) setState(() => _introProgress = progress);
    } catch (_) {
      if (mounted && key == _key) {
        setState(() => _introPreferenceError = '引導狀態讀取失敗，請重試');
      }
    }
  }

  Future<void> _saveIntro({
    Set<String> completed = const {},
    Set<String> skipped = const {},
    bool dismissed = false,
  }) async {
    final key = _key, shopId = widget.shopId;
    setState(() => _introSaving = true);
    try {
      final progress = await ShopIntroGuideProgress.save(
        shopId,
        completed: completed,
        skipped: skipped,
        dismissed: dismissed,
      );
      if (mounted && key == _key) {
        setState(() {
          _introProgress = progress;
          _introPreferenceError = null;
        });
      }
    } catch (_) {
      if (mounted && key == _key) {
        setState(() => _introPreferenceError = '引導狀態保存失敗，請重試');
      }
    } finally {
      if (mounted && key == _key) setState(() => _introSaving = false);
    }
  }

  Future<void> _openOpeningPolicy() async {
    final key = _key, shopId = widget.shopId, uid = widget.userId;
    final published = await _open(
      ShopPolicyPage(shopId: shopId, continueOpeningAfterPublish: true),
    );
    if (!mounted ||
        key != _key ||
        published != true ||
        FirebaseAuth.instance.currentUser?.uid != uid ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    try {
      final rooms = await StayBookingReadiness.load(shopId);
      final policy = await ShopPolicyService.instance.hasEffectiveStayPolicy(
        shopId,
      );
      final member = await ShopService.instance.getUserMemberInShop(
        shopId: shopId,
        uid: uid,
      );
      if (!mounted ||
          key != _key ||
          FirebaseAuth.instance.currentUser?.uid != uid ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (!rooms.ready ||
          !policy ||
          !ShopService.instance.hasPermission(
            member,
            ShopPermissionKeys.manageBookingSettings,
          )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('條款已發布；請確認可用房間及預約設定權限後繼續。')),
        );
        return;
      }
      await _open(
        ShopBookingSetupCenterPage(
          shopId: shopId,
          initialTab: ShopBookingSetupTab.booking,
          guideStayOpening: true,
        ),
      );
    } catch (_) {
      if (mounted && key == _key) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('條款已發布，預約資格確認失敗，請重新點選前往預約設定。')),
        );
      }
    }
  }

  Future<Object?> _open(Widget page) async {
    final key = _key;
    final desktop =
        ShopDashboardNavigationScope.maybeOf(context)?.desktop == true;
    final result = await Navigator.of(context, rootNavigator: !desktop).push(
      MaterialPageRoute(
        settings: RouteSettings(name: page.runtimeType.toString()),
        builder: (_) => page,
      ),
    );
    if (mounted && key == _key) {
      _reloadIntro();
      _reloadPolicy();
      setState(
        () => _stream =
            widget.readinessStream ?? StayBookingReadiness.watch(widget.shopId),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StreamBuilder<StayBookingReadiness>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!_basicComplete) {
            return _mainCard(null, policyReady: _policyState.data);
          }
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
          if (state.ready &&
              _policyState.data == true &&
              StayBookingReadiness.requested(widget.shop)) {
            return const SizedBox.shrink();
          }
          return _mainCard(
            state,
            policyReady: _policyState.hasError ? null : _policyState.data,
            policyError: _policyState.error,
          );
        },
      ),
      if (_basicComplete) _optionalCard(),
    ],
  );

  Widget _mainCard(
    StayBookingReadiness? state, {
    bool? policyReady,
    Object? policyError,
  }) {
    final colors = Theme.of(context).colorScheme;
    final ready = state?.ready ?? false;
    final current = !_basicComplete
        ? 0
        : ready
        ? (policyReady == true ? 3 : 2)
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
        Text(
          current == 2 ? '設定住宿入住條款' : '準備開放住宿預約',
          style: const TextStyle(
            fontSize: 23,
            height: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          !_basicComplete
              ? '先完成電話與詳細地址，再準備住宿房間。'
              : current == 2
              ? policyError != null
                    ? policyError is FirebaseException &&
                              policyError.code == 'permission-denied'
                          ? '沒有讀取住宿條款的權限，尚無法確認資格。'
                          : '住宿條款讀取失敗，尚無法確認資格。'
                    : policyReady == null
                    ? '正在確認住宿入住條款…'
                    : '請先設定並發布入住條款，讓顧客在預約前了解入住規定。'
              : ready
              ? '房間已準備好，請確認預約設定後手動開放。'
              : state!.reason,
          style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: current == 2
              ? policyError != null
                    ? _reloadPolicy
                    : policyReady == null || !_canManagePolicy
                    ? null
                    : _openOpeningPolicy
              : () => _open(
                  !_basicComplete
                      ? ShopBasicInfoPage(shopId: widget.shopId)
                      : ShopBookingSetupCenterPage(
                          shopId: widget.shopId,
                          guideStayOpening: ready && policyReady == true,
                          initialTab: ready
                              ? ShopBookingSetupTab.booking
                              : ShopBookingSetupTab.roomTypes,
                        ),
                ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: Text(
            !_basicComplete
                ? '前往完善基本資料'
                : current == 2
                ? policyError != null
                      ? '重試條款確認'
                      : '前往條款設定'
                : ready
                ? '前往預約設定'
                : state!.action,
          ),
        ),
        if (current == 2 && !_canManagePolicy)
          const Text('請由店主或有條款管理權限的人完成設定。'),
      ],
    );
    final steps = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(4, (i) {
          final done = i == 2 ? policyReady == true : i < current;
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
                    ['基本資料', '房型與房間', '發布入住條款', '開放住宿預約'][i],
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
    if (_introProgress?.ended == true) return const SizedBox.shrink();
    if (_introProgress == null ||
        (_intro.isEmpty && _introPreferenceError == null)) {
      if (_introPreferenceError == null) return const SizedBox.shrink();
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
                  onPressed: _introSaving
                      ? null
                      : () => _saveIntro(dismissed: true),
                  child: const Text('稍後再說'),
                ),
              ],
            ),
            const Text(
              '可依需求完善店家介紹；公告與常見問題可稍後新增，不影響繼續操作後台。',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (_introPreferenceError != null)
              TextButton(
                onPressed: _introSaving
                    ? null
                    : () async {
                        _introPreferences = _load();
                        await _introPreferences;
                        await _reloadIntro();
                      },
                child: Text(_introPreferenceError!),
              ),
            if (_introRefreshing)
              const Text('正在確認介紹內容…', style: TextStyle(fontSize: 12)),
            if (_intro.values.contains(ShopIntroContentStatus.failed))
              TextButton.icon(
                onPressed: _introRefreshing ? null : _reloadIntro,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('部分內容確認失敗，重試'),
              ),
            if (!ShopPlanService.isPaidActive(widget.shop))
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('以下介紹功能需升級方案解鎖。', style: TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final remaining = ShopIntroContent.keys
                    .where((id) => _introProgress?.handled(id) != true)
                    .length;
                final columns =
                    (constraints.maxWidth >= 1000
                            ? 4
                            : constraints.maxWidth >= 520
                            ? 2
                            : 1)
                        .clamp(1, remaining.clamp(1, 4));
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (_introProgress?.handled('environment') != true)
                      _option(
                        'environment',
                        width,
                        Icons.apartment_rounded,
                        '環境介紹',
                        '展示住宿空間與環境照片',
                        ShopPlanService.canUseEnvironment(widget.shop),
                        () => ShopEnvironmentManagePage(shopId: widget.shopId),
                      ),
                    if (_introProgress?.handled('about') != true)
                      _option(
                        'about',
                        width,
                        Icons.favorite_border_rounded,
                        '關於我們管理',
                        '分享店家特色與照護理念',
                        ShopPlanService.canUseAboutUs(widget.shop),
                        () => ShopAboutManagePage(shopId: widget.shopId),
                      ),
                    if (_introProgress?.handled('announcement') != true)
                      _option(
                        'announcement',
                        width,
                        Icons.campaign_outlined,
                        '公告管理',
                        '發布消息與入住注意事項',
                        ShopPlanService.canUseAnnouncement(widget.shop),
                        () => ShopAnnouncementManagePage(shopId: widget.shopId),
                      ),
                    if (_introProgress?.handled('faq') != true)
                      _option(
                        'faq',
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
    String id,
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
                const SizedBox(height: 6),
                Text(
                  _intro[id] == ShopIntroContentStatus.failed
                      ? '暫時無法確認'
                      : '選填・可稍後設定',
                  style: const TextStyle(fontSize: 12),
                ),
                if (id == 'announcement' || id == 'faq')
                  TextButton(
                    onPressed: _introSaving
                        ? null
                        : () => _saveIntro(skipped: {id}),
                    child: const Text('稍後再說'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
