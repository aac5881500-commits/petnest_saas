// lib/features/shop/pages/shop_addon_page.dart
// 🧩 加購服務管理頁（完整版🔥🔥🔥）
// 👉 已升級：
// - 預設時間自動建立
// - 每項都有介紹 desc
// - 三大區塊：時間 / 加值 / 客製
// - Firebase 存取完整

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/addon_inventory_binding_editor.dart';

class ShopAddonPage extends StatefulWidget {
  final String shopId;

  const ShopAddonPage({super.key, required this.shopId});

  @override
  State<ShopAddonPage> createState() => _ShopAddonPageState();
}

class _ShopAddonPageState extends State<ShopAddonPage> {
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

  @override
  void initState() {
    super.initState();
    _loadData();
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
  Widget _buildServiceItem(Map<String, dynamic> item, VoidCallback onDelete) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
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

            const SizedBox(height: 8),

            /// 🔥 第二行：介紹
            TextFormField(
              initialValue: item['desc'] ?? '',
              decoration: const InputDecoration(labelText: '介紹（前台顯示）'),
              onChanged: (val) {
                item['desc'] = val;
              },
            ),
            if (!item.containsKey('label'))
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
              title: const Text(
                '允許同一時段選擇多隻寵物',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                '開啟後，不同寵物可選擇同一個服務時段',
                style: TextStyle(fontSize: 12),
              ),
              value: item['allowMultiplePetsPerSlot'] ?? true,
              onChanged: (value) {
                setState(() {
                  item['allowMultiplePetsPerSlot'] = value;
                });
              },
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '每天可選時段',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: addTimeSlot,
                  icon: const Icon(Icons.access_time),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加購服務設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '啟用時間加購',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Switch(
                      value: enabled,
                      onChanged: (v) {
                        setState(() => enabled = v);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Text(
                  enabled ? '🟢 已啟用（前台會顯示）' : '🔴 未啟用（前台不顯示）',
                  style: TextStyle(
                    color: enabled ? Colors.green : Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  /// ⏰ 時間加購
                  _title('時間加購'),
                  const Text(
                    '⚠️ 此區為「單選」，顧客只能選擇一個時間方案',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  ...timeOptions.map((item) {
                    return _buildServiceItem(
                      item,
                      () => setState(() => timeOptions.remove(item)),
                    );
                  }),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        timeOptions.add({"label": "", "price": 0, "desc": ""});
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新增時間'),
                  ),

                  const SizedBox(height: 20),

                  /// 💰 加值服務
                  _title('加值服務'),
                  const Text(
                    '⚠️ 此區為「單次計算」，不論幾隻寵物只收一次費用',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  ...valueServices.map((item) {
                    return _buildServiceItem(
                      item,
                      () => setState(() => valueServices.remove(item)),
                    );
                  }),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        valueServices.add(<String, dynamic>{
                          'id': _createServiceId('value'),
                          'name': '',
                          'price': 0,
                          'desc': '',
                        });
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新增加值服務'),
                  ),

                  const SizedBox(height: 20),

                  /// 🛠 客製化服務
                  _title('客製化服務'),
                  const Text(
                    '⚠️ 此區為「每隻寵物計算」，前台可選擇套用單隻或全部寵物',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  ...customServices.map((item) {
                    return _buildServiceItem(
                      item,
                      () => setState(() => customServices.remove(item)),
                    );
                  }),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        customServices.add(<String, dynamic>{
                          'id': _createServiceId('custom'),
                          'name': '',
                          'price': 0,
                          'desc': '',
                        });
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新增客製化服務'),
                  ),

                  const SizedBox(height: 20),

                  /// 🕐 每日分時段服務
                  _title('每日分時段服務'),

                  const Text(
                    '⚠️ 此區依「寵物、住宿日期、選擇時段」分別計費',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    '例如：餵食每次 50 元，顧客可替不同寵物選擇每天早、中、晚的服務時段。',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),

                  const SizedBox(height: 10),

                  ...dailyTimedServices.map((item) {
                    return _buildDailyTimedServiceItem(item, () {
                      setState(() {
                        dailyTimedServices.remove(item);
                      });
                    });
                  }),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        dailyTimedServices.add(<String, dynamic>{
                          'id': _createServiceId('daily_timed'),
                          'name': '',
                          'price': 0,
                          'desc': '',
                          'allowMultiplePetsPerSlot': true,
                          'timeSlots': <Map<String, dynamic>>[],
                        });
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新增每日時段服務'),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),

            /// 儲存
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('儲存設定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
