// lib/features/shop/pages/inventory/shop_inventory_list_page.dart
// 📦 庫存管理首頁
// 功能：顯示品項總數、低庫存、缺貨，並支援搜尋與狀態篩選。手機優先，卡片保持精簡。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_detail_page.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_item_cover.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_status_chip.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_stock_dialogs.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';

enum _InventoryFilter { all, normal, low, outOfStock, disabled }

class ShopInventoryListPage extends StatefulWidget {
  const ShopInventoryListPage({
    super.key,
    required this.shopId,
    this.memberData,
  });

  final String shopId;
  final Map<String, dynamic>? memberData;

  @override
  State<ShopInventoryListPage> createState() => _ShopInventoryListPageState();
}

class _ShopInventoryListPageState extends State<ShopInventoryListPage> {
  String _keyword = '';
  _InventoryFilter _filter = _InventoryFilter.all;

  bool _can(String key) {
    return ShopService.instance.hasPermission(widget.memberData, key);
  }

  bool get _canManage => _can(ShopPermissionKeys.manageInventory);
  bool get _canReceive =>
      _can(ShopPermissionKeys.receiveInventory) || _canManage;
  bool get _canAdjust => _can(ShopPermissionKeys.adjustInventory) || _canManage;
  bool get _canViewCost => _can(ShopPermissionKeys.viewInventoryCost);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('庫存管理'),
        actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) {
                      return ShopInventoryFormPage(shopId: widget.shopId);
                    },
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<InventoryItemModel>>(
        stream: InventoryService.instance.streamItems(widget.shopId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<InventoryItemModel>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<InventoryItemModel> allItems =
                  snapshot.data ?? const <InventoryItemModel>[];
              final int lowCount = allItems
                  .where(
                    (InventoryItemModel item) =>
                        item.stockStatus == InventoryStockStatus.low,
                  )
                  .length;
              final int outCount = allItems
                  .where(
                    (InventoryItemModel item) =>
                        item.stockStatus == InventoryStockStatus.outOfStock,
                  )
                  .length;

              final List<InventoryItemModel> visible = allItems
                  .where(_matchesKeyword)
                  .where(_matchesFilter)
                  .toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _SummaryChip(label: '品項', value: '${allItems.length}'),
                      const SizedBox(width: 8),
                      _SummaryChip(
                        label: '低庫存',
                        value: '$lowCount',
                        warning: true,
                      ),
                      const SizedBox(width: 8),
                      _SummaryChip(
                        label: '缺貨',
                        value: '$outCount',
                        danger: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: '搜尋名稱、SKU、條碼',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (String value) {
                      setState(() => _keyword = value.trim());
                    },
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _filterChip('全部', _InventoryFilter.all),
                        _filterChip('正常', _InventoryFilter.normal),
                        _filterChip('低庫存', _InventoryFilter.low),
                        _filterChip('缺貨', _InventoryFilter.outOfStock),
                        _filterChip('停用', _InventoryFilter.disabled),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: Text('目前沒有符合條件的庫存品項')),
                    )
                  else
                    ...visible.map(_buildItemCard),
                ],
              );
            },
      ),
    );
  }

  Widget _filterChip(String label, _InventoryFilter value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) {
          setState(() => _filter = value);
        },
      ),
    );
  }

  Widget _buildItemCard(InventoryItemModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (BuildContext context) {
                return ShopInventoryDetailPage(
                  shopId: widget.shopId,
                  itemId: item.id,
                  memberData: widget.memberData,
                );
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InventoryItemCover(item: item, size: 52, borderRadius: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(child: InventoryStatusChip(item: item)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '目前庫存 ${InventoryConstants.formatQuantity(item.currentStock)} ${item.unit}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      '安全庫存 ${InventoryConstants.formatQuantity(item.safetyStock)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (item.sku.isNotEmpty)
                      Text(
                        'SKU ${item.sku}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              if (_canReceive || _canAdjust)
                PopupMenuButton<String>(
                  onSelected: (String value) {
                    switch (value) {
                      case 'receive':
                        showInventoryReceiveDialog(
                          context: context,
                          item: item,
                          canViewCost: _canViewCost,
                        );
                        break;
                      case 'outbound':
                        showInventoryOutboundDialog(
                          context: context,
                          item: item,
                        );
                        break;
                      case 'adjust':
                        showInventoryAdjustDialog(context: context, item: item);
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<String>>[
                      if (_canReceive)
                        const PopupMenuItem<String>(
                          value: 'receive',
                          child: Text('進貨'),
                        ),
                      if (_canAdjust)
                        const PopupMenuItem<String>(
                          value: 'outbound',
                          child: Text('出庫'),
                        ),
                      if (_canAdjust)
                        const PopupMenuItem<String>(
                          value: 'adjust',
                          child: Text('盤點'),
                        ),
                    ];
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesKeyword(InventoryItemModel item) {
    if (_keyword.isEmpty) {
      return true;
    }

    final String keyword = _keyword.toLowerCase();
    return item.name.toLowerCase().contains(keyword) ||
        item.sku.toLowerCase().contains(keyword) ||
        item.barcode.toLowerCase().contains(keyword) ||
        item.category.toLowerCase().contains(keyword);
  }

  bool _matchesFilter(InventoryItemModel item) {
    switch (_filter) {
      case _InventoryFilter.all:
        return true;
      case _InventoryFilter.normal:
        return item.stockStatus == InventoryStockStatus.normal;
      case _InventoryFilter.low:
        return item.stockStatus == InventoryStockStatus.low;
      case _InventoryFilter.outOfStock:
        return item.stockStatus == InventoryStockStatus.outOfStock;
      case _InventoryFilter.disabled:
        return item.stockStatus == InventoryStockStatus.disabled;
    }
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    this.warning = false,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool warning;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color color = danger
        ? Colors.red.shade700
        : warning
        ? Colors.orange.shade800
        : Colors.blueGrey.shade700;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
