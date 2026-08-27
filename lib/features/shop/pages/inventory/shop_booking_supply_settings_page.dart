// lib/features/shop/pages/inventory/shop_booking_supply_settings_page.dart
// 🧹 住宿耗材／必要用品設定頁
// 功能：可手動記錄一般用品，或綁定中央庫存並設定每房／每寵物、每晚／每次入住的扣除方式。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/booking_supply_setting_model.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/booking_supply_setting_service.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_item_picker_page.dart';

class ShopBookingSupplySettingsPage extends StatelessWidget {
  const ShopBookingSupplySettingsPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('住宿耗材設定')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _openEditor(context: context);
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<BookingSupplySettingModel>>(
        stream: BookingSupplySettingService.instance.streamSettings(shopId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<BookingSupplySettingModel>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<BookingSupplySettingModel> settings =
              snapshot.data ?? const <BookingSupplySettingModel>[];

          if (settings.isEmpty) {
            return const Center(child: Text('尚未設定住宿耗材。可先新增手動用品或綁定中央庫存。'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: settings.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final BookingSupplySettingModel setting = settings[index];
              return Card(
                child: ListTile(
                  title: Text(setting.name),
                  subtitle: Text(
                    [
                      setting.useInventory
                          ? '中央庫存：${setting.inventoryItemName.isEmpty ? setting.inventoryItemId : setting.inventoryItemName}'
                          : '不管理庫存',
                      '${InventoryConstants.deductionModeLabel(setting.deductionMode)} ${InventoryConstants.formatQuantity(setting.quantityPerUnit)} ${setting.unit}',
                      setting.enabled ? '啟用' : '停用',
                    ].join('｜'),
                  ),
                  onTap: () {
                    _openEditor(context: context, setting: setting);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor({
    required BuildContext context,
    BookingSupplySettingModel? setting,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _BookingSupplyEditorPage(shopId: shopId, setting: setting);
        },
      ),
    );
  }
}

class _BookingSupplyEditorPage extends StatefulWidget {
  const _BookingSupplyEditorPage({
    required this.shopId,
    this.setting,
  });

  final String shopId;
  final BookingSupplySettingModel? setting;

  @override
  State<_BookingSupplyEditorPage> createState() =>
      _BookingSupplyEditorPageState();
}

class _BookingSupplyEditorPageState extends State<_BookingSupplyEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _noteController;
  late bool _useInventory;
  late bool _enabled;
  late BookingSupplyDeductionMode _mode;
  String _inventoryItemId = '';
  String _inventoryItemName = '';
  String _unit = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final BookingSupplySettingModel? setting = widget.setting;
    _nameController = TextEditingController(text: setting?.name ?? '');
    _quantityController = TextEditingController(
      text: setting == null ? '1' : setting.quantityPerUnit.toString(),
    );
    _noteController = TextEditingController(text: setting?.note ?? '');
    _useInventory = setting?.useInventory ?? false;
    _enabled = setting?.enabled ?? true;
    _mode = setting?.deductionMode ?? BookingSupplyDeductionMode.perRoomPerNight;
    _inventoryItemId = setting?.inventoryItemId ?? '';
    _inventoryItemName = setting?.inventoryItemName ?? '';
    _unit = setting?.unit ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      await BookingSupplySettingService.instance.saveSetting(
        shopId: widget.shopId,
        settingId: widget.setting?.id,
        name: _nameController.text,
        useInventory: _useInventory,
        inventoryItemId: _inventoryItemId,
        inventoryItemName: _inventoryItemName,
        unit: _unit,
        quantityPerUnit: num.tryParse(_quantityController.text.trim()) ?? 0,
        deductionMode: _mode,
        enabled: _enabled,
        note: _noteController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存住宿耗材設定')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(InventoryException.userMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setting == null ? '新增住宿耗材' : '編輯住宿耗材'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '用品名稱',
              hintText: '例如：豆腐砂',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('使用中央庫存'),
            subtitle: const Text('關閉時只作為用品紀錄，不扣除庫存'),
            value: _useInventory,
            onChanged: (bool value) {
              setState(() => _useInventory = value);
            },
          ),
          if (_useInventory) ...<Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _inventoryItemName.isEmpty ? '選擇庫存品項' : _inventoryItemName,
              ),
              subtitle: Text(_inventoryItemId.isEmpty ? '尚未選擇' : '單位：$_unit'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final InventoryItemModel? selected = await Navigator.of(context)
                    .push<InventoryItemModel>(
                  MaterialPageRoute<InventoryItemModel>(
                    builder: (BuildContext context) {
                      return ShopInventoryItemPickerPage(
                        shopId: widget.shopId,
                        selectedItemId: _inventoryItemId,
                      );
                    },
                  ),
                );

                if (selected == null) {
                  return;
                }

                setState(() {
                  _inventoryItemId = selected.id;
                  _inventoryItemName = selected.name;
                  _unit = selected.unit;
                  if (_nameController.text.trim().isEmpty) {
                    _nameController.text = selected.name;
                  }
                });
              },
            ),
          ],
          DropdownButtonFormField<BookingSupplyDeductionMode>(
            initialValue: _mode,
            decoration: const InputDecoration(
              labelText: '扣除方式',
              border: OutlineInputBorder(),
            ),
            items: BookingSupplyDeductionMode.values.map((
              BookingSupplyDeductionMode mode,
            ) {
              return DropdownMenuItem<BookingSupplyDeductionMode>(
                value: mode,
                child: Text(InventoryConstants.deductionModeLabel(mode)),
              );
            }).toList(),
            onChanged: (BookingSupplyDeductionMode? value) {
              if (value != null) {
                setState(() => _mode = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '每次扣除數量',
              suffixText: _unit,
              helperText: '例如每房每晚 0.5 包',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '備註',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('啟用'),
            value: _enabled,
            onChanged: (bool value) {
              setState(() => _enabled = value);
            },
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '儲存中...' : '儲存'),
          ),
        ],
      ),
    );
  }
}
