// lib/features/shop/pages/inventory/shop_inventory_item_picker_page.dart
// 📦 中央庫存品項選擇頁
// 功能：加購、點數商品與住宿耗材綁定庫存時，只顯示已啟用品項。
// 已綁定的品項可標示「已加入」並禁止再選，避免同一服務重複綁定。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_item_cover.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_status_chip.dart';

class ShopInventoryItemPickerPage extends StatefulWidget {
  const ShopInventoryItemPickerPage({
    super.key,
    required this.shopId,
    this.selectedItemId = '',
    this.occupiedItemIds = const <String>{},
  });

  final String shopId;
  final String selectedItemId;
  final Set<String> occupiedItemIds;

  @override
  State<ShopInventoryItemPickerPage> createState() =>
      _ShopInventoryItemPickerPageState();
}

class _ShopInventoryItemPickerPageState
    extends State<ShopInventoryItemPickerPage> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(title: const Text('選擇庫存品項')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜尋品項名稱 / SKU / 條碼',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                isDense: true,
              ),
              onChanged: (String value) {
                setState(() => _keyword = value.trim());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<InventoryItemModel>>(
              stream: InventoryService.instance.streamEnabledItems(
                widget.shopId,
              ),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<InventoryItemModel>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<InventoryItemModel> items =
                        (snapshot.data ?? const <InventoryItemModel>[])
                            .where(_matchesKeyword)
                            .toList();

                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          '沒有可選的庫存品項',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        return _PickerItemTile(
                          item: items[index],
                          selected: items[index].id == widget.selectedItemId,
                          occupied:
                              widget.occupiedItemIds.contains(
                                items[index].id,
                              ) &&
                              items[index].id != widget.selectedItemId,
                        );
                      },
                    );
                  },
            ),
          ),
        ],
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
        item.barcode.toLowerCase().contains(keyword);
  }
}

class _PickerItemTile extends StatelessWidget {
  const _PickerItemTile({
    required this.item,
    required this.selected,
    required this.occupied,
  });

  final InventoryItemModel item;
  final bool selected;
  final bool occupied;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool enabled = !occupied;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? () => Navigator.pop(context, item) : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.primary : Colors.grey.shade200,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InventoryItemCover(item: item, size: 56, borderRadius: 12),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU：${item.sku.isEmpty ? '無' : item.sku}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '單位：${item.unit.trim().isEmpty ? '個' : item.unit.trim()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '目前庫存：${InventoryConstants.formatQuantity(item.currentStock)} ${item.unit}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        '安全庫存：${InventoryConstants.formatQuantity(item.safetyStock)} ${item.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (occupied)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '已加入',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                      )
                    else
                      InventoryStatusChip(item: item, showExpiry: false),
                    if (selected && !occupied)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.check_circle,
                          color: colors.primary,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
