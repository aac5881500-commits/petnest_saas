// 檔案名稱：lib/features/shop/widgets/inventory/inventory_overview_tab.dart
// 功能說明：顯示品項資訊、庫存概況、快速操作與最近異動。沿用既有進貨／出庫／盤點 Dialog。
// 📦 庫存詳情「總覽」分頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/inventory_movement_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_item_cover.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_movement_tile.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_status_chip.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_stock_dialogs.dart';

class InventoryOverviewTab extends StatelessWidget {
  const InventoryOverviewTab({
    super.key,
    required this.shopId,
    required this.item,
    required this.canReceive,
    required this.canAdjust,
    required this.canViewCost,
    required this.onViewAllMovements,
  });

  final String shopId;
  final InventoryItemModel item;
  final bool canReceive;
  final bool canAdjust;
  final bool canViewCost;
  final VoidCallback onViewAllMovements;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _ItemHeader(item: item),
        const SizedBox(height: 16),
        _SectionLabel(title: '庫存概況'),
        const SizedBox(height: 8),
        _StockSummaryGrid(item: item, canViewCost: canViewCost),
        if (canViewCost) ...<Widget>[
          const SizedBox(height: 8),
          _EstimatedCostBanner(item: item),
        ],
        if (canReceive || canAdjust) ...<Widget>[
          const SizedBox(height: 16),
          _SectionLabel(title: '快速操作'),
          const SizedBox(height: 8),
          _QuickActions(
            item: item,
            canReceive: canReceive,
            canAdjust: canAdjust,
            canViewCost: canViewCost,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            const Expanded(child: _SectionLabel(title: '最近異動')),
            TextButton(
              onPressed: onViewAllMovements,
              child: const Text('查看全部異動'),
            ),
          ],
        ),
        StreamBuilder<List<InventoryMovementModel>>(
          stream: InventoryService.instance.streamMovements(
            shopId: shopId,
            itemId: item.id,
            limit: InventoryConstants.recentMovementLimit,
          ),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<InventoryMovementModel>> snapshot,
              ) {
                final List<InventoryMovementModel> movements =
                    snapshot.data ?? const <InventoryMovementModel>[];

                if (movements.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '尚無異動紀錄',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return Column(
                  children: movements
                      .map(
                        (InventoryMovementModel movement) =>
                            InventoryMovementTile(
                              movement: movement,
                              unit: item.unit,
                            ),
                      )
                      .toList(),
                );
              },
        ),
      ],
    );
  }
}

class _ItemHeader extends StatelessWidget {
  const _ItemHeader({required this.item});

  final InventoryItemModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InventoryItemCover(item: item, size: 84),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                InventoryStatusChip(item: item),
                const SizedBox(height: 8),
                if (item.category.isNotEmpty)
                  _MetaLine(icon: Icons.category_outlined, text: item.category),
                _MetaLine(icon: Icons.straighten, text: '單位 ${item.unit}'),
                if (item.sku.isNotEmpty)
                  _MetaLine(icon: Icons.qr_code_2, text: 'SKU ${item.sku}'),
                if (item.barcode.isNotEmpty)
                  _MetaLine(
                    icon: Icons.qr_code_scanner,
                    text: '條碼 ${item.barcode}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

class _StockSummaryGrid extends StatelessWidget {
  const _StockSummaryGrid({required this.item, required this.canViewCost});

  final InventoryItemModel item;
  final bool canViewCost;

  @override
  Widget build(BuildContext context) {
    final List<_SummaryData> cards = <_SummaryData>[
      _SummaryData(
        label: '目前庫存',
        value: InventoryConstants.formatQuantity(item.currentStock),
        suffix: item.unit,
      ),
      _SummaryData(
        label: '安全庫存',
        value: InventoryConstants.formatQuantity(item.safetyStock),
        suffix: item.unit,
      ),
      if (canViewCost)
        _SummaryData(
          label: '最近進貨價',
          value:
              '\$${InventoryConstants.formatMoney(item.lastPurchaseUnitCost)}',
        ),
      if (canViewCost)
        _SummaryData(
          label: '加權平均成本',
          value:
              '\$${InventoryConstants.formatMoney(item.weightedAverageCost)}',
        ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 720 ? 4 : 2;
        final double gap = 8;
        final double cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map(
                (_SummaryData card) => SizedBox(
                  width: cardWidth,
                  child: _SummaryCard(data: card),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.label,
    required this.value,
    this.suffix = '',
  });

  final String label;
  final String value;
  final String suffix;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            data.label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: data.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (data.suffix.isNotEmpty)
                  TextSpan(
                    text: ' ${data.suffix}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimatedCostBanner extends StatelessWidget {
  const _EstimatedCostBanner({required this.item});

  final InventoryItemModel item;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.payments_outlined, color: colors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '目前庫存估計成本 \$${InventoryConstants.formatMoney(item.estimatedStockCost)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.item,
    required this.canReceive,
    required this.canAdjust,
    required this.canViewCost,
  });

  final InventoryItemModel item;
  final bool canReceive;
  final bool canAdjust;
  final bool canViewCost;

  @override
  Widget build(BuildContext context) {
    final List<Widget> buttons = <Widget>[
      if (canReceive)
        _ActionButton(
          icon: Icons.add_box_outlined,
          label: '進貨',
          filled: true,
          onTap: () {
            showInventoryReceiveDialog(
              context: context,
              item: item,
              canViewCost: canViewCost,
            );
          },
        ),
      if (canAdjust)
        _ActionButton(
          icon: Icons.outbox_outlined,
          label: '出庫',
          onTap: () {
            showInventoryOutboundDialog(context: context, item: item);
          },
        ),
      if (canAdjust)
        _ActionButton(
          icon: Icons.fact_check_outlined,
          label: '盤點',
          onTap: () {
            showInventoryAdjustDialog(context: context, item: item);
          },
        ),
    ];

    return Row(
      children: <Widget>[
        for (int index = 0; index < buttons.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: buttons[index]),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Widget child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 22),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );

    if (filled) {
      return FilledButton(onPressed: onTap, child: child);
    }

    return OutlinedButton(onPressed: onTap, child: child);
  }
}
