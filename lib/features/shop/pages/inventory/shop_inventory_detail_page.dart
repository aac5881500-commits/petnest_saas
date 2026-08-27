// lib/features/shop/pages/inventory/shop_inventory_detail_page.dart
// 📦 庫存品項詳情頁
// 功能：手機優先的分頁式詳情。總覽、進貨紀錄、異動流水、設定分開，不改庫存計算邏輯。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_batches_tab.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_movements_tab.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_overview_tab.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_settings_tab.dart';

class ShopInventoryDetailPage extends StatefulWidget {
  const ShopInventoryDetailPage({
    super.key,
    required this.shopId,
    required this.itemId,
    this.memberData,
  });

  final String shopId;
  final String itemId;
  final Map<String, dynamic>? memberData;

  @override
  State<ShopInventoryDetailPage> createState() => _ShopInventoryDetailPageState();
}

class _ShopInventoryDetailPageState extends State<ShopInventoryDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _can(String key) {
    return ShopService.instance.hasPermission(widget.memberData, key);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage = _can(ShopPermissionKeys.manageInventory);
    final bool canReceive =
        _can(ShopPermissionKeys.receiveInventory) || canManage;
    final bool canAdjust =
        _can(ShopPermissionKeys.adjustInventory) || canManage;
    final bool canViewCost = _can(ShopPermissionKeys.viewInventoryCost);
    final double pageWidth = MediaQuery.sizeOf(context).width;
    final bool compactTabs = pageWidth < 430;

    return StreamBuilder<InventoryItemModel?>(
      stream: InventoryService.instance.streamItem(
        shopId: widget.shopId,
        itemId: widget.itemId,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<InventoryItemModel?> snapshot,
      ) {
        final InventoryItemModel? item = snapshot.data;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F8FB),
          appBar: AppBar(
            title: Text(item?.name ?? '庫存詳情'),
            actions: <Widget>[
              if (canManage && item != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) {
                          return ShopInventoryFormPage(
                            shopId: widget.shopId,
                            item: item,
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: compactTabs,
              tabAlignment: compactTabs
                  ? TabAlignment.start
                  : TabAlignment.fill,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const <Widget>[
                Tab(text: '總覽'),
                Tab(text: '進貨紀錄'),
                Tab(text: '異動流水'),
                Tab(text: '設定'),
              ],
            ),
          ),
          body: item == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    InventoryOverviewTab(
                      shopId: widget.shopId,
                      item: item,
                      canReceive: canReceive,
                      canAdjust: canAdjust,
                      canViewCost: canViewCost,
                      onViewAllMovements: () => _tabController.animateTo(2),
                    ),
                    InventoryBatchesTab(
                      shopId: widget.shopId,
                      item: item,
                      canViewCost: canViewCost,
                    ),
                    InventoryMovementsTab(
                      shopId: widget.shopId,
                      item: item,
                    ),
                    InventorySettingsTab(
                      shopId: widget.shopId,
                      item: item,
                      canManage: canManage,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
