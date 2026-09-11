// 檔案名稱：lib/features/admin/pages/admin_booking_list_page.dart
// 功能說明：店家訂單列表頁（住宿／安親分頁）

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';
import 'package:petnest_saas/core/services/shop_permission_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/admin/pages/admin_create_booking_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_create_daycare_booking_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_daycare_order_list.dart';
import 'package:petnest_saas/features/admin/widgets/admin_paged_booking_list.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_entry_service_card.dart';

class AdminBookingListPage extends StatefulWidget {
  const AdminBookingListPage({
    super.key,
    required this.shopId,
    this.filterType,
    this.initialKind,
  });

  final String shopId;
  final String? filterType;
  final String? initialKind;

  @override
  State<AdminBookingListPage> createState() => _AdminBookingListPageState();
}

class _AdminBookingListPageState extends State<AdminBookingListPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Map<String, dynamic>?>? _shopSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _openDaycareSub;
  TabController? _tabController;
  Map<String, dynamic> _shop = <String, dynamic>{};
  bool _shopLoaded = false;
  bool _daycareOn = false;
  bool _hasOpenDaycare = false;
  bool _appliedInitialKind = false;

  @override
  void initState() {
    super.initState();
    _shopSub = ShopService.instance.streamShop(widget.shopId).listen((
      Map<String, dynamic>? shop,
    ) {
      if (!mounted) {
        return;
      }
      _shop = shop ?? <String, dynamic>{};
      _shopLoaded = true;
      _daycareOn = DaycareSettingsService.instance.isEnabledForShop(
        shop: _shop,
      );
      _syncTabs();
      setState(() {});
    });
    _openDaycareSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: widget.shopId)
        .where('bookingKind', isEqualTo: BookingKind.daycare)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snap) {
          if (!mounted) {
            return;
          }
          final bool hasOpen = snap.docs.any((
            QueryDocumentSnapshot<Map<String, dynamic>> doc,
          ) {
            return !DaycareStatusLabels.isHistory(doc.data());
          });
          if (hasOpen == _hasOpenDaycare) {
            return;
          }
          _hasOpenDaycare = hasOpen;
          _syncTabs();
          setState(() {});
        });
  }

  void _syncTabs() {
    final bool needTabs = _daycareOn || _hasOpenDaycare;
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
    _openDaycareSub?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shopLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final bool showDaycareTab =
        (_daycareOn || _hasOpenDaycare) && _tabController != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單管理'),
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
          ShopTaskCenterButton(shopId: widget.shopId),
          _CreateOrderButton(shopId: widget.shopId, shop: _shop),
        ],
      ),
      body: showDaycareTab
          ? TabBarView(
              controller: _tabController,
              children: <Widget>[
                AdminPagedBookingList(
                  shopId: widget.shopId,
                  kind: BookingKind.accommodation,
                  initialFilter: widget.filterType ?? 'pending',
                ),
                AdminDaycareOrderList(shopId: widget.shopId),
              ],
            )
          : AdminPagedBookingList(
              shopId: widget.shopId,
              kind: BookingKind.accommodation,
              initialFilter: widget.filterType ?? 'pending',
            ),
    );
  }
}

class _CreateOrderButton extends StatelessWidget {
  const _CreateOrderButton({required this.shopId, required this.shop});

  final String shopId;
  final Map<String, dynamic> shop;

  @override
  Widget build(BuildContext context) {
    final bool canCreateOrder = ShopPermissionService.canCreateOrder(shop);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: canCreateOrder
            ? () async {
                final bool daycareOn = DaycareSettingsService.instance
                    .isEnabledForShop(shop: shop);
                if (!context.mounted) {
                  return;
                }
                if (!daycareOn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AdminCreateBookingPage(shopId: shopId),
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
                Navigator.push(
                  context,
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
        label: const Text('手動新增訂單'),
      ),
    );
  }
}
