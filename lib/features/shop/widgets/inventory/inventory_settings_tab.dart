// lib/features/shop/widgets/inventory/inventory_settings_tab.dart
// 📦 庫存詳情「設定」分頁
// 功能：集中顯示品項主檔。不可在此修改 currentStock。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_form_page.dart';

class InventorySettingsTab extends StatelessWidget {
  const InventorySettingsTab({
    super.key,
    required this.shopId,
    required this.item,
    required this.canManage,
  });

  final String shopId;
  final InventoryItemModel item;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _Group(
          title: '基本資料',
          children: <Widget>[
            _InfoRow(label: '品項名稱', value: item.name),
            _InfoRow(
              label: '說明',
              value: item.description.isEmpty ? '未填寫' : item.description,
            ),
            _InfoRow(
              label: '分類',
              value: item.category.isEmpty ? '未填寫' : item.category,
            ),
            _InfoRow(label: '單位', value: item.unit),
            _InfoRow(
              label: '安全庫存',
              value:
                  '${InventoryConstants.formatQuantity(item.safetyStock)} ${item.unit}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Group(
          title: '進階資料',
          children: <Widget>[
            _InfoRow(label: 'SKU', value: item.sku.isEmpty ? '未填寫' : item.sku),
            _InfoRow(
              label: '條碼',
              value: item.barcode.isEmpty ? '未填寫' : item.barcode,
            ),
            _InfoRow(label: '允許小數', value: item.allowDecimal ? '是' : '否'),
            _InfoRow(label: '啟用狀態', value: item.enabled ? '啟用' : '停用'),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('目前庫存不可在此直接修改。請使用進貨、手動出庫或盤點調整。'),
        ),
        if (canManage) ...<Widget>[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (BuildContext context) {
                    return ShopInventoryFormPage(shopId: shopId, item: item);
                  },
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('編輯品項'),
          ),
        ],
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
