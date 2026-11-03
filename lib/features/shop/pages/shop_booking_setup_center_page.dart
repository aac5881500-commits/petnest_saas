import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_data_stream.dart';
import 'package:petnest_saas/core/services/stay_booking_readiness.dart';
import 'package:petnest_saas/features/shop/widgets/shop_setup_leave_guard.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_live_preview.dart';
// 檔案名稱：lib/features/shop/pages/shop_booking_setup_center_page.dart
// 功能說明：房型、房間與預約設定整合頁，頂部分頁為房型與房間、預約設定。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_settings_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_rooms_hub.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ShopBookingSetupTab {
  roomTypes,
  rooms,
  booking,
  listAppearance,
  detailAppearance,
  bookingAppearance,
}

class ShopBookingSetupCenterPage extends StatefulWidget {
  const ShopBookingSetupCenterPage({
    super.key,
    required this.shopId,
    this.initialTab = ShopBookingSetupTab.roomTypes,
    this.guideStayOpening = false,
    this.loadMember,
    this.roomTypesStream,
    this.roomsStream,
    this.shopStream,
    this.readinessStream,
    this.actionLogsStream,
    this.saveRoomType,
    this.appBarActions,
  });

  final Future<Map<String, dynamic>?> Function()? loadMember;
  final Stream<List<Map<String, dynamic>>>? roomTypesStream,
      roomsStream,
      actionLogsStream;
  final Stream<Map<String, dynamic>?>? shopStream;
  final Stream<StayBookingReadiness>? readinessStream;
  final Future<String> Function(ShopRoomTypeDraft)? saveRoomType;
  final List<Widget>? appBarActions;
  final String shopId;
  final ShopBookingSetupTab initialTab;
  final bool guideStayOpening;

  @override
  State<ShopBookingSetupCenterPage> createState() =>
      _ShopBookingSetupCenterPageState();
}

class _ShopBookingSetupCenterPageState extends State<ShopBookingSetupCenterPage>
    with ShopDashboardLeaveAware<ShopBookingSetupCenterPage> {
  @override
  bool get dashboardHasUnsavedChanges =>
      (_appearanceKey.currentState?.hasChanges ?? false) ||
      (_bookingAppearanceKey.currentState?.hasChanges ?? false);
  @override
  bool get dashboardIsBusy =>
      _navigating ||
      (_appearanceKey.currentState?.isBusy ?? false) ||
      (_bookingAppearanceKey.currentState?.isBusy ?? false);
  @override
  Future<bool> dashboardConfirmLeave() async {
    if (_navigating) return false;
    _navigating = true;
    try {
      return await _leaveCurrentTab();
    } finally {
      _navigating = false;
    }
  }

  final ShopBookingSettingsLeaveGuard _bookingLeaveGuard =
      ShopBookingSettingsLeaveGuard();

  final ShopSetupLeaveGuard _roomLeaveGuard = ShopSetupLeaveGuard();
  RoomIntroDataStream<Map<String, dynamic>?>? _shopData;
  RoomIntroDataStream<List<Map<String, dynamic>>>? _typesData;
  Stream<Map<String, dynamic>?> get _shopSource =>
      (_shopData ??= RoomIntroDataStream(
        widget.shopStream ?? ShopService.instance.streamShop(widget.shopId),
      )).stream;
  Stream<List<Map<String, dynamic>>> get _typesSource =>
      (_typesData ??= RoomIntroDataStream(
        widget.roomTypesStream ??
            ShopService.instance.streamRoomTypes(widget.shopId),
      )).stream;
  final _appearanceKey = GlobalKey<RoomIntroAppearanceEditorState>();
  final _bookingAppearanceKey = GlobalKey<BookingAppearanceEditorState>();
  bool _bookingAppearanceVisited = false;
  ShopBookingSetupTab? _lastRoomTab;
  ShopBookingSetupTab? _lastBookingTab;
  bool _appearanceVisited = false;
  bool _isAppearance(ShopBookingSetupTab tab) =>
      tab == ShopBookingSetupTab.listAppearance ||
      tab == ShopBookingSetupTab.detailAppearance;
  bool _navigating = false;
  bool _bookingTutorialLocked = false;
  bool _stayOpeningGuide = false;
  Map<String, dynamic>? _memberData;
  bool _roleLoaded = false;
  ShopBookingSetupTab _tab = ShopBookingSetupTab.roomTypes;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _appearanceVisited = _isAppearance(_tab);
    _bookingAppearanceVisited = _tab == ShopBookingSetupTab.bookingAppearance;
    _stayOpeningGuide = widget.guideStayOpening;
    _loadRole();
  }

  @override
  void didUpdateWidget(covariant ShopBookingSetupCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _shopData?.dispose();
      _typesData?.dispose();
      _shopData = null;
      _typesData = null;
      _appearanceVisited = false;
      _roleLoaded = false;
      _memberData = null;
      _tab = widget.initialTab;
      _loadRole();
    }
  }

  @override
  void dispose() {
    _shopData?.dispose();
    _typesData?.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final loadingShopId = widget.shopId;
    if (widget.loadMember != null) {
      try {
        final member = await widget.loadMember!();
        if (!mounted || widget.shopId != loadingShopId) return;
        setState(() {
          _memberData = member;
          _roleLoaded = true;
          _tab = _firstAllowedTab();
          _appearanceVisited = _appearanceVisited || _isAppearance(_tab);
        });
      } catch (_) {
        if (mounted && widget.shopId == loadingShopId) {
          setState(() => _roleLoaded = true);
        }
      }
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted || widget.shopId != loadingShopId) {
        return;
      }
      setState(() {
        _memberData = null;
        _roleLoaded = true;
      });
      return;
    }
    try {
      final Map<String, dynamic>? member = await ShopService.instance
          .getUserMemberInShop(shopId: widget.shopId, uid: user.uid);
      if (!mounted || widget.shopId != loadingShopId) {
        return;
      }
      setState(() {
        _memberData = member;
        _roleLoaded = true;
        _tab = _firstAllowedTab();
        _appearanceVisited = _appearanceVisited || _isAppearance(_tab);
      });
    } catch (_) {
      if (!mounted || widget.shopId != loadingShopId) {
        return;
      }
      setState(() {
        _memberData = null;
        _roleLoaded = true;
      });
    }
  }

  bool _can(String key) {
    return ShopService.instance.hasPermission(_memberData, key);
  }

  List<ShopBookingSetupTab> get _allowedTabs {
    final List<ShopBookingSetupTab> tabs = <ShopBookingSetupTab>[];
    if (_can(ShopPermissionKeys.manageRoomTypes) ||
        _can(ShopPermissionKeys.manageRooms)) {
      tabs.add(ShopBookingSetupTab.roomTypes);
    }
    if (_can(ShopPermissionKeys.manageBookingSettings)) {
      tabs.add(ShopBookingSetupTab.booking);
    }
    if (_can(ShopPermissionKeys.manageFrontendContent)) {
      tabs.addAll([
        ShopBookingSetupTab.listAppearance,
        ShopBookingSetupTab.detailAppearance,
        ShopBookingSetupTab.bookingAppearance,
      ]);
    }
    return tabs;
  }

  ShopBookingSetupTab _normalizedInitialTab() {
    if (widget.initialTab == ShopBookingSetupTab.rooms) {
      return ShopBookingSetupTab.roomTypes;
    }
    return widget.initialTab;
  }

  ShopBookingSetupTab _firstAllowedTab() {
    final List<ShopBookingSetupTab> allowed = _allowedTabs;
    final ShopBookingSetupTab initial = _normalizedInitialTab();
    if (allowed.contains(initial)) {
      return initial;
    }
    if (allowed.isNotEmpty) {
      return allowed.first;
    }
    return ShopBookingSetupTab.roomTypes;
  }

  Future<bool> _leaveCurrentTab() =>
      _tab == ShopBookingSetupTab.bookingAppearance
      ? (_bookingAppearanceKey.currentState?.confirmLeave() ??
            Future.value(true))
      : _isAppearance(_tab)
      ? (_appearanceKey.currentState?.confirmLeave() ?? Future.value(true))
      : _tab == ShopBookingSetupTab.booking
      ? _bookingLeaveGuard.confirmLeave()
      : _roomLeaveGuard.confirmLeave();

  Future<void> _selectTab(ShopBookingSetupTab tab) async {
    if (_appearanceKey.currentState?.isBusy == true ||
        _bookingAppearanceKey.currentState?.isBusy == true) {
      return;
    }
    if (_tab == ShopBookingSetupTab.booking && _bookingTutorialLocked) return;
    if (_navigating || tab == _tab || !_allowedTabs.contains(tab)) return;
    _navigating = true;
    try {
      if ((_isAppearance(_tab) && _isAppearance(tab) ||
              await _leaveCurrentTab()) &&
          mounted) {
        setState(() {
          _tab = tab;
          if (tab == ShopBookingSetupTab.booking ||
              tab == ShopBookingSetupTab.bookingAppearance) {
            _lastBookingTab = tab;
          } else {
            _lastRoomTab = tab;
          }
          if (tab == ShopBookingSetupTab.bookingAppearance) {
            _bookingAppearanceVisited = true;
          }
          if (_isAppearance(tab)) _appearanceVisited = true;
        });
      }
    } finally {
      _navigating = false;
    }
  }

  Future<void> _onBack() async {
    if (_navigating) return;
    _navigating = true;
    try {
      if (await _leaveCurrentTab() && mounted) Navigator.of(context).pop();
    } finally {
      _navigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<ShopBookingSetupTab> allowed = _allowedTabs;
    if (allowed.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('房型與預約設定'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: const Center(child: Text('你沒有管理房型與預約設定的權限')),
      );
    }

    final ShopBookingSetupTab current = allowed.contains(_tab)
        ? _tab
        : allowed.first;

    final originalTabs = allowed.where((tab) => !_isAppearance(tab)).toList();
    final roomTabs = allowed
        .where(
          (tab) => tab == ShopBookingSetupTab.roomTypes || _isAppearance(tab),
        )
        .toList();
    final bookingTabs = allowed
        .where(
          (tab) =>
              tab == ShopBookingSetupTab.booking ||
              tab == ShopBookingSetupTab.bookingAppearance,
        )
        .toList();
    final inBooking = bookingTabs.contains(current);
    final groups = <ShopBookingSetupTab>[
      if (roomTabs.isNotEmpty) ShopBookingSetupTab.roomTypes,
      if (bookingTabs.isNotEmpty) ShopBookingSetupTab.booking,
    ];
    final subTabs = inBooking ? bookingTabs : roomTabs;
    return RoomIntroAppearanceHost(
      shopId: widget.shopId,
      shopStream: _shopSource,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (didPop) {
            return;
          }
          await _onBack();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('房型與預約設定'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _onBack,
            ),
            actions:
                widget.appBarActions ??
                <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
          ),
          body: Column(
            children: <Widget>[
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(14) > 21
                      ? 88
                      : 56,
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final List<Widget> chips = groups.map((
                            ShopBookingSetupTab tab,
                          ) {
                            final Widget chip = _SetupTabChip(
                              tab: tab,
                              primary: true,
                              selected:
                                  tab ==
                                  (inBooking
                                      ? ShopBookingSetupTab.booking
                                      : ShopBookingSetupTab.roomTypes),
                              onTap:
                                  _tab == ShopBookingSetupTab.booking &&
                                      _bookingTutorialLocked
                                  ? null
                                  : () {
                                      final candidates =
                                          tab == ShopBookingSetupTab.booking
                                          ? bookingTabs
                                          : roomTabs;
                                      final last =
                                          tab == ShopBookingSetupTab.booking
                                          ? _lastBookingTab
                                          : _lastRoomTab;
                                      _selectTab(
                                        candidates.contains(last)
                                            ? last!
                                            : candidates.first,
                                      );
                                    },
                            );
                            return Expanded(child: chip);
                          }).toList();
                          return Row(children: chips);
                        },
                  ),
                ),
              ),
              const Divider(height: 1),
              if (subTabs.length > 1)
                SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(13) > 20
                      ? 72
                      : 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: subTabs
                        .map(
                          (tab) => _SetupTabChip(
                            tab: tab,
                            selected: current == tab,
                            onTap: () => _selectTab(tab),
                            labelOverride: tab == ShopBookingSetupTab.roomTypes
                                ? '房型管理'
                                : tab == ShopBookingSetupTab.booking
                                ? '開放與規則'
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: SizedBox(
                      width: double.infinity,
                      child: IndexedStack(
                        index: _isAppearance(current)
                            ? originalTabs.length
                            : originalTabs.indexOf(current),
                        sizing: StackFit.expand,
                        children: [
                          ...originalTabs.map(_pageForTab),
                          if (_can(ShopPermissionKeys.manageFrontendContent))
                            _appearanceVisited
                                ? RoomIntroAppearanceEditor(
                                    key: _appearanceKey,
                                    shopId: widget.shopId,
                                    detailMode:
                                        current ==
                                        ShopBookingSetupTab.detailAppearance,
                                    roomTypesStream: _typesSource,
                                    onManage:
                                        originalTabs.contains(
                                          ShopBookingSetupTab.roomTypes,
                                        )
                                        ? () => _selectTab(
                                            ShopBookingSetupTab.roomTypes,
                                          )
                                        : null,
                                  )
                                : const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageForTab(ShopBookingSetupTab tab) {
    switch (tab) {
      case ShopBookingSetupTab.roomTypes:
      case ShopBookingSetupTab.rooms:
        return ShopRoomTypeRoomsHub(
          key: ValueKey<String>('setup-room-hub-${widget.shopId}'),
          shopId: widget.shopId,
          embeddedInSetupCenter: true,
          leaveGuard: _roomLeaveGuard,
          roomTypesStream: _typesSource,
          roomsStream: widget.roomsStream,
          saveDraft: widget.saveRoomType,
          canManageRoomTypes: _can(ShopPermissionKeys.manageRoomTypes),
          canManageRooms: _can(ShopPermissionKeys.manageRooms),
          canManagePolicy: _can(ShopPermissionKeys.managePolicy) ? null : false,
          isActive:
              _tab == ShopBookingSetupTab.roomTypes ||
              _tab == ShopBookingSetupTab.rooms,
          onOpenBookingSettings: _can(ShopPermissionKeys.manageBookingSettings)
              ? () => _selectTab(ShopBookingSetupTab.booking)
              : null,
          onOpenGuidedBookingSettings:
              _can(ShopPermissionKeys.manageBookingSettings)
              ? () async {
                  setState(() => _stayOpeningGuide = true);
                  await _selectTab(ShopBookingSetupTab.booking);
                }
              : null,
        );
      case ShopBookingSetupTab.bookingAppearance:
        return _bookingAppearanceVisited ||
                _tab == ShopBookingSetupTab.bookingAppearance
            ? BookingAppearanceEditor(
                key: _bookingAppearanceKey,
                shopId: widget.shopId,
                shopStream: _shopSource,
              )
            : const SizedBox.shrink();
      case ShopBookingSetupTab.listAppearance:
      case ShopBookingSetupTab.detailAppearance:
        return const SizedBox.shrink();
      case ShopBookingSetupTab.booking:
        return ShopBookingSettingsPage(
          key: ValueKey<String>('setup-booking-${widget.shopId}'),
          shopId: widget.shopId,
          embeddedInSetupCenter: true,
          leaveGuard: _bookingLeaveGuard,
          guideStayOpening: _stayOpeningGuide,
          isActive: _tab == ShopBookingSetupTab.booking,
          onTutorialLockChanged: (locked) {
            if (mounted && locked != _bookingTutorialLocked) {
              setState(() => _bookingTutorialLocked = locked);
            }
          },
          onManageRooms: () => _selectTab(ShopBookingSetupTab.roomTypes),
          onReturnToOpening: _onBack,
          loadMember: widget.loadMember,
          shopStream: _shopSource,
          readinessStream: widget.readinessStream,
          actionLogsStream: widget.actionLogsStream,
        );
    }
  }
}

class _SetupTabChip extends StatelessWidget {
  const _SetupTabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.labelOverride,
    this.primary = false,
  });

  final ShopBookingSetupTab tab;
  final bool selected;
  final VoidCallback? onTap;
  final String? labelOverride;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final IconData icon;
    final String label;
    switch (tab) {
      case ShopBookingSetupTab.roomTypes:
      case ShopBookingSetupTab.rooms:
        icon = Icons.home_work_outlined;
        label = '房型與房間';
        break;
      case ShopBookingSetupTab.booking:
        icon = Icons.calendar_month_outlined;
        label = '預約設定';
        break;
      case ShopBookingSetupTab.listAppearance:
        icon = Icons.view_list_outlined;
        label = '房型列表外觀';
        break;
      case ShopBookingSetupTab.detailAppearance:
        icon = Icons.article_outlined;
        label = '房型詳細頁外觀';
        break;
      case ShopBookingSetupTab.bookingAppearance:
        icon = Icons.palette_outlined;
        label = '預約頁外觀';
        break;
    }
    if (primary) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? colors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        labelOverride ?? label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: selected
                              ? colors.onPrimaryContainer
                              : colors.onSurfaceVariant,
                        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                labelOverride ?? label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
