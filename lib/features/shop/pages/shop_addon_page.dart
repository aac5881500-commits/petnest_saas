// 檔案名稱：lib/features/shop/pages/shop_addon_page.dart
// 功能說明：加購服務管理頁（完整版）
// 👉 已升級：
// - 預設時間自動建立
// - 每項都有介紹 desc
// - 三大區塊：時間 / 加值 / 客製
// - Firebase 存取完整

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_binding_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/daycare_enabled.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_list_page.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/addon_inventory_binding_editor.dart';

class ShopAddonPage extends StatefulWidget {
  final String shopId;

  const ShopAddonPage({super.key, required this.shopId});

  @override
  State<ShopAddonPage> createState() => _ShopAddonPageState();
}

class _ShopAddonPageState extends State<ShopAddonPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool enabled = false;
  int _serviceIdCounter = 0;

  /// 建立不重複的服務 ID
  String _createServiceId(String prefix) {
    _serviceIdCounter++;

    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_'
        '$_serviceIdCounter';
  }

  /// 替舊服務補上固定 ID，並統一基本欄位格式
  List<Map<String, dynamic>> _normalizeServices(
    dynamic rawServices, {
    required String idPrefix,
  }) {
    if (rawServices is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawServices
        .map((dynamic rawService) {
          if (rawService is! Map) {
            return <String, dynamic>{};
          }

          final Map<String, dynamic> service = Map<String, dynamic>.from(
            rawService,
          );

          final String existingId = (service['id'] ?? '').toString().trim();

          return <String, dynamic>{
            ...service,
            'id': existingId.isNotEmpty
                ? existingId
                : _createServiceId(idPrefix),
            'name': (service['name'] ?? '').toString(),
            'price': (service['price'] as num?)?.toInt() ?? 0,
            'desc': (service['desc'] ?? '').toString(),
          };
        })
        .where((Map<String, dynamic> service) {
          return service.isNotEmpty;
        })
        .toList();
  }

  List<Map<String, dynamic>> timeOptions = [];
  List<Map<String, dynamic>> valueServices = [];
  List<Map<String, dynamic>> customServices = [];

  /// 🕐 每日分時段服務
  /// 依「寵物 × 日期 × 時段」計次收費
  List<Map<String, dynamic>> dailyTimedServices = [];
  String? _selectedKey;
  _AddonKind _focusKind = _AddonKind.time;
  bool _showInventory = false;
  bool _hasUnsavedChanges = false;
  _InventoryListFilter _inventoryFilter = _InventoryListFilter.all;
  static const double _desktopMin = 1100;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 🔥 預設時間
  List<Map<String, dynamic>> _defaultTimeOptions() {
    return [
      {"label": "正常入住", "price": 0, "desc": "一般營業時間內入住"},
      {"label": "09:00 - 09:59 入住", "price": 400, "desc": "提早入住（早上）"},
      {"label": "10:00 - 10:59 入住", "price": 200, "desc": "提早入住"},
      {"label": "20:01 - 21:00 退房", "price": 200, "desc": "延後退房"},
      {"label": "21:01 - 22:00 退房", "price": 400, "desc": "延後退房（晚）"},
    ];
  }

  /// 🔥 讀取
  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('addons')
        .doc('main')
        .get();

    final data = doc.data();

    if (data != null) {
      setState(() {
        enabled = data['enabled'] ?? false;

        timeOptions = List<Map<String, dynamic>>.from(
          data['timeOptions'] ?? _defaultTimeOptions(),
        );

        valueServices = _normalizeServices(
          data['valueServices'],
          idPrefix: 'value',
        );

        customServices = _normalizeServices(
          data['customServices'],
          idPrefix: 'custom',
        );
        dailyTimedServices =
            _normalizeServices(
              data['dailyTimedServices'],
              idPrefix: 'daily_timed',
            ).map((Map<String, dynamic> service) {
              final List<dynamic> rawTimeSlots = List<dynamic>.from(
                service['timeSlots'] ?? <dynamic>[],
              );

              final List<Map<String, dynamic>> normalizedTimeSlots =
                  rawTimeSlots.asMap().entries.map((
                    MapEntry<int, dynamic> entry,
                  ) {
                    final dynamic rawSlot = entry.value;

                    if (rawSlot is Map) {
                      final Map<String, dynamic> slot =
                          Map<String, dynamic>.from(rawSlot);

                      final String existingSlotId = (slot['id'] ?? '')
                          .toString()
                          .trim();

                      return <String, dynamic>{
                        'id': existingSlotId.isNotEmpty
                            ? existingSlotId
                            : _createServiceId('time_slot'),
                        'label': (slot['label'] ?? '').toString(),
                      };
                    }

                    return <String, dynamic>{
                      'id': _createServiceId('time_slot'),
                      'label': rawSlot.toString(),
                    };
                  }).toList();

              return <String, dynamic>{
                ...service,
                'allowMultiplePetsPerSlot':
                    service['allowMultiplePetsPerSlot'] ?? true,
                'timeSlots': normalizedTimeSlots,
              };
            }).toList();
        _selectInitialItem();
      });
    } else {
      /// 🔥 沒資料 → 自動給預設
      setState(() {
        timeOptions = _defaultTimeOptions();
        _selectInitialItem();
      });
    }
  }

  void _selectInitialItem() {
    if (_selectedKey != null || _showInventory) {
      return;
    }
    if (timeOptions.isNotEmpty) {
      _selectedKey = _addonItemKey('time', timeOptions.first);
      _focusKind = _AddonKind.time;
    }
  }

  void _markDirty() {
    if (_hasUnsavedChanges) {
      return;
    }
    setState(() => _hasUnsavedChanges = true);
  }

  /// 🔥 儲存
  Future<void> _save() async {
    final List<Map<String, dynamic>> normalizedValueServices =
        _normalizeServices(valueServices, idPrefix: 'value');

    final List<Map<String, dynamic>> normalizedCustomServices =
        _normalizeServices(customServices, idPrefix: 'custom');

    final List<Map<String, dynamic>> normalizedDailyTimedServices =
        _normalizeServices(dailyTimedServices, idPrefix: 'daily_timed').map((
          Map<String, dynamic> service,
        ) {
          final List<dynamic> rawTimeSlots = List<dynamic>.from(
            service['timeSlots'] ?? <dynamic>[],
          );

          final List<Map<String, dynamic>> normalizedTimeSlots = rawTimeSlots
              .map((dynamic rawSlot) {
                if (rawSlot is! Map) {
                  return <String, dynamic>{
                    'id': _createServiceId('time_slot'),
                    'label': rawSlot.toString(),
                  };
                }

                final Map<String, dynamic> slot = Map<String, dynamic>.from(
                  rawSlot,
                );

                final String existingSlotId = (slot['id'] ?? '')
                    .toString()
                    .trim();

                return <String, dynamic>{
                  ...slot,
                  'id': existingSlotId.isNotEmpty
                      ? existingSlotId
                      : _createServiceId('time_slot'),
                  'label': (slot['label'] ?? '').toString(),
                };
              })
              .toList();

          return <String, dynamic>{
            ...service,
            'allowMultiplePetsPerSlot':
                service['allowMultiplePetsPerSlot'] ?? true,
            'timeSlots': normalizedTimeSlots,
          };
        }).toList();

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('addons')
        .doc('main')
        .set(<String, dynamic>{
          'enabled': enabled,
          'timeOptions': timeOptions,
          'valueServices': normalizedValueServices,
          'customServices': normalizedCustomServices,
          'dailyTimedServices': normalizedDailyTimedServices,
        });

    if (!mounted) {
      return;
    }

    setState(() {
      valueServices = normalizedValueServices;
      customServices = normalizedCustomServices;
      dailyTimedServices = normalizedDailyTimedServices;
      _hasUnsavedChanges = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('加購服務設定已儲存')));
  }

  List<_AddonEntry> _entriesOf(_AddonKind kind) {
    switch (kind) {
      case _AddonKind.time:
        return timeOptions
            .map(
              (Map<String, dynamic> item) => _AddonEntry(
                kind: kind,
                prefix: 'time',
                item: item,
                list: timeOptions,
                deleteTitle: '刪除時間方案',
              ),
            )
            .toList();
      case _AddonKind.value:
        return valueServices
            .map(
              (Map<String, dynamic> item) => _AddonEntry(
                kind: kind,
                prefix: 'value',
                item: item,
                list: valueServices,
                deleteTitle: '刪除加值服務',
              ),
            )
            .toList();
      case _AddonKind.custom:
        return customServices
            .map(
              (Map<String, dynamic> item) => _AddonEntry(
                kind: kind,
                prefix: 'custom',
                item: item,
                list: customServices,
                deleteTitle: '刪除客製服務',
              ),
            )
            .toList();
      case _AddonKind.daily:
        return dailyTimedServices
            .map(
              (Map<String, dynamic> item) => _AddonEntry(
                kind: kind,
                prefix: 'daily',
                item: item,
                list: dailyTimedServices,
                deleteTitle: '刪除每日分時段服務',
              ),
            )
            .toList();
    }
  }

  List<_AddonEntry> get _allEntries {
    return <_AddonEntry>[
      ..._entriesOf(_AddonKind.time),
      ..._entriesOf(_AddonKind.value),
      ..._entriesOf(_AddonKind.custom),
      ..._entriesOf(_AddonKind.daily),
    ];
  }

  _AddonEntry? _selectedEntry() {
    if (_showInventory || _selectedKey == null) {
      return null;
    }
    for (final _AddonEntry entry in _allEntries) {
      if (entry.key == _selectedKey) {
        return entry;
      }
    }
    return null;
  }

  String _addonItemKey(String prefix, Map<String, dynamic> item) {
    final String id = (item['id'] ?? '').toString().trim();
    if (id.isNotEmpty) {
      return '$prefix:$id';
    }
    return '$prefix:${identityHashCode(item)}';
  }

  String _displayName(Map<String, dynamic> item, {String fallback = '未命名服務'}) {
    final String name = (item['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name;
    }
    final String label = (item['label'] ?? '').toString().trim();
    return label.isEmpty ? fallback : label;
  }

  int _priceOf(Map<String, dynamic> item) {
    return (item['price'] as num?)?.toInt() ?? 0;
  }

  int _bindingCount(Map<String, dynamic> item) {
    return InventoryBindingModel.listFromValue(
      item['inventoryBindings'],
    ).length;
  }

  String _bindingPhrase(Map<String, dynamic> item) {
    final List<InventoryBindingModel> models =
        InventoryBindingModel.listFromValue(item['inventoryBindings']);
    if (models.isEmpty) {
      return '';
    }
    final String shown = models
        .take(2)
        .map((InventoryBindingModel model) {
          final String name = model.inventoryItemName.trim().isEmpty
              ? '未命名品項'
              : model.inventoryItemName.trim();
          return '$name ×${InventoryConstants.formatQuantity(model.quantityPerUnit)}';
        })
        .join('、');
    final int extra = models.length - 2;
    if (extra > 0) {
      return '$shown、另 $extra 項';
    }
    return shown;
  }

  int get _inventoryOnCount {
    return _allEntries.where((_AddonEntry entry) {
      return entry.item['useInventory'] == true;
    }).length;
  }

  int get _inventoryBoundCount {
    return _allEntries.where((_AddonEntry entry) {
      return entry.item['useInventory'] == true &&
          _bindingCount(entry.item) > 0;
    }).length;
  }

  int get _inventoryPendingCount {
    return _allEntries.where((_AddonEntry entry) {
      return entry.item['useInventory'] == true &&
          _bindingCount(entry.item) == 0;
    }).length;
  }

  void _selectEntry(_AddonEntry entry) {
    setState(() {
      _selectedKey = entry.key;
      _focusKind = entry.kind;
      _showInventory = false;
    });
  }

  void _addService(_AddonKind kind) {
    late final Map<String, dynamic> item;
    late final List<Map<String, dynamic>> list;
    late final String prefix;
    switch (kind) {
      case _AddonKind.time:
        item = <String, dynamic>{'label': '', 'price': 0, 'desc': ''};
        list = timeOptions;
        prefix = 'time';
      case _AddonKind.value:
        item = <String, dynamic>{
          'id': _createServiceId('value'),
          'name': '',
          'price': 0,
          'desc': '',
        };
        list = valueServices;
        prefix = 'value';
      case _AddonKind.custom:
        item = <String, dynamic>{
          'id': _createServiceId('custom'),
          'name': '',
          'price': 0,
          'desc': '',
        };
        list = customServices;
        prefix = 'custom';
      case _AddonKind.daily:
        item = <String, dynamic>{
          'id': _createServiceId('daily_timed'),
          'name': '',
          'price': 0,
          'desc': '',
          'allowMultiplePetsPerSlot': true,
          'timeSlots': <Map<String, dynamic>>[],
        };
        list = dailyTimedServices;
        prefix = 'daily';
    }
    setState(() {
      list.add(item);
      _selectedKey = _addonItemKey(prefix, item);
      _focusKind = kind;
      _showInventory = false;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _confirmDelete(_AddonEntry entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(entry.deleteTitle),
          content: const Text('確定要刪除嗎？尚未儲存前，仍可離開頁面放棄變更。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      final int index = entry.list.indexOf(entry.item);
      entry.list.remove(entry.item);
      _hasUnsavedChanges = true;
      if (_selectedKey != entry.key) {
        return;
      }
      _showInventory = false;
      _focusKind = entry.kind;
      if (entry.list.isEmpty) {
        _selectedKey = null;
        return;
      }
      final int nextIndex = index >= entry.list.length
          ? entry.list.length - 1
          : index;
      _selectedKey = _addonItemKey(entry.prefix, entry.list[nextIndex]);
    });
  }

  void _openInventorySheet(Map<String, dynamic> item) {
    showAddonInventoryBindingSheet(
      context: context,
      shopId: widget.shopId,
      service: item,
      onChanged: () {
        setState(() => _hasUnsavedChanges = true);
      },
    );
  }

  Future<void> _addTimeSlot(Map<String, dynamic> item) async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: '選擇服務時段',
      cancelText: '取消',
      confirmText: '確定',
    );
    if (selectedTime == null) {
      return;
    }
    final String label =
        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> timeSlots =
        List<Map<String, dynamic>>.from(
          item['timeSlots'] ?? <Map<String, dynamic>>[],
        );
    final bool hasSameTime = timeSlots.any(
      (Map<String, dynamic> slot) => slot['label']?.toString() == label,
    );
    if (hasSameTime) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label 已經存在')));
      return;
    }
    timeSlots.add(<String, dynamic>{
      'id': 'slot_${DateTime.now().microsecondsSinceEpoch}',
      'label': label,
    });
    timeSlots.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      return (a['label'] ?? '').toString().compareTo(
        (b['label'] ?? '').toString(),
      );
    });
    setState(() {
      item['timeSlots'] = timeSlots;
      _hasUnsavedChanges = true;
    });
  }

  void _removeTimeSlot(Map<String, dynamic> item, Map<String, dynamic> slot) {
    final String slotId = (slot['id'] ?? '').toString();
    final String slotLabel = (slot['label'] ?? '').toString();
    final List<Map<String, dynamic>> current = List<Map<String, dynamic>>.from(
      item['timeSlots'] ?? <Map<String, dynamic>>[],
    );
    current.removeWhere((Map<String, dynamic> currentSlot) {
      final String currentId = (currentSlot['id'] ?? '').toString();
      if (slotId.isNotEmpty) {
        return currentId == slotId;
      }
      return (currentSlot['label'] ?? '').toString() == slotLabel;
    });
    setState(() {
      item['timeSlots'] = current;
      _hasUnsavedChanges = true;
    });
  }

  List<String> _slotLabels(Map<String, dynamic> item) {
    final Object? raw = item['timeSlots'];
    if (raw is! List) {
      return const <String>[];
    }
    return raw
        .map((Object? slot) {
          if (slot is Map) {
            return (slot['label'] ?? '').toString().trim();
          }
          return slot.toString().trim();
        })
        .where((String label) => label.isNotEmpty)
        .toList();
  }

  String _applicableShort(Map<String, dynamic> item) {
    final List<String> current = PolicyApplicableService.parse(
      item['applicableServices'],
    );
    final bool stay = current.contains(PolicyApplicableService.accommodation);
    final bool daycare = current.contains(PolicyApplicableService.daycare);
    if (stay && daycare) {
      return '住宿與安親';
    }
    if (daycare) {
      return '安親';
    }
    return '住宿';
  }

  String _billingText(_AddonKind kind) {
    switch (kind) {
      case _AddonKind.time:
        return '顧客每次預約只能選擇一個入住／退房時間方案。';
      case _AddonKind.value:
        return '此服務每筆訂單只計費一次，不因寵物數量重複收費。';
      case _AddonKind.custom:
        return '顧客可依服務規則選擇適用寵物；實際收費依既有前台規則計算。';
      case _AddonKind.daily:
        return '依每隻寵物、每個入住日期與每個選擇時段分別計費。';
    }
  }

  String _kindLabel(_AddonKind kind) {
    switch (kind) {
      case _AddonKind.time:
        return '時間加購';
      case _AddonKind.value:
        return '加值服務';
      case _AddonKind.custom:
        return '客製服務';
      case _AddonKind.daily:
        return '每日分時段';
    }
  }

  IconData _kindIcon(_AddonKind kind) {
    switch (kind) {
      case _AddonKind.time:
        return Icons.schedule;
      case _AddonKind.value:
        return Icons.auto_awesome_outlined;
      case _AddonKind.custom:
        return Icons.tune;
      case _AddonKind.daily:
        return Icons.calendar_view_day_outlined;
    }
  }

  void _openInventoryPage() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ShopInventoryListPage(shopId: widget.shopId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= _desktopMin;
        return Scaffold(
          backgroundColor: const Color(0xFFF6F8FB),
          appBar: AppBar(
            title: const Text('加購服務設定'),
            actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
            bottom: desktop
                ? null
                : TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    tabs: const <Widget>[
                      Tab(text: '時間加購'),
                      Tab(text: '加值服務'),
                      Tab(text: '客製服務'),
                      Tab(text: '每日分時段'),
                      Tab(text: '庫存設定'),
                    ],
                  ),
          ),
          body: desktop ? _desktopBody() : _mobileBody(),
        );
      },
    );
  }

  Widget _desktopBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(width: 320, child: _overviewRail()),
          const SizedBox(width: 12),
          Expanded(child: _editorPane()),
        ],
      ),
    );
  }

  Widget _mobileBody() {
    return Column(
      children: <Widget>[
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _mobileKindList(_AddonKind.time),
              _mobileKindList(_AddonKind.value),
              _mobileKindList(_AddonKind.custom),
              _mobileKindList(_AddonKind.daily),
              _inventoryOverview(compact: true),
            ],
          ),
        ),
        _saveBar(fullWidth: true),
      ],
    );
  }

  Widget _overviewRail() {
    final Color primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '加購服務總覽',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _summaryCard(),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: <Widget>[
                _kindSection(_AddonKind.time, showSwitch: true),
                _kindSection(_AddonKind.value),
                _kindSection(_AddonKind.custom),
                _kindSection(_AddonKind.daily),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: _inventoryNavTile(primary),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              _hasUnsavedChanges ? '有尚未儲存的變更' : '所有設定已儲存',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _hasUnsavedChanges
                    ? const Color(0xFFC2410C)
                    : const Color(0xFF5F7A68),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('目前設定', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _countChip('時間方案 ${timeOptions.length}'),
              _countChip('加值服務 ${valueServices.length}'),
              _countChip('客製服務 ${customServices.length}'),
              _countChip('每日分時段 ${dailyTimedServices.length}'),
            ],
          ),
          const SizedBox(height: 8),
          if (_inventoryOnCount == 0)
            const Text(
              '目前沒有服務扣除庫存',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            )
          else ...<Widget>[
            Text(
              '$_inventoryOnCount 個服務已連動庫存',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            if (_inventoryPendingCount > 0)
              Text(
                '$_inventoryPendingCount 個服務尚未完成庫存綁定',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC2410C),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _countChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _kindSection(_AddonKind kind, {bool showSwitch = false}) {
    final List<_AddonEntry> entries = _entriesOf(kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  kind == _AddonKind.time
                      ? _kindLabel(kind)
                      : '${_kindLabel(kind)} ${entries.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: '新增',
                visualDensity: VisualDensity.compact,
                onPressed: () => _addService(kind),
                icon: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
          if (showSwitch)
            Row(
              children: <Widget>[
                Text(
                  enabled ? '已啟用' : '未啟用',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? const Color(0xFF1B7A45)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                Switch(
                  value: enabled,
                  onChanged: (bool value) {
                    setState(() {
                      enabled = value;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
              ],
            ),
          for (final _AddonEntry entry in entries) _railTile(entry),
        ],
      ),
    );
  }

  Widget _railTile(_AddonEntry entry) {
    final bool selected = !_showInventory && entry.key == _selectedKey;
    final Color primary = Theme.of(context).colorScheme.primary;
    final String name = _displayName(
      entry.item,
      fallback: entry.kind == _AddonKind.time ? '未命名時間方案' : '未命名服務',
    );
    final int slots = _slotLabels(entry.item).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? primary.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _selectEntry(entry),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: selected ? primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                if (entry.kind == _AddonKind.time) ...<Widget>[
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: selected ? primary : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Tooltip(
                    message: name,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    entry.kind == _AddonKind.daily
                        ? 'NT\$${_priceOf(entry.item)}・$slots 個時段'
                        : 'NT\$${_priceOf(entry.item)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                if (entry.kind != _AddonKind.time) ...<Widget>[
                  const SizedBox(width: 4),
                  _stockIcon(entry.item),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stockIcon(Map<String, dynamic> item) {
    final bool useInventory = item['useInventory'] == true;
    final int count = _bindingCount(item);
    if (!useInventory) {
      return const Icon(
        Icons.inventory_2_outlined,
        size: 16,
        color: Color(0xFF9CA3AF),
      );
    }
    if (count == 0) {
      return const Icon(
        Icons.warning_amber_rounded,
        size: 16,
        color: Color(0xFFC2410C),
      );
    }
    return const Icon(
      Icons.inventory_2_outlined,
      size: 16,
      color: Color(0xFF1565C0),
    );
  }

  Widget _inventoryNavTile(Color primary) {
    return Material(
      color: _showInventory ? primary.withValues(alpha: 0.10) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _showInventory = true),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                color: _showInventory ? primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.inventory_2_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '庫存總覽',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '$_inventoryBoundCount 個服務已綁定',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (_inventoryPendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '待處理 $_inventoryPendingCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC2410C),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editorPane() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: _showInventory
                    ? _inventoryOverview(compact: false)
                    : _selectedEditor(embedded: false),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: _saveBar(fullWidth: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBar({required bool fullWidth}) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: fullWidth
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.end,
          children: <Widget>[
            if (fullWidth)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _hasUnsavedChanges ? '有尚未儲存的變更' : '所有設定已儲存',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _hasUnsavedChanges
                        ? const Color(0xFFC2410C)
                        : const Color(0xFF5F7A68),
                  ),
                ),
              ),
            SizedBox(
              width: fullWidth ? double.infinity : 168,
              child: FilledButton(
                style: _hasUnsavedChanges
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB7C0CC),
                      ),
                onPressed: _save,
                child: Text(_hasUnsavedChanges ? '儲存設定' : '設定已儲存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileKindList(_AddonKind kind) {
    final List<_AddonEntry> entries = _entriesOf(kind);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        if (kind == _AddonKind.time) _timeMasterCard(),
        if (entries.isEmpty)
          _emptyState(kind)
        else
          for (final _AddonEntry entry in entries)
            if (!_showInventory && entry.key == _selectedKey)
              _serviceEditor(entry, embedded: true)
            else
              _mobileSummary(entry),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _addService(kind),
          icon: const Icon(Icons.add),
          label: Text('新增${_kindLabel(kind)}'),
        ),
      ],
    );
  }

  Widget _timeMasterCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '啟用時間加購',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  '未啟用時，前台不會顯示時間加購方案',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (bool value) {
              setState(() {
                enabled = value;
                _hasUnsavedChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _mobileSummary(_AddonEntry entry) {
    final String name = _displayName(entry.item);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        onTap: () => _selectEntry(entry),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('NT\$${_priceOf(entry.item)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _stockIcon(entry.item),
            IconButton(
              tooltip: '刪除',
              onPressed: () => _confirmDelete(entry),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedEditor({required bool embedded}) {
    final _AddonEntry? entry = _selectedEntry();
    if (entry == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[_emptyState(_focusKind)],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: <Widget>[_serviceEditor(entry, embedded: embedded)],
    );
  }

  Widget _emptyState(_AddonKind kind) {
    final String title = switch (kind) {
      _AddonKind.time => '尚未建立時間方案',
      _AddonKind.value => '尚未建立加值服務',
      _AddonKind.custom => '尚未建立客製服務',
      _AddonKind.daily => '尚未建立每日分時段服務',
    };
    final String body = kind == _AddonKind.daily
        ? '建立後可設定每次價格、每日時段與是否售出扣庫存。'
        : '建立後可設定價格、適用服務與是否售出扣庫存。';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: <Widget>[
          Icon(_kindIcon(kind), size: 36, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _addService(kind),
            icon: const Icon(Icons.add),
            label: Text('新增${_kindLabel(kind)}'),
          ),
        ],
      ),
    );
  }

  Widget _serviceEditor(_AddonEntry entry, {required bool embedded}) {
    final Map<String, dynamic> item = entry.item;
    final String name = _displayName(item);
    final int slots = _slotLabels(item).length;
    final String headline = entry.kind == _AddonKind.time
        ? '${_kindLabel(entry.kind)}／$name'
        : '${_kindLabel(entry.kind)}／$name';
    final String second = entry.kind == _AddonKind.daily
        ? '依寵物 × 入住日期 × 選擇時段計費'
        : entry.kind == _AddonKind.time
        ? '顧客只能單選一個時間方案'
        : entry.kind == _AddonKind.value
        ? '單次計費・不論幾隻寵物只收一次'
        : '依服務規則選擇適用寵物';
    final String third = entry.kind == _AddonKind.daily
        ? '已設定 $slots 個每日時段'
        : '適用：${_applicableShort(item)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    headline,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    second,
                    style: const TextStyle(color: Color(0xFF4B5563)),
                  ),
                  Text(third, style: const TextStyle(color: Color(0xFF6B7280))),
                ],
              ),
            ),
            IconButton(
              tooltip: '刪除',
              onPressed: () => _confirmDelete(entry),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
        if (embedded)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _selectedKey = null),
              child: const Text('完成編輯'),
            ),
          ),
        const SizedBox(height: 8),
        _formCard(
          title: '基本資料',
          child: Column(
            children: <Widget>[
              TextFormField(
                key: ValueKey<String>('${entry.key}-name'),
                initialValue: (item['name'] ?? item['label'] ?? '').toString(),
                decoration: InputDecoration(
                  labelText: entry.kind == _AddonKind.time ? '時間名稱' : '名稱',
                ),
                onChanged: (String value) {
                  if (item.containsKey('label') && !item.containsKey('name')) {
                    item['label'] = value;
                  } else if (entry.kind == _AddonKind.time) {
                    item['label'] = value;
                  } else {
                    item['name'] = value;
                  }
                  _markDirty();
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey<String>('${entry.key}-price'),
                initialValue: _priceOf(item).toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: entry.kind == _AddonKind.daily ? '每次價格' : '價格',
                  prefixText: 'NT\$ ',
                ),
                onChanged: (String value) {
                  item['price'] = int.tryParse(value) ?? 0;
                  _markDirty();
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey<String>('${entry.key}-desc'),
                initialValue: (item['desc'] ?? '').toString(),
                maxLines: 2,
                decoration: const InputDecoration(labelText: '前台介紹'),
                onChanged: (String value) {
                  item['desc'] = value;
                  _markDirty();
                },
              ),
              _applicableServicesField(item),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _formCard(
          title: '此服務如何計費',
          child: Text(
            _billingText(entry.kind),
            style: const TextStyle(height: 1.45),
          ),
        ),
        if (entry.kind == _AddonKind.daily) ...<Widget>[
          const SizedBox(height: 10),
          _dailySlotCard(item),
        ],
        const SizedBox(height: 10),
        _inventoryRow(item),
      ],
    );
  }

  Widget _formCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _applicableServicesField(Map<String, dynamic> item) {
    final List<String> current = PolicyApplicableService.parse(
      item['applicableServices'],
    );
    final String mode =
        current.contains(PolicyApplicableService.accommodation) &&
            current.contains(PolicyApplicableService.daycare)
        ? 'both'
        : current.contains(PolicyApplicableService.daycare)
        ? 'daycare'
        : 'stay';
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> shopSnap,
          ) {
            final bool daycareOn = DaycareEnabled.isOn(shop: shopSnap.data);
            final String effectiveMode = daycareOn ? mode : 'stay';
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '適用服務',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (!daycareOn)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '安親服務目前關閉，加購僅能設定住宿適用。',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ),
                  SegmentedButton<String>(
                    segments: daycareOn
                        ? const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'stay',
                              label: Text('住宿'),
                            ),
                            ButtonSegment<String>(
                              value: 'daycare',
                              label: Text('安親'),
                            ),
                            ButtonSegment<String>(
                              value: 'both',
                              label: Text('住宿與安親'),
                            ),
                          ]
                        : const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'stay',
                              label: Text('住宿'),
                            ),
                          ],
                    selected: <String>{effectiveMode},
                    onSelectionChanged: (Set<String> values) {
                      if (values.isEmpty) {
                        return;
                      }
                      setState(() {
                        switch (values.first) {
                          case 'daycare':
                            item['applicableServices'] = List<String>.from(
                              PolicyApplicableService.daycareOnly,
                            );
                          case 'both':
                            item['applicableServices'] = List<String>.from(
                              PolicyApplicableService.shared,
                            );
                          default:
                            item['applicableServices'] = List<String>.from(
                              PolicyApplicableService.accommodationOnly,
                            );
                        }
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),
                ],
              ),
            );
          },
    );
  }

  Widget _dailySlotCard(Map<String, dynamic> item) {
    final List<Map<String, dynamic>> slots = List<Map<String, dynamic>>.from(
      item['timeSlots'] ?? <Map<String, dynamic>>[],
    );
    return _formCard(
      title: '每日服務時段',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: const Text(
              '允許同一時段選擇多隻寵物',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              '開啟後，同一時段可同時替不同寵物加購。',
              style: TextStyle(fontSize: 12),
            ),
            value: item['allowMultiplePetsPerSlot'] ?? true,
            onChanged: (bool value) {
              setState(() {
                item['allowMultiplePetsPerSlot'] = value;
                _hasUnsavedChanges = true;
              });
            },
          ),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '每日可選時段',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _addTimeSlot(item),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增時段'),
              ),
            ],
          ),
          if (slots.isEmpty)
            const Text(
              '尚未設定每日可選時段，顧客目前無法選擇此服務。',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final Map<String, dynamic> slot in slots)
                  InputChip(
                    label: Text((slot['label'] ?? '').toString()),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => _removeTimeSlot(item, slot),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          const Text(
            '顧客會先選擇寵物，再依入住日期選擇每天需要的服務時段。',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryRow(Map<String, dynamic> item) {
    final bool useInventory = item['useInventory'] == true;
    final int count = _bindingCount(item);
    final String phrase = _bindingPhrase(item);
    final String subtitle = !useInventory
        ? '不扣庫存，僅計費'
        : count == 0
        ? '已開啟扣庫存，但尚未選擇品項'
        : '已綁定：$phrase';
    return _formCard(
      title: '庫存扣除',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.inventory_2_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '售出時扣除庫存',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
              Switch(
                value: useInventory,
                onChanged: (bool value) {
                  setState(() {
                    item['useInventory'] = value;
                    _hasUnsavedChanges = true;
                  });
                },
              ),
            ],
          ),
          if (useInventory && count == 0)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '請選擇售出時要扣除的庫存品項。',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC2410C),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openInventorySheet(item),
              child: const Text('管理扣除品項'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryOverview({required bool compact}) {
    final List<_AddonEntry> rows = _allEntries.where((_AddonEntry entry) {
      final bool useInventory = entry.item['useInventory'] == true;
      final int count = _bindingCount(entry.item);
      switch (_inventoryFilter) {
        case _InventoryListFilter.all:
          return true;
        case _InventoryListFilter.bound:
          return useInventory && count > 0;
        case _InventoryListFilter.pending:
          return useInventory && count == 0;
        case _InventoryListFilter.off:
          return !useInventory;
      }
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                '加購服務庫存總覽',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: _openInventoryPage,
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('前往庫存管理'),
            ),
          ],
        ),
        const Text(
          '在這裡一次檢查所有服務售出時會扣除哪些庫存品項。未開啟庫存連動的服務仍可正常販售，只是不扣庫存。',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _countChip('使用庫存 $_inventoryOnCount 個服務'),
            _countChip('已完成綁定 $_inventoryBoundCount 個'),
            _countChip('待選擇品項 $_inventoryPendingCount 個'),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: <Widget>[
            _filterChip('全部', _InventoryListFilter.all),
            _filterChip('已綁定', _InventoryListFilter.bound),
            _filterChip('待綁定', _InventoryListFilter.pending),
            _filterChip('不扣庫存', _InventoryListFilter.off),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('這個篩選目前沒有服務'),
          )
        else if (compact)
          for (final _AddonEntry entry in rows) _inventoryCard(entry)
        else
          _inventoryTable(rows),
      ],
    );
  }

  Widget _filterChip(String label, _InventoryListFilter value) {
    return ChoiceChip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      selected: _inventoryFilter == value,
      onSelected: (_) => setState(() => _inventoryFilter = value),
    );
  }

  Widget _inventoryTable(List<_AddonEntry> rows) {
    return Column(
      children: <Widget>[
        const _InventoryHeader(),
        for (final _AddonEntry entry in rows) _inventoryTableRow(entry),
      ],
    );
  }

  Widget _inventoryTableRow(_AddonEntry entry) {
    final bool useInventory = entry.item['useInventory'] == true;
    final int count = _bindingCount(entry.item);
    final String phrase = _bindingPhrase(entry.item);
    final int slots = _slotLabels(entry.item).length;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 132,
            child: Row(
              children: <Widget>[
                Icon(_kindIcon(entry.kind), size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _kindLabel(entry.kind),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _displayName(entry.item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  entry.kind == _AddonKind.daily
                      ? 'NT\$${_priceOf(entry.item)}・$slots 個時段'
                      : 'NT\$${_priceOf(entry.item)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 118,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Switch(
                  value: useInventory,
                  onChanged: (bool value) {
                    setState(() {
                      entry.item['useInventory'] = value;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
                Text(
                  !useInventory
                      ? '不扣庫存'
                      : count == 0
                      ? '尚未綁定'
                      : '已開啟',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: useInventory && count == 0
                        ? const Color(0xFFC2410C)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              phrase.isEmpty ? '—' : phrase,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 120,
            child: useInventory && count == 0
                ? FilledButton(
                    onPressed: () => _openInventorySheet(entry.item),
                    child: const Text('選擇品項', style: TextStyle(fontSize: 12)),
                  )
                : TextButton(
                    onPressed: () => _openInventorySheet(entry.item),
                    child: const Text('編輯扣除品項'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryCard(_AddonEntry entry) {
    final bool useInventory = entry.item['useInventory'] == true;
    final int count = _bindingCount(entry.item);
    final String phrase = _bindingPhrase(entry.item);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${_kindLabel(entry.kind)}・${_displayName(entry.item)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text('NT\$${_priceOf(entry.item)}'),
            Text(phrase.isEmpty ? '扣除品項：—' : phrase),
            Row(
              children: <Widget>[
                const Text('售出時扣庫存'),
                Switch(
                  value: useInventory,
                  onChanged: (bool value) {
                    setState(() {
                      entry.item['useInventory'] = value;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _openInventorySheet(entry.item),
                  child: Text(useInventory && count == 0 ? '選擇品項' : '編輯扣除品項'),
                ),
              ],
            ),
            if (useInventory && count == 0)
              const Text(
                '尚未綁定',
                style: TextStyle(
                  color: Color(0xFFC2410C),
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader();

  @override
  Widget build(BuildContext context) {
    const TextStyle style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Color(0xFF6B7280),
    );
    return const Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          SizedBox(width: 132, child: Text('類型', style: style)),
          Expanded(flex: 3, child: Text('服務名稱', style: style)),
          SizedBox(width: 118, child: Text('售出時扣庫存', style: style)),
          Expanded(flex: 3, child: Text('扣除品項', style: style)),
          SizedBox(width: 120, child: Text('操作', style: style)),
        ],
      ),
    );
  }
}

class _AddonEntry {
  _AddonEntry({
    required this.kind,
    required this.prefix,
    required this.item,
    required this.list,
    required this.deleteTitle,
  });

  final _AddonKind kind;
  final String prefix;
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> list;
  final String deleteTitle;

  String get key {
    final String id = (item['id'] ?? '').toString().trim();
    if (id.isNotEmpty) {
      return '$prefix:$id';
    }
    return '$prefix:${identityHashCode(item)}';
  }
}

enum _AddonKind { time, value, custom, daily }

enum _InventoryListFilter { all, bound, pending, off }
