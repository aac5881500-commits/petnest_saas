// 檔案名稱：lib/features/shop/pages/shop_booking_setup_center_page.dart
// 功能說明：房型、房間與預約設定整合頁，頂部分頁為房型與房間、預約設定。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_settings_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_rooms_hub.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ShopBookingSetupTab { roomTypes, rooms, booking }

class ShopBookingSetupCenterPage extends StatefulWidget {
  const ShopBookingSetupCenterPage({
    super.key,
    required this.shopId,
    this.initialTab = ShopBookingSetupTab.roomTypes,
  });

  final String shopId;
  final ShopBookingSetupTab initialTab;

  @override
  State<ShopBookingSetupCenterPage> createState() =>
      _ShopBookingSetupCenterPageState();
}

class _ShopBookingSetupCenterPageState
    extends State<ShopBookingSetupCenterPage> {
  final ShopBookingSettingsLeaveGuard _bookingLeaveGuard =
      ShopBookingSettingsLeaveGuard();

  Map<String, dynamic>? _memberData;
  bool _roleLoaded = false;
  ShopBookingSetupTab _tab = ShopBookingSetupTab.roomTypes;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _loadRole();
  }

  Future<void> _loadRole() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) {
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
      if (!mounted) {
        return;
      }
      setState(() {
        _memberData = member;
        _roleLoaded = true;
        _tab = _firstAllowedTab();
      });
    } catch (_) {
      if (!mounted) {
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

  Future<void> _onBack() async {
    if (_can(ShopPermissionKeys.manageBookingSettings)) {
      final bool leave = await _bookingLeaveGuard.confirmLeave();
      if (!leave || !mounted) {
        return;
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
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

    return PopScope(
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
          actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
        ),
        body: Column(
          children: <Widget>[
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: SizedBox(
                height: 48,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool equalTabs = constraints.maxWidth >= 720;
                    final List<Widget> chips = allowed.map((
                      ShopBookingSetupTab tab,
                    ) {
                      final Widget chip = _SetupTabChip(
                        tab: tab,
                        selected: current == tab,
                        onTap: () {
                          setState(() {
                            _tab = tab;
                          });
                        },
                      );
                      if (equalTabs) {
                        return Expanded(child: chip);
                      }
                      return chip;
                    }).toList();
                    if (equalTabs) {
                      return Row(children: chips);
                    }
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: chips,
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: SizedBox(
                    width: double.infinity,
                    child: IndexedStack(
                      index: allowed.indexOf(current),
                      sizing: StackFit.expand,
                      children: allowed.map(_pageForTab).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
          canManageRoomTypes: _can(ShopPermissionKeys.manageRoomTypes),
          canManageRooms: _can(ShopPermissionKeys.manageRooms),
        );
      case ShopBookingSetupTab.booking:
        return ShopBookingSettingsPage(
          key: ValueKey<String>('setup-booking-${widget.shopId}'),
          shopId: widget.shopId,
          embeddedInSetupCenter: true,
          leaveGuard: _bookingLeaveGuard,
        );
    }
  }
}

class _SetupTabChip extends StatelessWidget {
  const _SetupTabChip({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ShopBookingSetupTab tab;
  final bool selected;
  final VoidCallback onTap;

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
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border(
              bottom: BorderSide(
                color: selected ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: selected ? colors.primary : null),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
