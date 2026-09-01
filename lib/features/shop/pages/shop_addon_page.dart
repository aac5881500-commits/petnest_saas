// lib/features/shop/pages/shop_addon_page.dart
// 🧩 加購服務管理頁（完整版🔥🔥🔥）
// 👉 已升級：
// - 預設時間自動建立
// - 每項都有介紹 desc
// - 三大區塊：時間 / 加值 / 客製
// - Firebase 存取完整

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String? _editingAddonKey;

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
      });
    } else {
      /// 🔥 沒資料 → 自動給預設
      setState(() {
        timeOptions = _defaultTimeOptions();
      });
    }
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
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已儲存')));
  }

  /// 🔥 卡片（含介紹）
  Widget _buildServiceItem(
    Map<String, dynamic> item,
    VoidCallback onDelete, {
    bool showInventoryBinding = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        child: Column(
          children: [
            /// 第一行
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item['name'] ?? item['label'] ?? '',
                    decoration: const InputDecoration(labelText: '名稱 / 時間'),
                    onChanged: (val) {
                      if (item.containsKey('label')) {
                        item['label'] = val;
                      } else {
                        item['name'] = val;
                      }
                    },
                  ),
                ),

                const SizedBox(width: 10),

                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: (item['price'] ?? 0).toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '價格'),
                    onChanged: (val) {
                      item['price'] = int.tryParse(val) ?? 0;
                    },
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),

            /// 🔥 第二行：介紹
            TextFormField(
              initialValue: item['desc'] ?? '',
              decoration: const InputDecoration(labelText: '介紹（前台顯示）'),
              onChanged: (val) {
                item['desc'] = val;
              },
            ),
            if (showInventoryBinding)
              AddonInventoryBindingEditor(
                shopId: widget.shopId,
                service: item,
                onChanged: () {
                  setState(() {});
                },
              )
            else if (item['useInventory'] == true ||
                (item['inventoryBindings'] is List &&
                    (item['inventoryBindings'] as List).isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      showAddonInventoryBindingSheet(
                        context: context,
                        shopId: widget.shopId,
                        service: item,
                        onChanged: () {
                          setState(() {});
                        },
                      );
                    },
                    child: AddonInventoryStatusChip(service: item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 🕐 每日分時段服務卡片
  ///
  /// 功能：
  /// 店主可設定服務名稱、每次價格、介紹，
  /// 並使用時間選擇器新增每日可選時段。
  Widget _buildDailyTimedServiceItem(
    Map<String, dynamic> item,
    VoidCallback onDelete,
  ) {
    final timeSlots = List<Map<String, dynamic>>.from(item['timeSlots'] ?? []);

    Future<void> addTimeSlot() async {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: '選擇服務時段',
        cancelText: '取消',
        confirmText: '確定',
      );

      if (selectedTime == null) {
        return;
      }

      final hour = selectedTime.hour.toString().padLeft(2, '0');
      final minute = selectedTime.minute.toString().padLeft(2, '0');
      final label = '$hour:$minute';

      final hasSameTime = timeSlots.any(
        (slot) => slot['label']?.toString() == label,
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

      final newTimeSlots = [
        ...timeSlots,
        <String, dynamic>{
          'id': 'slot_${DateTime.now().microsecondsSinceEpoch}',
          'label': label,
        },
      ];

      newTimeSlots.sort((a, b) {
        final aLabel = a['label']?.toString() ?? '';
        final bLabel = b['label']?.toString() ?? '';
        return aLabel.compareTo(bLabel);
      });

      setState(() {
        item['timeSlots'] = newTimeSlots;
      });
    }

    void removeTimeSlot(Map<String, dynamic> slot) {
      final slotId = slot['id']?.toString() ?? '';
      final slotLabel = slot['label']?.toString() ?? '';

      setState(() {
        final currentTimeSlots = List<Map<String, dynamic>>.from(
          item['timeSlots'] ?? [],
        );

        currentTimeSlots.removeWhere((currentSlot) {
          final currentId = currentSlot['id']?.toString() ?? '';
          final currentLabel = currentSlot['label']?.toString() ?? '';

          if (slotId.isNotEmpty) {
            return currentId == slotId;
          }

          return currentLabel == slotLabel;
        });

        item['timeSlots'] = currentTimeSlots;
      });
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item['name']?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: '服務名稱',
                      hintText: '例如：餵食服務',
                    ),
                    onChanged: (value) {
                      item['name'] = value;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: (item['price'] ?? 0).toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '每次價格',
                      prefixText: '\$',
                    ),
                    onChanged: (value) {
                      item['price'] = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
                IconButton(
                  tooltip: '刪除服務',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: item['desc']?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: '服務介紹（前台顯示）',
                hintText: '例如：由照護人員依指定時段協助餵食',
              ),
              maxLines: 2,
              onChanged: (value) {
                item['desc'] = value;
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: const Text(
                '允許同一時段選擇多隻寵物',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '開啟後，不同寵物可選擇同一個服務時段',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              value: item['allowMultiplePetsPerSlot'] ?? true,
              onChanged: (value) {
                setState(() {
                  item['allowMultiplePetsPerSlot'] = value;
                });
              },
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                const Text(
                  '每天可選時段',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                OutlinedButton.icon(
                  onPressed: addTimeSlot,
                  icon: const Icon(Icons.access_time, size: 18),
                  label: const Text('新增時段'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (timeSlots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '尚未設定時段，請按右上方「新增時段」。',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              )
            else
              ...timeSlots.map((slot) {
                final label = slot['label']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '刪除時段',
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          removeTimeSlot(slot);
                        },
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            const Text(
              '顧客預約時會先選擇寵物，再依住宿日期選擇每天需要的服務時段。',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            AddonInventoryBindingEditor(
              shopId: widget.shopId,
              service: item,
              onChanged: () {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _billingHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.red.shade800,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeAddonTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '啟用時間加購',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                  setState(() => enabled = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          enabled ? '已啟用，前台會顯示' : '未啟用，前台不顯示',
          style: TextStyle(
            color: enabled ? Colors.green.shade700 : Colors.grey.shade600,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _title('時間加購方案'),
        _billingHint('此區為單選，顧客只能選擇一個時間方案。'),
        ...timeOptions.map((Map<String, dynamic> item) {
          final String itemKey = _addonItemKey('time', item);
          if (_editingAddonKey == itemKey) {
            return _wrapInlineEditor(
              _buildServiceItem(
                item,
                () => _confirmDeleteAddonItem(
                  title: '刪除時間方案',
                  item: item,
                  list: timeOptions,
                ),
              ),
            );
          }

          return _buildAddonSummaryCard(
            item: item,
            titleFallback: '未命名時間方案',
            onEdit: () => _openAddonEditor(itemKey),
            onDelete: () => _confirmDeleteAddonItem(
              title: '刪除時間方案',
              item: item,
              list: timeOptions,
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            final Map<String, dynamic> item = <String, dynamic>{
              'label': '',
              'price': 0,
              'desc': '',
            };
            setState(() {
              timeOptions.add(item);
              _editingAddonKey = _addonItemKey('time', item);
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('新增時間'),
        ),
      ],
    );
  }

  Widget _valueServiceTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _title('加值服務'),
        _billingHint('此區為單次計算，不論幾隻寵物只收一次費用。'),
        ...valueServices.map((Map<String, dynamic> item) {
          final String itemKey = _addonItemKey('value', item);
          if (_editingAddonKey == itemKey) {
            return _wrapInlineEditor(
              _buildServiceItem(
                item,
                () => _confirmDeleteAddonItem(
                  title: '刪除加值服務',
                  item: item,
                  list: valueServices,
                ),
                showInventoryBinding: true,
              ),
            );
          }

          return _buildAddonSummaryCard(
            item: item,
            showInventory: true,
            onEdit: () => _openAddonEditor(itemKey),
            onDelete: () => _confirmDeleteAddonItem(
              title: '刪除加值服務',
              item: item,
              list: valueServices,
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            final Map<String, dynamic> item = <String, dynamic>{
              'id': _createServiceId('value'),
              'name': '',
              'price': 0,
              'desc': '',
            };
            setState(() {
              valueServices.add(item);
              _editingAddonKey = _addonItemKey('value', item);
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('新增加值服務'),
        ),
      ],
    );
  }

  String _addonItemKey(String prefix, Map<String, dynamic> item) {
    final String id = (item['id'] ?? '').toString().trim();
    if (id.isNotEmpty) {
      return '$prefix:$id';
    }
    return '$prefix:${identityHashCode(item)}';
  }

  String _addonDisplayName(Map<String, dynamic> item) {
    final String name = (item['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name;
    }
    return (item['label'] ?? '').toString().trim();
  }

  void _openAddonEditor(String itemKey) {
    setState(() {
      _editingAddonKey = itemKey;
    });
  }

  Widget _wrapInlineEditor(Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        child,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() {
                _editingAddonKey = null;
              });
            },
            child: const Text('完成編輯'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAddonItem({
    required String title,
    required Map<String, dynamic> item,
    required List<Map<String, dynamic>> list,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
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

    if (confirmed != true) {
      return;
    }

    setState(() {
      _editingAddonKey = null;
      list.remove(item);
    });
  }

  int _addonBindingCount(Map<String, dynamic> item) {
    final Object? raw = item['inventoryBindings'];
    if (raw is! List) {
      return 0;
    }

    return raw.where((Object? binding) {
      if (binding is! Map) {
        return false;
      }
      return (binding['inventoryItemId'] ?? '').toString().trim().isNotEmpty;
    }).length;
  }

  String _addonInventoryLabel(Map<String, dynamic> item) {
    if (item['useInventory'] != true) {
      return '不使用庫存';
    }

    final int count = _addonBindingCount(item);
    if (count <= 0) {
      return '已開啟庫存連動・尚未綁定';
    }
    return '已綁定 $count 項庫存';
  }

  Widget _buildAddonSummaryCard({
    required Map<String, dynamic> item,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    String titleFallback = '未命名服務',
    String priceSuffix = '',
    bool showInventory = false,
    Widget? extra,
  }) {
    final String name = _addonDisplayName(item);
    final String desc = (item['desc'] ?? '').toString().trim();
    final int price = (item['price'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: Radius.circular(showInventory ? 0 : 14),
            ),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                name.isEmpty ? titleFallback : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '\$$price$priceSuffix',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        if (desc.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        if (extra != null) ...<Widget>[
                          const SizedBox(height: 8),
                          extra,
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '更多',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (String value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(value: 'edit', child: Text('編輯')),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('刪除'),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
          ),
          if (showInventory)
            InkWell(
              onTap: () {
                showAddonInventoryBindingSheet(
                  context: context,
                  shopId: widget.shopId,
                  service: item,
                  onChanged: () {
                    setState(() {});
                  },
                );
              },
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _addonInventoryLabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyTimedSummaryCard(
    Map<String, dynamic> item,
    String itemKey,
  ) {
    final List<String> slotLabels = _dailyTimedSlotLabels(item);
    const int visibleSlotCount = 4;
    final bool allowMultiple = item['allowMultiplePetsPerSlot'] ?? true;

    return _buildAddonSummaryCard(
      item: item,
      priceSuffix: ' / 次',
      showInventory: true,
      onEdit: () => _openAddonEditor(itemKey),
      onDelete: () => _confirmDeleteAddonItem(
        title: '刪除每日分時段服務',
        item: item,
        list: dailyTimedServices,
      ),
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (slotLabels.isEmpty)
            Text(
              '尚未設定時段',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade800,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                ...slotLabels.take(visibleSlotCount).map(_buildTimeSlotChip),
                if (slotLabels.length > visibleSlotCount)
                  _buildTimeSlotChip(
                    '+${slotLabels.length - visibleSlotCount}',
                    muted: true,
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Text(
            allowMultiple ? '多寵物：可同時選擇' : '多寵物：不可同時選擇',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _dailyTimedSlotLabels(Map<String, dynamic> item) {
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

  Widget _buildTimeSlotChip(String label, {bool muted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: muted ? Colors.grey.shade700 : Colors.grey.shade900,
        ),
      ),
    );
  }

  Widget _customServiceTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _title('客製化服務'),
        _billingHint('此區依每隻寵物計算，前台可選擇套用單隻或全部寵物。'),
        ...customServices.map((Map<String, dynamic> item) {
          final String itemKey = _addonItemKey('custom', item);
          if (_editingAddonKey == itemKey) {
            return _wrapInlineEditor(
              _buildServiceItem(
                item,
                () => _confirmDeleteAddonItem(
                  title: '刪除客製服務',
                  item: item,
                  list: customServices,
                ),
                showInventoryBinding: true,
              ),
            );
          }

          return _buildAddonSummaryCard(
            item: item,
            showInventory: true,
            onEdit: () => _openAddonEditor(itemKey),
            onDelete: () => _confirmDeleteAddonItem(
              title: '刪除客製服務',
              item: item,
              list: customServices,
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            final Map<String, dynamic> item = <String, dynamic>{
              'id': _createServiceId('custom'),
              'name': '',
              'price': 0,
              'desc': '',
            };
            setState(() {
              customServices.add(item);
              _editingAddonKey = _addonItemKey('custom', item);
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('新增客製化服務'),
        ),
      ],
    );
  }

  Widget _dailyTimedTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _title('每日分時段服務'),
        _billingHint('此區依寵物、住宿日期、選擇時段分別計費。'),
        _hint('例如餵食每次 50 元，顧客可替不同寵物選擇每天早、中、晚的服務時段。'),
        ...dailyTimedServices.map((Map<String, dynamic> item) {
          final String itemKey = _addonItemKey('daily', item);
          if (_editingAddonKey == itemKey) {
            return _wrapInlineEditor(
              _buildDailyTimedServiceItem(
                item,
                () => _confirmDeleteAddonItem(
                  title: '刪除每日分時段服務',
                  item: item,
                  list: dailyTimedServices,
                ),
              ),
            );
          }

          return _buildDailyTimedSummaryCard(item, itemKey);
        }),
        OutlinedButton.icon(
          onPressed: () {
            final Map<String, dynamic> item = <String, dynamic>{
              'id': _createServiceId('daily_timed'),
              'name': '',
              'price': 0,
              'desc': '',
              'allowMultiplePetsPerSlot': true,
              'timeSlots': <Map<String, dynamic>>[],
            };
            setState(() {
              dailyTimedServices.add(item);
              _editingAddonKey = _addonItemKey('daily', item);
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('新增每日分時段服務'),
        ),
      ],
    );
  }

  Widget _inventoryGuideTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _title('加購服務庫存連動'),
        _hint('加購服務可以選擇是否連動中央庫存。未啟用庫存的服務仍可正常使用。'),
        _GuideCard(title: '不使用庫存', body: '只計算服務費用，不影響庫存。適合單純計時、計次、不消耗實體物品的服務。'),
        _GuideCard(
          title: '使用中央庫存',
          body: '客戶購買服務後，會自動扣除已綁定的庫存品項。請先在對應服務開啟「庫存連動」。',
        ),
        _GuideCard(title: '多品項綁定', body: '一個服務可以同時使用多種庫存，例如生日套餐：蛋糕 ×1、肉泥 ×2。'),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (BuildContext context) {
                  return ShopInventoryListPage(shopId: widget.shopId);
                },
              ),
            );
          },
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('前往庫存管理'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('加購服務設定'),
        actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
        bottom: TabBar(
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
      body: Column(
        children: <Widget>[
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _timeAddonTab(),
                _valueServiceTab(),
                _customServiceTab(),
                _dailyTimedTab(),
                _inventoryGuideTab(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('儲存設定'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
