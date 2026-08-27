// lib/features/shop/widgets/inventory/addon_inventory_binding_editor.dart
// 📦 加購服務中央庫存綁定編輯器
// 功能：加值、客製與每日分時段服務可選不使用庫存，或綁定多個中央庫存品項。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/inventory_binding_model.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_item_picker_page.dart';

class AddonInventoryBindingEditor extends StatelessWidget {
  const AddonInventoryBindingEditor({
    super.key,
    required this.shopId,
    required this.service,
    required this.onChanged,
  });

  final String shopId;
  final Map<String, dynamic> service;
  final VoidCallback onChanged;

  bool get _useInventory => service['useInventory'] == true;

  List<Map<String, dynamic>> get _bindings {
    final Object? raw = service['inventoryBindings'];
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '使用中央庫存',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            '關閉時與原本加購流程相同，不扣除庫存。',
            style: TextStyle(fontSize: 12),
          ),
          value: _useInventory,
          onChanged: (bool value) {
            service['useInventory'] = value;
            service['inventoryBindings'] = _bindings;
            onChanged();
          },
        ),
        if (_useInventory) ...<Widget>[
          const Text(
            '可綁定多個庫存品項。顧客購買 2 份時，會依每份數量加倍扣除。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ..._bindings.asMap().entries.map((
            MapEntry<int, Map<String, dynamic>> entry,
          ) {
            final int index = entry.key;
            final Map<String, dynamic> binding = entry.value;
            final InventoryBindingModel model = InventoryBindingModel.fromMap(
              binding,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            model.inventoryItemName.isEmpty
                                ? '尚未選擇庫存品項'
                                : model.inventoryItemName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: '移除',
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            final List<Map<String, dynamic>> next = [..._bindings]
                              ..removeAt(index);
                            service['inventoryBindings'] = next;
                            onChanged();
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final InventoryItemModel? selected =
                                  await Navigator.of(context)
                                      .push<InventoryItemModel>(
                                MaterialPageRoute<InventoryItemModel>(
                                  builder: (BuildContext context) {
                                    return ShopInventoryItemPickerPage(
                                      shopId: shopId,
                                      selectedItemId: model.inventoryItemId,
                                    );
                                  },
                                ),
                              );

                              if (selected == null) {
                                return;
                              }

                              binding['inventoryItemId'] = selected.id;
                              binding['inventoryItemName'] = selected.name;
                              binding['unit'] = selected.unit;
                              onChanged();
                            },
                            child: Text(
                              model.inventoryItemId.isEmpty ? '選擇品項' : '更換品項',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            initialValue: model.quantityPerUnit.toString(),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: '每份數量',
                              suffixText: model.unit,
                            ),
                            onChanged: (String value) {
                              binding['quantityPerUnit'] =
                                  num.tryParse(value) ?? 1;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () {
              final List<Map<String, dynamic>> next = [..._bindings]
                ..add(<String, dynamic>{
                  'inventoryItemId': '',
                  'inventoryItemName': '',
                  'unit': '',
                  'quantityPerUnit': 1,
                });
              service['inventoryBindings'] = next;
              onChanged();
            },
            icon: const Icon(Icons.add),
            label: const Text('新增庫存品項'),
          ),
        ],
      ],
    );
  }
}
