// 檔案名稱：lib/features/shop/widgets/inventory/addon_inventory_binding_editor.dart
// 功能說明：卡片上只顯示庫存連動摘要；實際綁定在 BottomSheet 管理。
// 📦 加購服務庫存連動
// 不改 inventoryBindings schema，也不改扣庫存計算。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_binding_model.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_item_picker_page.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_item_cover.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_status_chip.dart';

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

  List<InventoryBindingModel> get _models {
    return _bindings.map(InventoryBindingModel.fromMap).toList();
  }

  String get _subtitle {
    if (!_useInventory) {
      return '此服務只計費，不會扣庫存';
    }

    final int count = _models.where((InventoryBindingModel item) {
      return item.inventoryItemId.trim().isNotEmpty;
    }).length;

    if (count == 0) {
      return '尚未設定扣除品項';
    }

    return '已綁定 $count 項庫存';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<InventoryBindingModel> namedBindings = _models.where((
      InventoryBindingModel item,
    ) {
      return item.inventoryItemName.trim().isNotEmpty ||
          item.inventoryItemId.trim().isNotEmpty;
    }).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.inventory_2_outlined, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '庫存連動',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '開啟後，此服務售出時會自動扣除指定庫存品項',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _useInventory,
                onChanged: (bool value) {
                  service['useInventory'] = value;
                  service['inventoryBindings'] = _bindings;
                  onChanged();
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 2, bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _useInventory ? _subtitle : '不使用庫存',
                  style: TextStyle(
                    fontSize: 12,
                    color: _useInventory
                        ? colors.primary
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!_useInventory)
                  Text(
                    '此服務只計費，不會扣庫存',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          if (_useInventory) ...<Widget>[
            if (namedBindings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ...namedBindings.take(2).map((InventoryBindingModel item) {
                      final String name = item.inventoryItemName.trim().isEmpty
                          ? '未選擇品項'
                          : item.inventoryItemName;
                      return Text(
                        '$name ×${InventoryConstants.formatQuantity(item.quantityPerUnit)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                        ),
                      );
                    }),
                    if (namedBindings.length > 2)
                      Text(
                        '另有 ${namedBindings.length - 2} 項',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  showAddonInventoryBindingSheet(
                    context: context,
                    shopId: shopId,
                    service: service,
                    onChanged: onChanged,
                  );
                },
                child: const Text('管理庫存綁定'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AddonInventoryStatusChip extends StatelessWidget {
  const AddonInventoryStatusChip({super.key, required this.service});

  final Map<String, dynamic> service;

  @override
  Widget build(BuildContext context) {
    final bool useInventory = service['useInventory'] == true;
    final int count = InventoryBindingModel.listFromValue(
      service['inventoryBindings'],
    ).length;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(
        Icons.inventory_2_outlined,
        size: 16,
        color: useInventory ? colors.primary : Colors.grey.shade600,
      ),
      label: Text(
        useInventory
            ? (count > 0 ? '庫存連動 · 已綁定 $count 項' : '庫存連動 · 尚未綁定')
            : '不使用庫存',
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: useInventory
          ? colors.primary.withValues(alpha: 0.08)
          : Colors.grey.shade100,
      padding: EdgeInsets.zero,
    );
  }
}

Future<void> showAddonInventoryBindingSheet({
  required BuildContext context,
  required String shopId,
  required Map<String, dynamic> service,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF6F8FB),
    builder: (BuildContext sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _AddonInventoryBindingSheet(
          shopId: shopId,
          service: service,
          onChanged: onChanged,
        ),
      );
    },
  );
}

class _AddonInventoryBindingSheet extends StatefulWidget {
  const _AddonInventoryBindingSheet({
    required this.shopId,
    required this.service,
    required this.onChanged,
  });

  final String shopId;
  final Map<String, dynamic> service;
  final VoidCallback onChanged;

  @override
  State<_AddonInventoryBindingSheet> createState() =>
      _AddonInventoryBindingSheetState();
}

class _AddonInventoryBindingSheetState
    extends State<_AddonInventoryBindingSheet> {
  List<Map<String, dynamic>> get _bindings {
    final Object? raw = widget.service['inventoryBindings'];
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Set<String> get _boundItemIds {
    return _bindings
        .map(
          (Map<String, dynamic> item) =>
              (item['inventoryItemId'] ?? '').toString().trim(),
        )
        .where((String id) => id.isNotEmpty)
        .toSet();
  }

  void _commit(List<Map<String, dynamic>> next) {
    widget.service['useInventory'] = true;
    widget.service['inventoryBindings'] = next;
    widget.onChanged();
    setState(() {});
  }

  num? _parseQuantity(String raw, {required bool allowDecimal}) {
    final num? quantity = num.tryParse(raw.trim());
    if (quantity == null || quantity <= 0) {
      return null;
    }

    if (!allowDecimal && quantity % 1 != 0) {
      return null;
    }

    return InventoryConstants.roundQuantity(quantity);
  }

  Future<num?> _editQuantityValue({
    required String itemName,
    required String unit,
    required bool allowDecimal,
    num initial = 1,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: InventoryConstants.formatQuantity(initial <= 0 ? 1 : initial),
    );

    final num? result = await showDialog<num>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('每份扣除數量'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: allowDecimal,
            ),
            decoration: InputDecoration(
              labelText: itemName,
              suffixText: unit.isEmpty ? null : unit,
              helperText: allowDecimal ? '可輸入小數，例如 0.5' : '僅能輸入整數',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final num? quantity = _parseQuantity(
                  controller.text,
                  allowDecimal: allowDecimal,
                );
                if (quantity == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        allowDecimal ? '每份扣除數量必須大於 0' : '每份扣除數量必須為大於 0 的整數',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, quantity);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _addBinding() async {
    final InventoryItemModel? selected = await Navigator.of(context)
        .push<InventoryItemModel>(
          MaterialPageRoute<InventoryItemModel>(
            builder: (BuildContext context) {
              return ShopInventoryItemPickerPage(
                shopId: widget.shopId,
                occupiedItemIds: _boundItemIds,
              );
            },
          ),
        );

    if (selected == null || !mounted) {
      return;
    }

    if (_boundItemIds.contains(selected.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此品項已綁定')));
      return;
    }

    final num? quantity = await _showDeductQuantitySheet(item: selected);
    if (quantity == null) {
      return;
    }

    _commit(<Map<String, dynamic>>[
      ..._bindings,
      <String, dynamic>{
        'inventoryItemId': selected.id,
        'inventoryItemName': selected.name,
        'unit': selected.unit,
        'quantityPerUnit': quantity,
      },
    ]);
  }

  Future<void> _replaceItem(int index) async {
    final Map<String, dynamic> binding = _bindings[index];
    final InventoryBindingModel model = InventoryBindingModel.fromMap(binding);
    final Set<String> occupied = Set<String>.from(_boundItemIds)
      ..remove(model.inventoryItemId);

    final InventoryItemModel? selected = await Navigator.of(context)
        .push<InventoryItemModel>(
          MaterialPageRoute<InventoryItemModel>(
            builder: (BuildContext context) {
              return ShopInventoryItemPickerPage(
                shopId: widget.shopId,
                selectedItemId: model.inventoryItemId,
                occupiedItemIds: occupied,
              );
            },
          ),
        );

    if (selected == null) {
      return;
    }

    if (occupied.contains(selected.id)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此品項已綁定')));
      return;
    }

    num quantity = model.quantityPerUnit;
    if (!selected.allowDecimal && quantity % 1 != 0) {
      quantity = quantity.ceil() < 1 ? 1 : quantity.ceil();
    }

    final List<Map<String, dynamic>> next = <Map<String, dynamic>>[
      ..._bindings,
    ];
    next[index] = <String, dynamic>{
      ...binding,
      'inventoryItemId': selected.id,
      'inventoryItemName': selected.name,
      'unit': selected.unit,
      'quantityPerUnit': quantity,
    };
    _commit(next);
  }

  void _updateQuantity(int index, num quantity) {
    if (quantity <= 0) {
      return;
    }

    final List<Map<String, dynamic>> next = <Map<String, dynamic>>[
      ..._bindings,
    ];
    next[index] = <String, dynamic>{
      ...next[index],
      'quantityPerUnit': InventoryConstants.roundQuantity(quantity),
    };
    _commit(next);
  }

  Future<num?> _showDeductQuantitySheet({
    required InventoryItemModel item,
    num initial = 1,
  }) {
    return showModalBottomSheet<num>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _DeductQuantitySheet(item: item, initial: initial),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> bindings = _bindings;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: StreamBuilder<List<InventoryItemModel>>(
            stream: InventoryService.instance.streamItems(widget.shopId),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<InventoryItemModel>> snapshot,
                ) {
                  final Map<String, InventoryItemModel> itemsById =
                      <String, InventoryItemModel>{
                        for (final InventoryItemModel item
                            in snapshot.data ?? const <InventoryItemModel>[])
                          item.id: item,
                      };
                  final bool itemsLoaded = snapshot.hasData;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                '管理庫存綁定',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '此服務每售出 1 份，系統會依下方設定自動扣除庫存。',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  height: 1.4,
                                ),
                              ),
                              if (bindings.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  '已綁定 ${bindings.length} 項庫存',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (bindings.isEmpty)
                        _EmptyBindingState(onAdd: _addBinding)
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            itemCount: bindings.length,
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const SizedBox(height: 10),
                            itemBuilder: (BuildContext context, int index) {
                              final Map<String, dynamic> binding =
                                  bindings[index];
                              final InventoryBindingModel model =
                                  InventoryBindingModel.fromMap(binding);
                              final InventoryItemModel? item =
                                  itemsById[model.inventoryItemId];

                              return _BoundItemCard(
                                model: model,
                                item: item,
                                itemsLoaded: itemsLoaded,
                                onNudge: (num next) =>
                                    _updateQuantity(index, next),
                                onEditQuantity: () async {
                                  final num?
                                  quantity = await _editQuantityValue(
                                    itemName: model.inventoryItemName.isEmpty
                                        ? '庫存品項'
                                        : model.inventoryItemName,
                                    unit: item?.unit ?? model.unit,
                                    allowDecimal: item?.allowDecimal ?? true,
                                    initial: model.quantityPerUnit,
                                  );
                                  if (quantity != null) {
                                    _updateQuantity(index, quantity);
                                  }
                                },
                                onReplace: () => _replaceItem(index),
                                onRemove: () {
                                  final List<Map<String, dynamic>> next =
                                      <Map<String, dynamic>>[...bindings]
                                        ..removeAt(index);
                                  _commit(next);
                                },
                              );
                            },
                          ),
                        ),
                      if (bindings.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _addBinding,
                              icon: const Icon(Icons.add),
                              label: const Text('新增庫存品項'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.primary,
                                backgroundColor: colors.primary.withValues(
                                  alpha: 0.06,
                                ),
                                side: BorderSide(
                                  color: colors.primary.withValues(alpha: 0.28),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
          ),
        ),
      ),
    );
  }
}

class _EmptyBindingState extends StatelessWidget {
  const _EmptyBindingState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 32,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '尚未綁定庫存品項',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '此服務目前只計費，不會扣除任何庫存。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('選擇庫存品項'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                backgroundColor: colors.primary.withValues(alpha: 0.06),
                side: BorderSide(color: colors.primary.withValues(alpha: 0.28)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundItemCard extends StatelessWidget {
  const _BoundItemCard({
    required this.model,
    required this.item,
    required this.itemsLoaded,
    required this.onNudge,
    required this.onEditQuantity,
    required this.onReplace,
    required this.onRemove,
  });

  final InventoryBindingModel model;
  final InventoryItemModel? item;
  final bool itemsLoaded;
  final ValueChanged<num> onNudge;
  final VoidCallback onEditQuantity;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String name = (item?.name ?? model.inventoryItemName).trim().isEmpty
        ? '尚未選擇庫存品項'
        : (item?.name ?? model.inventoryItemName);
    final String unit = (item?.unit ?? model.unit).trim();
    final bool allowDecimal =
        item?.allowDecimal ?? model.quantityPerUnit % 1 != 0;
    final bool missing = itemsLoaded && item == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (item != null)
                InventoryItemCover(item: item!, size: 56, borderRadius: 12)
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: colors.primary.withValues(alpha: 0.08),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (item != null)
                          InventoryStatusChip(item: item!, showExpiry: false)
                        else if (missing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '找不到品項',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (item != null) ...<Widget>[
                      Text(
                        '目前庫存：${InventoryConstants.formatQuantity(item!.currentStock)} ${item!.unit}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        '安全庫存：${InventoryConstants.formatQuantity(item!.safetyStock)} ${item!.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ] else if (missing)
                      Text(
                        '無法讀取目前庫存',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '每份扣除數量',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                _QuantityStepper(
                  value: model.quantityPerUnit,
                  unit: unit,
                  allowDecimal: allowDecimal,
                  onChanged: onNudge,
                  onEditTap: onEditQuantity,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: onReplace,
                icon: Icon(
                  Icons.edit_outlined,
                  color: colors.primary,
                  size: 18,
                ),
                label: const Text('更換品項'),
              ),
              const Spacer(),
              IconButton(
                tooltip: '移除',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.unit,
    required this.allowDecimal,
    required this.onChanged,
    required this.onEditTap,
  });

  final num value;
  final String unit;
  final bool allowDecimal;
  final ValueChanged<num> onChanged;
  final VoidCallback onEditTap;

  num get _step => allowDecimal ? 0.5 : 1;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final num nextDown = InventoryConstants.roundQuantity(value - _step);
    final bool canDecrease = nextDown > 0;

    return Row(
      children: <Widget>[
        _StepperButton(
          icon: Icons.remove,
          enabled: canDecrease,
          onPressed: () => onChanged(nextDown),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onEditTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
            ),
            child: Text(
              InventoryConstants.formatQuantity(value),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _StepperButton(
          icon: Icons.add,
          enabled: true,
          onPressed: () {
            onChanged(InventoryConstants.roundQuantity(value + _step));
          },
        ),
        if (unit.isNotEmpty) ...<Widget>[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: enabled ? Colors.white : Colors.grey.shade100,
        shape: CircleBorder(
          side: BorderSide(
            color: enabled
                ? colors.primary.withValues(alpha: 0.28)
                : Colors.grey.shade300,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? colors.primary : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

class _DeductQuantitySheet extends StatefulWidget {
  const _DeductQuantitySheet({required this.item, required this.initial});

  final InventoryItemModel item;
  final num initial;

  @override
  State<_DeductQuantitySheet> createState() => _DeductQuantitySheetState();
}

class _DeductQuantitySheetState extends State<_DeductQuantitySheet> {
  late num _quantity;

  @override
  void initState() {
    super.initState();
    final num initial = widget.initial <= 0 ? 1 : widget.initial;
    if (!widget.item.allowDecimal && initial % 1 != 0) {
      _quantity = initial.ceil() < 1 ? 1 : initial.ceil();
    } else {
      _quantity = InventoryConstants.roundQuantity(initial);
    }
  }

  Future<void> _editManually() async {
    final TextEditingController controller = TextEditingController(
      text: InventoryConstants.formatQuantity(_quantity),
    );
    final bool allowDecimal = widget.item.allowDecimal;

    final num? result = await showDialog<num>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('每份扣除數量'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: allowDecimal,
            ),
            decoration: InputDecoration(
              suffixText: widget.item.unit,
              helperText: allowDecimal ? '可輸入小數，例如 0.5' : '僅能輸入整數',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final num? quantity = num.tryParse(controller.text.trim());
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(const SnackBar(content: Text('每份扣除數量必須大於 0')));
                  return;
                }
                if (!allowDecimal && quantity % 1 != 0) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(const SnackBar(content: Text('此品項只能輸入整數')));
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  InventoryConstants.roundQuantity(quantity),
                );
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (result != null) {
      setState(() => _quantity = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InventoryItemModel item = widget.item;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String formatted = InventoryConstants.formatQuantity(_quantity);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '設定扣除數量',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                InventoryItemCover(item: item, size: 56, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '目前庫存：${InventoryConstants.formatQuantity(item.currentStock)} ${item.unit}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '每售出 1 份此服務：',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              '扣除',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            _QuantityStepper(
              value: _quantity,
              unit: item.unit,
              allowDecimal: item.allowDecimal,
              onChanged: (num value) {
                setState(() => _quantity = value);
              },
              onEditTap: _editManually,
            ),
            const SizedBox(height: 12),
            Text(
              '此服務每售出 1 份，將扣除 $formatted ${item.unit}。',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _quantity),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
