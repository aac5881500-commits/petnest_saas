// lib/features/shop/pages/inventory/shop_inventory_item_picker_page.dart
// 📦 中央庫存品項選擇頁
// 功能：加購、點數商品與住宿耗材綁定庫存時，只顯示已啟用品項。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_status_chip.dart';

class ShopInventoryItemPickerPage extends StatefulWidget {
  const ShopInventoryItemPickerPage({
    super.key,
    required this.shopId,
    this.selectedItemId = '',
  });

  final String shopId;
  final String selectedItemId;

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
      appBar: AppBar(title: const Text('選擇庫存品項')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
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
          ),
          Expanded(
            child: StreamBuilder<List<InventoryItemModel>>(
              stream: InventoryService.instance.streamEnabledItems(widget.shopId),
              builder: (
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
                  return const Center(child: Text('沒有可選的庫存品項'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: items.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final InventoryItemModel item = items[index];
                    final bool selected = item.id == widget.selectedItemId;

                    return Card(
                      child: ListTile(
                        dense: true,
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.sku.isEmpty ? '無 SKU' : item.sku}｜庫存 ${InventoryConstants.formatQuantity(item.currentStock)} ${item.unit}',
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : InventoryStatusChip(item: item),
                        onTap: () => Navigator.pop(context, item),
                      ),
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
