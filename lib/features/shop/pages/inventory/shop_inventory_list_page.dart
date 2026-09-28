// 檔案名稱：lib/features/shop/pages/inventory/shop_inventory_list_page.dart
// 功能說明：庫存管理總覽。顯示庫存狀態、連動摘要，並保留進貨、出庫、盤點。
// 📦 庫存管理首頁

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_linkage_service.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_detail_page.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_item_cover.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_linkage_badge.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_status_chip.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_stock_dialogs.dart';

enum _InventoryFilter { all, normal, low, outOfStock, disabled }

enum _LinkFilter { all, linked, unlinked }

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
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<InventoryLinkageSnapshot>? _linkSubscription;

  String _keyword = '';
  _InventoryFilter _filter = _InventoryFilter.all;
  _LinkFilter _linkFilter = _LinkFilter.all;
  InventoryLinkageSnapshot _linkages = const InventoryLinkageSnapshot.pending();

  bool _can(String key) {
    return ShopService.instance.hasPermission(widget.memberData, key);
  }

  bool get _canManage => _can(ShopPermissionKeys.manageInventory);
  bool get _canReceive =>
      _can(ShopPermissionKeys.receiveInventory) || _canManage;
  bool get _canAdjust => _can(ShopPermissionKeys.adjustInventory) || _canManage;
  bool get _canViewCost => _can(ShopPermissionKeys.viewInventoryCost);

  @override
  void initState() {
    super.initState();
    _linkSubscription = InventoryLinkageService.instance
        .watchShop(widget.shopId)
        .listen(
          (InventoryLinkageSnapshot snapshot) {
            if (!mounted) {
              return;
            }
            setState(() => _linkages = snapshot);
          },
          onError: (Object _) {
            if (!mounted) {
              return;
            }
            setState(() {
              _linkages = const InventoryLinkageSnapshot(
                ready: true,
                hasError: true,
                byItemId: <String, List<InventoryLinkage>>{},
              );
            });
          },
        );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('庫存管理'),
        actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _openCreate,
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
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError && !snapshot.hasData) {
                return const Center(child: Text('暫時無法讀取庫存品項'));
              }

              final List<InventoryItemModel> allItems =
                  snapshot.data ?? const <InventoryItemModel>[];
              final List<InventoryItemModel> visible = allItems
                  .where(_matchesKeyword)
                  .where(_matchesFilter)
                  .where(_matchesLink)
                  .toList();

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    children: <Widget>[
                      _StatusSummary(
                        items: allItems,
                        selected: _filter,
                        onSelected: (_InventoryFilter value) {
                          setState(() => _filter = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      _StockAlert(items: allItems),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '搜尋品項、SKU、條碼或分類',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (String value) {
                          setState(() => _keyword = value.trim());
                        },
                      ),
                      const SizedBox(height: 8),
                      _FilterBar(
                        filter: _filter,
                        linkFilter: _linkFilter,
                        linksReady: _linkages.canClassify,
                        onFilter: (_InventoryFilter value) {
                          setState(() => _filter = value);
                        },
                        onLinkFilter: (_LinkFilter value) {
                          setState(() => _linkFilter = value);
                        },
                      ),
                      if (!_linkages.canClassify && _linkages.ready)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '暫時無法讀取連動資訊',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (allItems.isEmpty)
                        _EmptyInventory(
                          canManage: _canManage,
                          onCreate: _openCreate,
                        )
                      else if (visible.isEmpty)
                        _EmptyFilter(
                          onClear: () {
                            _searchController.clear();
                            setState(() {
                              _keyword = '';
                              _filter = _InventoryFilter.all;
                              _linkFilter = _LinkFilter.all;
                            });
                          },
                        )
                      else
                        LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final bool desktop =
                                    constraints.maxWidth >= 1000;
                                if (desktop) {
                                  return _DesktopTable(
                                    items: visible,
                                    linkages: _linkages,
                                    canReceive: _canReceive,
                                    canAdjust: _canAdjust,
                                    canViewCost: _canViewCost,
                                    onOpen: _openDetail,
                                  );
                                }
                                return Column(
                                  children: visible
                                      .map(
                                        (InventoryItemModel item) => _PhoneCard(
                                          item: item,
                                          linkages: _linkages,
                                          canReceive: _canReceive,
                                          canAdjust: _canAdjust,
                                          canViewCost: _canViewCost,
                                          onOpen: () => _openDetail(item),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                        ),
                    ],
                  ),
                ),
              );
            },
      ),
    );
  }

  void _openCreate() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ShopInventoryFormPage(shopId: widget.shopId);
        },
      ),
    );
  }

  void _openDetail(InventoryItemModel item) {
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

  bool _matchesLink(InventoryItemModel item) {
    if (!_linkages.canClassify || _linkFilter == _LinkFilter.all) {
      return true;
    }
    final bool linked = _linkages.countOf(item.id) > 0;
    return _linkFilter == _LinkFilter.linked ? linked : !linked;
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<InventoryItemModel> items;
  final _InventoryFilter selected;
  final ValueChanged<_InventoryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final int normal = _count(InventoryStockStatus.normal);
    final int low = _count(InventoryStockStatus.low);
    final int out = _count(InventoryStockStatus.outOfStock);
    final int disabled = _count(InventoryStockStatus.disabled);
    final List<_SummaryCardData> cards = <_SummaryCardData>[
      _SummaryCardData('品項總數', items.length, _InventoryFilter.all),
      _SummaryCardData('正常庫存', normal, _InventoryFilter.normal),
      _SummaryCardData('低庫存', low, _InventoryFilter.low),
      _SummaryCardData('缺貨', out, _InventoryFilter.outOfStock),
      _SummaryCardData('已停用', disabled, _InventoryFilter.disabled),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1000 ? 5 : 2;
        const double gap = 8;
        final double width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map(
                (_SummaryCardData card) => SizedBox(
                  width: width,
                  child: _SummaryCard(
                    data: card,
                    selected: selected == card.filter,
                    onTap: () => onSelected(card.filter),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  int _count(InventoryStockStatus status) {
    return items
        .where((InventoryItemModel item) => item.stockStatus == status)
        .length;
  }
}

class _SummaryCardData {
  const _SummaryCardData(this.label, this.value, this.filter);

  final String label;
  final int value;
  final _InventoryFilter filter;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _SummaryCardData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color tone = switch (data.filter) {
      _InventoryFilter.low => Colors.orange.shade800,
      _InventoryFilter.outOfStock => Colors.red.shade700,
      _InventoryFilter.disabled => const Color(0xFF667085),
      _ => colors.primary,
    };
    return Material(
      color: selected ? tone.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? tone : const Color(0xFFE4E7EC),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${data.value}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
              Text(
                data.label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockAlert extends StatelessWidget {
  const _StockAlert({required this.items});

  final List<InventoryItemModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final int low = items
        .where(
          (InventoryItemModel item) =>
              item.stockStatus == InventoryStockStatus.low,
        )
        .length;
    final int out = items
        .where(
          (InventoryItemModel item) =>
              item.stockStatus == InventoryStockStatus.outOfStock,
        )
        .length;
    final List<String> parts = <String>[
      if (low > 0) '有 $low 個品項低於安全庫存',
      if (out > 0) '有 $out 個品項已缺貨',
    ];
    final bool healthy = parts.isEmpty;
    final Color color = healthy
        ? Colors.green.shade800
        : Colors.orange.shade900;
    return Row(
      children: <Widget>[
        Icon(
          healthy ? Icons.check_circle_outline : Icons.info_outline,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            healthy ? '目前庫存狀態正常' : parts.join('，'),
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.linkFilter,
    required this.linksReady,
    required this.onFilter,
    required this.onLinkFilter,
  });

  final _InventoryFilter filter;
  final _LinkFilter linkFilter;
  final bool linksReady;
  final ValueChanged<_InventoryFilter> onFilter;
  final ValueChanged<_LinkFilter> onLinkFilter;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _chip('全部', filter == _InventoryFilter.all, () {
            onFilter(_InventoryFilter.all);
          }),
          _chip('正常', filter == _InventoryFilter.normal, () {
            onFilter(_InventoryFilter.normal);
          }),
          _chip('低庫存', filter == _InventoryFilter.low, () {
            onFilter(_InventoryFilter.low);
          }),
          _chip('缺貨', filter == _InventoryFilter.outOfStock, () {
            onFilter(_InventoryFilter.outOfStock);
          }),
          _chip('停用', filter == _InventoryFilter.disabled, () {
            onFilter(_InventoryFilter.disabled);
          }),
          const SizedBox(width: 8),
          _chip(
            linksReady ? '已連動' : '已連動…',
            linksReady && linkFilter == _LinkFilter.linked,
            linksReady
                ? () => onLinkFilter(
                    linkFilter == _LinkFilter.linked
                        ? _LinkFilter.all
                        : _LinkFilter.linked,
                  )
                : null,
          ),
          _chip(
            linksReady ? '未連動' : '未連動…',
            linksReady && linkFilter == _LinkFilter.unlinked,
            linksReady
                ? () => onLinkFilter(
                    linkFilter == _LinkFilter.unlinked
                        ? _LinkFilter.all
                        : _LinkFilter.unlinked,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback? onSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected == null ? null : (_) => onSelected(),
      ),
    );
  }
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.items,
    required this.linkages,
    required this.canReceive,
    required this.canAdjust,
    required this.canViewCost,
    required this.onOpen,
  });

  final List<InventoryItemModel> items;
  final InventoryLinkageSnapshot linkages;
  final bool canReceive;
  final bool canAdjust;
  final bool canViewCost;
  final ValueChanged<InventoryItemModel> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        children: <Widget>[
          const _TableHeader(),
          for (int index = 0; index < items.length; index++) ...<Widget>[
            const Divider(height: 1),
            _TableRow(
              item: items[index],
              linkages: linkages,
              canReceive: canReceive,
              canAdjust: canAdjust,
              canViewCost: canViewCost,
              onOpen: () => onOpen(items[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: <Widget>[
          Expanded(flex: 4, child: _HeaderText('品項')),
          Expanded(flex: 3, child: _HeaderText('現有／可用庫存')),
          Expanded(flex: 2, child: _HeaderText('安全庫存')),
          Expanded(flex: 2, child: _HeaderText('狀態')),
          Expanded(flex: 3, child: _HeaderText('連動用途')),
          SizedBox(width: 168, child: _HeaderText('快速操作')),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF667085),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.item,
    required this.linkages,
    required this.canReceive,
    required this.canAdjust,
    required this.canViewCost,
    required this.onOpen,
  });

  final InventoryItemModel item;
  final InventoryLinkageSnapshot linkages;
  final bool canReceive;
  final bool canAdjust;
  final bool canViewCost;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final String meta = <String>[
      if (item.sku.isNotEmpty) item.sku,
      if (item.category.isNotEmpty) item.category,
    ].join('・');
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 4,
              child: Row(
                children: <Widget>[
                  InventoryItemCover(item: item, size: 36, borderRadius: 8),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (meta.isNotEmpty)
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(flex: 3, child: _StockText(item: item)),
            Expanded(
              flex: 2,
              child: Text(
                '${InventoryConstants.formatQuantity(item.safetyStock)} ${item.unit}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Expanded(flex: 2, child: InventoryStatusChip(item: item)),
            Expanded(
              flex: 3,
              child: InventoryLinkageBadge(snapshot: linkages, item: item),
            ),
            SizedBox(
              width: 168,
              child: _QuickActions(
                item: item,
                canReceive: canReceive,
                canAdjust: canAdjust,
                canViewCost: canViewCost,
                compact: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({
    required this.item,
    required this.linkages,
    required this.canReceive,
    required this.canAdjust,
    required this.canViewCost,
    required this.onOpen,
  });

  final InventoryItemModel item;
  final InventoryLinkageSnapshot linkages;
  final bool canReceive;
  final bool canAdjust;
  final bool canViewCost;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InventoryItemCover(item: item, size: 48, borderRadius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _StockText(item: item),
                    Text(
                      '安全庫存 ${InventoryConstants.formatQuantity(item.safetyStock)} ${item.unit}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        InventoryStatusChip(item: item),
                        InventoryLinkageBadge(snapshot: linkages, item: item),
                      ],
                    ),
                  ],
                ),
              ),
              if (canReceive || canAdjust)
                _QuickActions(
                  item: item,
                  canReceive: canReceive,
                  canAdjust: canAdjust,
                  canViewCost: canViewCost,
                  compact: false,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockText extends StatelessWidget {
  const _StockText({required this.item});

  final InventoryItemModel item;

  @override
  Widget build(BuildContext context) {
    final String unit = item.unit;
    final bool reserved = item.reservedQuantity > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          reserved
              ? '可用 ${InventoryConstants.formatQuantity(item.availableStock)} $unit'
              : '現有 ${InventoryConstants.formatQuantity(item.currentStock)} $unit',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (reserved)
          Text(
            '現有 ${InventoryConstants.formatQuantity(item.currentStock)}／保留 ${InventoryConstants.formatQuantity(item.reservedQuantity)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
          ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.item,
    required this.canReceive,
    required this.canAdjust,
    required this.canViewCost,
    required this.compact,
  });

  final InventoryItemModel item;
  final bool canReceive;
  final bool canAdjust;
  final bool canViewCost;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return PopupMenuButton<String>(
        tooltip: '操作',
        onSelected: (String value) => _run(context, value),
        itemBuilder: (BuildContext context) {
          return <PopupMenuEntry<String>>[
            if (canReceive)
              const PopupMenuItem<String>(value: 'receive', child: Text('進貨')),
            if (canAdjust)
              const PopupMenuItem<String>(value: 'outbound', child: Text('出庫')),
            if (canAdjust)
              const PopupMenuItem<String>(value: 'adjust', child: Text('盤點')),
          ];
        },
      );
    }

    return Wrap(
      spacing: 2,
      children: <Widget>[
        if (canReceive) _mini(context, '進貨', () => _run(context, 'receive')),
        if (canAdjust) _mini(context, '出庫', () => _run(context, 'outbound')),
        if (canAdjust) _mini(context, '盤點', () => _run(context, 'adjust')),
      ],
    );
  }

  Widget _mini(BuildContext context, String label, VoidCallback onTap) {
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  void _run(BuildContext context, String value) {
    switch (value) {
      case 'receive':
        showInventoryReceiveDialog(
          context: context,
          item: item,
          canViewCost: canViewCost,
        );
        break;
      case 'outbound':
        showInventoryOutboundDialog(context: context, item: item);
        break;
      case 'adjust':
        showInventoryAdjustDialog(context: context, item: item);
        break;
    }
  }
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory({required this.canManage, required this.onCreate});

  final bool canManage;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.inventory_2_outlined,
            size: 40,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 10),
          const Text(
            '尚未建立庫存品項',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '先建立常用商品、耗材或可販售商品，再連動到加購服務、點數商品或商城商品。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          if (canManage) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton(onPressed: onCreate, child: const Text('新增庫存品項')),
          ],
        ],
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: <Widget>[
          const Text('沒有符合目前條件的庫存品項'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onClear, child: const Text('清除篩選')),
        ],
      ),
    );
  }
}
