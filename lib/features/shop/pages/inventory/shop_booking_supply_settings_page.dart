// 檔案名稱：lib/features/shop/pages/inventory/shop_booking_supply_settings_page.dart
// 功能說明：同一筆服務耗材可套用住宿、安親或兩者，並可綁定中央庫存。
// 🧹 住宿／安親耗材設定頁

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/booking_supply_setting_model.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/booking_supply_setting_service.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_item_picker_page.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_status_chip.dart';

class ShopBookingSupplySettingsPage extends StatelessWidget {
  const ShopBookingSupplySettingsPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> shopSnap,
          ) {
            final bool daycareOn = DaycareSettingsService.instance
                .isEnabledForShop(shop: shopSnap.data);
            return _page(context, daycareOn: daycareOn);
          },
    );
  }

  Widget _page(BuildContext context, {required bool daycareOn}) {
    return Scaffold(
      appBar: AppBar(title: Text(daycareOn ? '住宿／安親耗材設定' : '住宿耗材設定')),
      floatingActionButton: FloatingActionButton(
        tooltip: '新增服務耗材',
        onPressed: () => _openEditor(context: context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<BookingSupplySettingModel>>(
        stream: BookingSupplySettingService.instance.streamSettings(shopId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<BookingSupplySettingModel>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<BookingSupplySettingModel> settings =
                  snapshot.data ?? const <BookingSupplySettingModel>[];

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    children: <Widget>[
                      _IntroCard(daycareOn: daycareOn),
                      const SizedBox(height: 12),
                      if (settings.isEmpty)
                        _EmptySupplies(daycareOn: daycareOn)
                      else
                        for (final BookingSupplySettingModel setting
                            in settings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SettingCard(
                              daycareOn: daycareOn,
                              setting: setting,
                              onTap: () => _openEditor(
                                context: context,
                                setting: setting,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
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

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.daycareOn});

  final bool daycareOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '服務耗材與中央庫存',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            daycareOn
                ? '設定入住或安親開始時要使用的用品。啟用中央庫存後，系統會依服務類型與扣除方式自動扣除；取消已扣除的訂單時會依既有規則返還。'
                : '設定入住時要使用的用品。啟用中央庫存後，系統會依扣除方式自動扣除；取消已扣除的訂單時會依既有規則返還。',
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySupplies extends StatelessWidget {
  const _EmptySupplies({required this.daycareOn});

  final bool daycareOn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.cleaning_services_outlined,
            size: 36,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 8),
          const Text(
            '尚未設定服務耗材',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            daycareOn
                ? '可新增住宿或安親期間會使用的用品，並選擇是否連動中央庫存自動扣除。'
                : '可新增住宿期間會使用的用品，並選擇是否連動中央庫存自動扣除。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.daycareOn,
    required this.setting,
    required this.onTap,
  });

  final bool daycareOn;
  final BookingSupplySettingModel setting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String unit = setting.unit.trim().isEmpty ? '個' : setting.unit.trim();
    final String itemName = setting.inventoryItemName.trim().isEmpty
        ? '未命名庫存'
        : setting.inventoryItemName.trim();
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      setting.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    setting.enabled ? '啟用' : '停用',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: setting.enabled
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                setting.useInventory ? '中央庫存：$itemName' : '不使用中央庫存',
                style: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  if (setting.appliesToStay) const _ScopeChip('住宿'),
                  if (daycareOn && setting.appliesToDaycare)
                    const _ScopeChip('安親'),
                ],
              ),
              if (setting.appliesToStay)
                Text(
                  '住宿：${InventoryConstants.deductionModeLabel(setting.stayMode)} ${InventoryConstants.formatQuantity(setting.stayQuantity)} $unit',
                  style: const TextStyle(fontSize: 13),
                ),
              if (daycareOn && setting.appliesToDaycare)
                Text(
                  '安親：${InventoryConstants.daycareDeductionModeLabel(setting.daycareMode)} ${InventoryConstants.formatQuantity(setting.daycareQuantity)} $unit',
                  style: const TextStyle(fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
    );
  }
}

class _BookingSupplyEditorPage extends StatefulWidget {
  const _BookingSupplyEditorPage({required this.shopId, this.setting});

  final String shopId;
  final BookingSupplySettingModel? setting;

  @override
  State<_BookingSupplyEditorPage> createState() =>
      _BookingSupplyEditorPageState();
}

class _BookingSupplyEditorPageState extends State<_BookingSupplyEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late final TextEditingController _stayQuantityController;
  late final TextEditingController _daycareQuantityController;
  late bool _useInventory;
  late bool _enabled;
  late bool _appliesToStay;
  late bool _appliesToDaycare;
  late BookingSupplyDeductionMode _stayMode;
  late DaycareSupplyDeductionMode _daycareMode;
  String _inventoryItemId = '';
  String _inventoryItemName = '';
  String _unit = '';
  bool _allowDecimal = true;
  InventoryItemModel? _item;
  bool _saving = false;
  bool _shopDaycareOn = false;
  StreamSubscription<Map<String, dynamic>?>? _shopSub;

  @override
  void initState() {
    super.initState();
    final BookingSupplySettingModel? setting = widget.setting;
    _nameController = TextEditingController(text: setting?.name ?? '');
    _noteController = TextEditingController(text: setting?.note ?? '');
    _stayQuantityController = TextEditingController(
      text: setting == null
          ? '1'
          : InventoryConstants.formatQuantity(setting.stayQuantity),
    );
    _daycareQuantityController = TextEditingController(
      text: setting == null
          ? '1'
          : InventoryConstants.formatQuantity(setting.daycareQuantity),
    );
    _useInventory = setting?.useInventory ?? false;
    _enabled = setting?.enabled ?? true;
    _appliesToStay = setting?.appliesToStay ?? true;
    _appliesToDaycare = setting?.appliesToDaycare ?? false;
    _stayMode = setting?.stayMode ?? BookingSupplyDeductionMode.perRoomPerNight;
    _daycareMode =
        setting?.daycareMode ?? DaycareSupplyDeductionMode.perRoomPerVisit;
    _inventoryItemId = setting?.inventoryItemId ?? '';
    _inventoryItemName = setting?.inventoryItemName ?? '';
    _unit = setting?.unit ?? '';
    if (_useInventory && _inventoryItemId.trim().isNotEmpty) {
      _loadItem();
    }
    _shopSub = ShopService.instance.streamShop(widget.shopId).listen((
      Map<String, dynamic>? shop,
    ) {
      final bool on = DaycareSettingsService.instance.isEnabledForShop(
        shop: shop,
      );
      if (!mounted || on == _shopDaycareOn) {
        return;
      }
      setState(() {
        _shopDaycareOn = on;
      });
    });
  }

  Future<void> _loadItem() async {
    final InventoryItemModel? item = await InventoryService.instance.getItem(
      shopId: widget.shopId,
      itemId: _inventoryItemId,
    );
    if (!mounted || item == null) {
      return;
    }
    setState(() {
      _item = item;
      _allowDecimal = item.allowDecimal;
      if (_unit.trim().isEmpty) {
        _unit = item.unit;
      }
      if (_inventoryItemName.trim().isEmpty) {
        _inventoryItemName = item.name;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _stayQuantityController.dispose();
    _daycareQuantityController.dispose();
    _shopSub?.cancel();
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
        appliesToStay: _appliesToStay,
        appliesToDaycare: _appliesToDaycare,
        stayQuantityPerUnit:
            num.tryParse(_stayQuantityController.text.trim()) ?? 0,
        stayDeductionMode: _stayMode,
        daycareQuantityPerUnit:
            num.tryParse(_daycareQuantityController.text.trim()) ?? 0,
        daycareDeductionMode: _daycareMode,
        enabled: _enabled,
        note: _noteController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存服務耗材設定')));
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
    final bool creating = widget.setting == null;
    final String unit = _unit.trim().isEmpty ? '個' : _unit.trim();
    return Scaffold(
      appBar: AppBar(title: Text(creating ? '新增服務耗材' : '編輯服務耗材')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              const _SectionTitle('基本資料'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '耗材名稱',
                  hintText: '例如：豆腐砂、濕紙巾、餐盒',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '備註（可選）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const _SectionTitle('使用中央庫存'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('使用中央庫存'),
                value: _useInventory,
                onChanged: (bool value) =>
                    setState(() => _useInventory = value),
              ),
              if (!_useInventory)
                const Text(
                  '僅保留耗材設定，不會自動扣除庫存。',
                  style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
                ),
              if (_useInventory) ...<Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _inventoryItemName.isEmpty ? '選擇庫存品項' : _inventoryItemName,
                  ),
                  subtitle: Text(
                    _inventoryItemId.isEmpty ? '尚未選擇' : '單位：$unit',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickItem,
                ),
                if (_item != null) _SelectedItem(item: _item!),
                if (_inventoryItemId.isEmpty)
                  const Text(
                    '沒有選擇庫存品項時不能儲存。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                  ),
              ],
              const SizedBox(height: 16),
              const _SectionTitle('套用服務'),
              _ScopeTile(
                title: '住宿',
                subtitle: '辦理入住時依下方規則扣除',
                selected: _appliesToStay,
                onChanged: (bool value) =>
                    setState(() => _appliesToStay = value),
              ),
              if (_shopDaycareOn) ...<Widget>[
                const SizedBox(height: 8),
                _ScopeTile(
                  title: '安親',
                  subtitle: '開始安親時依下方規則扣除',
                  selected: _appliesToDaycare,
                  onChanged: (bool value) =>
                      setState(() => _appliesToDaycare = value),
                ),
              ],
              if (_appliesToStay) ...<Widget>[
                const SizedBox(height: 16),
                const _SectionTitle('住宿扣除規則'),
                DropdownButtonFormField<BookingSupplyDeductionMode>(
                  initialValue: _stayMode,
                  decoration: const InputDecoration(
                    labelText: '住宿扣除方式',
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
                      setState(() => _stayMode = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stayQuantityController,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: _allowDecimal,
                  ),
                  decoration: InputDecoration(
                    labelText: '每次扣除數量',
                    suffixText: unit,
                    helperText: _quantityHelper(
                      InventoryConstants.deductionModeLabel(_stayMode),
                      _stayQuantityController.text,
                      unit,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_shopDaycareOn && _appliesToDaycare) ...<Widget>[
                const SizedBox(height: 16),
                const _SectionTitle('安親扣除規則'),
                DropdownButtonFormField<DaycareSupplyDeductionMode>(
                  initialValue: _daycareMode,
                  decoration: const InputDecoration(
                    labelText: '安親扣除方式',
                    border: OutlineInputBorder(),
                  ),
                  items: DaycareSupplyDeductionMode.values.map((
                    DaycareSupplyDeductionMode mode,
                  ) {
                    return DropdownMenuItem<DaycareSupplyDeductionMode>(
                      value: mode,
                      child: Text(
                        InventoryConstants.daycareDeductionModeLabel(mode),
                      ),
                    );
                  }).toList(),
                  onChanged: (DaycareSupplyDeductionMode? value) {
                    if (value != null) {
                      setState(() => _daycareMode = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _daycareQuantityController,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: _allowDecimal,
                  ),
                  decoration: InputDecoration(
                    labelText: '每次扣除數量',
                    suffixText: unit,
                    helperText: _quantityHelper(
                      InventoryConstants.daycareDeductionModeLabel(
                        _daycareMode,
                      ),
                      _daycareQuantityController.text,
                      unit,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('啟用'),
                value: _enabled,
                onChanged: (bool value) => setState(() => _enabled = value),
              ),
              if (!_useInventory)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '目前不會自動扣庫存。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                  ),
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '儲存中...' : '儲存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _quantityHelper(String mode, String raw, String unit) {
    final num? quantity = num.tryParse(raw.trim());
    final String amount = quantity == null
        ? raw.trim()
        : InventoryConstants.formatQuantity(quantity);
    return '$mode會扣除 $amount $unit';
  }

  Future<void> _pickItem() async {
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
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _item = selected;
      _inventoryItemId = selected.id;
      _inventoryItemName = selected.name;
      _unit = selected.unit;
      _allowDecimal = selected.allowDecimal;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = selected.name;
      }
    });
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colors.primary : const Color(0xFFE4E7EC),
        ),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (bool? value) => onChanged(value == true),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class _SelectedItem extends StatelessWidget {
  const _SelectedItem({required this.item});

  final InventoryItemModel item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${item.name}・現有 ${InventoryConstants.formatQuantity(item.currentStock)} ${item.unit}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          InventoryStatusChip(item: item),
        ],
      ),
    );
  }
}
