import 'package:petnest_saas/features/medication/medication_widgets.dart';
// 檔案名稱：lib/features/admin/pages/admin_booking_list_page.dart
// 功能說明：店家訂單列表頁（住宿／安親分頁）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/widgets/app_state_panel.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/shop_permission_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/admin/pages/admin_create_booking_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_create_daycare_booking_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_paged_booking_list.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_entry_service_card.dart';

class AdminBookingListPage extends StatefulWidget {
  const AdminBookingListPage({
    super.key,
    required this.shopId,
    this.filterType,
    this.initialKind,
    this.onOpenOrder,
    this.selectedOrderId,
    this.canManageStay = true,
    this.canManageDaycare = true,
  });

  final String shopId;
  final String? filterType;
  final String? initialKind;
  final void Function(String, Map<String, dynamic>)? onOpenOrder;
  final bool canManageStay, canManageDaycare;
  final String? selectedOrderId;

  bool get embedded => onOpenOrder != null;

  @override
  State<AdminBookingListPage> createState() => _AdminBookingListPageState();
}

class _AdminBookingListPageState extends State<AdminBookingListPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Map<String, dynamic>?>? _shopSub;
  TabController? _tabController;
  Map<String, dynamic> _shop = <String, dynamic>{};
  bool _shopLoaded = false;
  bool _shopFailed = false;
  bool _daycareOn = false;
  bool _appliedInitialKind = false;

  @override
  void initState() {
    super.initState();
    _listenShop();
  }

  void _listenShop() {
    _shopSub?.cancel();
    _shopSub = ShopService.instance
        .streamShop(widget.shopId)
        .listen(
          (Map<String, dynamic>? shop) {
            if (!mounted) {
              return;
            }
            _shop = shop ?? <String, dynamic>{};
            _shopLoaded = true;
            _shopFailed = false;
            _daycareOn = DaycareSettingsService.instance.isEnabledForShop(
              shop: _shop,
            );
            _syncTabs();
            setState(() {});
          },
          onError: (Object error, StackTrace stack) {
            if (!mounted) return;
            setState(() => _shopFailed = true);
          },
        );
  }

  void _syncTabs() {
    final bool needTabs = _daycareOn && widget.canManageStay && widget.canManageDaycare;
    final bool hadTabs = _tabController != null;
    if (needTabs == hadTabs) {
      return;
    }
    if (needTabs) {
      final int initial =
          !_appliedInitialKind && widget.initialKind == BookingKind.daycare
          ? 1
          : 0;
      _appliedInitialKind = true;
      _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: initial,
      );
      return;
    }
    final TabController? old = _tabController;
    _tabController = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old?.dispose();
    });
  }

  @override
  void dispose() {
    _shopSub?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shopFailed) {
      return Scaffold(
        appBar: widget.embedded ? null : AppBar(title: const Text('訂單管理')),
        body: AppStatePanel(
          title: '訂單管理暫時無法載入',
          message: '請確認網路連線及店家權限後重試。',
          onRetry: () {
            setState(() {
              _shopFailed = false;
              _shopLoaded = false;
            });
            _listenShop();
          },
        ),
      );
    }
    if (!_shopLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final bool showDaycareTab = _daycareOn && _tabController != null;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(widget.embedded ? '訂單' : '訂單管理'),
        bottom: showDaycareTab
            ? TabBar(
                controller: _tabController,
                tabs: <Widget>[
                  const Tab(text: '住宿訂單'),
                  Tab(text: _daycareOn ? '安親訂單' : '待處理安親'),
                ],
              )
            : null,
        actions: <Widget>[
          if (!widget.embedded) IconButton(
            tooltip: '今日用藥待辦',
            icon: const Icon(Icons.medication_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => MedicationTodayPage(shopId: widget.shopId),
              ),
            ),
          ),
          if (!widget.embedded) ShopTaskCenterButton(shopId: widget.shopId),
          _CreateOrderButton(
            shopId: widget.shopId,
            shop: _shop,
            allowStay: widget.canManageStay,
            allowDaycare: widget.canManageDaycare,
          ),
        ],
      ),
      body: showDaycareTab
          ? TabBarView(
              controller: _tabController,
              children: <Widget>[
                _orders(BookingKind.accommodation),
                _orders(BookingKind.daycare),
              ],
            )
          : _orders(widget.canManageStay ? BookingKind.accommodation : BookingKind.daycare),
    );
  }

  Widget _orders(String kind) => AdminPagedBookingList(
    shopId: widget.shopId,
    kind: kind,
    initialFilter: kind == BookingKind.accommodation ? widget.filterType ?? 'active' : 'active',
    onOpenOrder: widget.onOpenOrder,
    selectedOrderId: widget.selectedOrderId,
  );
}

class _CreateOrderButton extends StatelessWidget {
  const _CreateOrderButton({
    required this.shopId,
    required this.shop,
    required this.allowStay,
    required this.allowDaycare,
  });

  final bool allowStay, allowDaycare;

  final String shopId;
  final Map<String, dynamic> shop;

  @override
  Widget build(BuildContext context) {
    final bool daycareOn = DaycareSettingsService.instance.isEnabledForShop(
      shop: shop,
    );
    if (!allowStay && !(allowDaycare && daycareOn)) {
      return const SizedBox.shrink();
    }
    final bool canCreateOrder = ShopPermissionService.canCreateOrder(shop);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilledButton.icon(
        onPressed: canCreateOrder
            ? () async {
                if (!allowStay || !allowDaycare || !daycareOn) {
                  await Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => allowStay
                          ? AdminCreateBookingPage(shopId: shopId)
                          : AdminCreateDaycareBookingPage(shopId: shopId),
                    ),
                  );
                  return;
                }
                final String? choice = await showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                            '新增訂單',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          BookingEntryServiceCard(
                            title: '新增住宿訂單',
                            subtitle: '代客建立入住與退房訂單',
                            imageUrl: '',
                            fallbackIcon: Icons.nights_stay,
                            onTap: () => Navigator.pop(context, 'stay'),
                          ),
                          const SizedBox(height: 12),
                          BookingEntryServiceCard(
                            title: '新增安親訂單',
                            subtitle: '代客建立單日送達與接回訂單',
                            imageUrl: '',
                            fallbackIcon: Icons.wb_sunny_outlined,
                            onTap: () => Navigator.pop(context, 'daycare'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                if (!context.mounted || choice == null) {
                  return;
                }
                await Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => choice == 'daycare'
                        ? AdminCreateDaycareBookingPage(shopId: shopId)
                        : AdminCreateBookingPage(shopId: shopId),
                  ),
                );
              }
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ShopPermissionService.restrictedMessage()),
                  ),
                );
              },
        icon: Icon(canCreateOrder ? Icons.add : Icons.lock_outline),
        label: const Text('新增訂單'),
      ),
    );
  }
}
