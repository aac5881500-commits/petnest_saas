// lib/features/shop/pages/shop_daycare_settings_page.dart
// 🐾 臨托後台設定（分頁：基本／時間名額／方案／加購／付款／條款）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/shop_daycare_date_override_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_entry_card_editor.dart';

class ShopDaycareSettingsPage extends StatefulWidget {
  const ShopDaycareSettingsPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopDaycareSettingsPage> createState() =>
      _ShopDaycareSettingsPageState();
}

class _ShopDaycareSettingsPageState extends State<ShopDaycareSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  DaycareSettingsModel _settings = const DaycareSettingsModel();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _intro = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final DaycareSettingsModel settings = await DaycareSettingsService
          .instance
          .get(widget.shopId);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _name.text = settings.serviceName;
        _intro.text = settings.intro;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final DaycareSettingsModel next = DaycareSettingsModel.fromMap({
        ..._settings.toMap(),
        'serviceName': _name.text.trim(),
        'intro': _intro.text.trim(),
        'updatedAt': null,
      });
      await DaycareSettingsService.instance.save(
        shopId: widget.shopId,
        settings: next,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = next;
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('臨托設定已儲存')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('臨托設定')),
        body: Center(child: Text(_error!)),
      );
    }
    return DefaultTabController(
          length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('臨托設定'),
          actions: <Widget>[
            ShopTaskCenterButton(shopId: widget.shopId),
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '儲存中' : '儲存'),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: '基本設定'),
              Tab(text: '時間與名額'),
              Tab(text: '方案與價格'),
              Tab(text: '加購服務'),
              Tab(text: '付款'),
              Tab(text: '條款'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _BasicTab(
              shopId: widget.shopId,
              settings: _settings,
              name: _name,
              intro: _intro,
              onChanged: (DaycareSettingsModel value) {
                setState(() => _settings = value);
              },
            ),
            _TimeTab(
              shopId: widget.shopId,
              settings: _settings,
              onChanged: (DaycareSettingsModel value) {
                setState(() => _settings = value);
              },
            ),
            _PlanTab(
              settings: _settings,
              onChanged: (DaycareSettingsModel value) {
                setState(() => _settings = value);
              },
            ),
            _AddonTab(
              shopId: widget.shopId,
              settings: _settings,
              onChanged: (DaycareSettingsModel value) {
                setState(() => _settings = value);
              },
            ),
            _PayTab(
              settings: _settings,
              onChanged: (DaycareSettingsModel value) {
                setState(() => _settings = value);
              },
            ),
            _PolicyTab(shopId: widget.shopId),
          ],
        ),
      ),
    );
  }
}

class _BasicTab extends StatelessWidget {
  const _BasicTab({
    required this.shopId,
    required this.settings,
    required this.name,
    required this.intro,
    required this.onChanged,
  });

  final String shopId;
  final DaycareSettingsModel settings;
  final TextEditingController name;
  final TextEditingController intro;
  final ValueChanged<DaycareSettingsModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const SizedBox(height: 8),
        BookingEntryCardEditor(shopId: shopId),
        const SizedBox(height: 16),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: '臨托服務名稱'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: intro,
          maxLines: 4,
          decoration: const InputDecoration(labelText: '臨托介紹'),
        ),
        SwitchListTile(
          title: const Text('允許當日預約'),
          value: settings.allowSameDay,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'allowSameDay': value,
                'updatedAt': null,
              }),
            );
          },
        ),
        ListTile(
          title: const Text('最晚需提前幾小時'),
          trailing: DropdownButton<int>(
            value: settings.minAdvanceHours,
            items: <int>[0, 1, 2, 3, 6, 12, 24]
                .map(
                  (int h) => DropdownMenuItem<int>(
                    value: h,
                    child: Text(h == 0 ? '不限制' : '$h 小時'),
                  ),
                )
                .toList(),
            onChanged: (int? value) {
              if (value == null) {
                return;
              }
              onChanged(
                DaycareSettingsModel.fromMap({
                  ...settings.toMap(),
                  'minAdvanceHours': value,
                  'updatedAt': null,
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TimeTab extends StatelessWidget {
  const _TimeTab({
    required this.shopId,
    required this.settings,
    required this.onChanged,
  });

  final String shopId;
  final DaycareSettingsModel settings;
  final ValueChanged<DaycareSettingsModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('可預約星期'),
        Wrap(
          children: List<Widget>.generate(7, (int index) {
            final int day = index + 1;
            const List<String> labels = <String>[
              '一',
              '二',
              '三',
              '四',
              '五',
              '六',
              '日',
            ];
            final bool selected = settings.weekdays.contains(day);
            return FilterChip(
              label: Text(labels[index]),
              selected: selected,
              onSelected: (bool value) {
                final List<int> next = List<int>.from(settings.weekdays);
                if (value) {
                  next.add(day);
                } else {
                  next.remove(day);
                }
                onChanged(
                  DaycareSettingsModel.fromMap({
                    ...settings.toMap(),
                    'weekdays': next,
                    'updatedAt': null,
                  }),
                );
              },
            );
          }),
        ),
        const SizedBox(height: 12),
        const Text('日期開放管理', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          '可單日或批次開放／關閉特定日期，並覆寫平日的星期規則。',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ShopDaycareDateOverridePage(
                  shopId: shopId,
                  settings: settings,
                ),
              ),
            );
          },
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('管理可預約日期'),
        ),
        _timeField(context, '每日開放', settings.openTime, 'openTime'),
        _timeField(context, '結束時間', settings.closeTime, 'closeTime'),
        _timeField(
          context,
          '最早送達',
          settings.earliestDropOff,
          'earliestDropOff',
        ),
        _timeField(context, '最晚接回', settings.latestPickUp, 'latestPickUp'),
        ListTile(
          title: const Text('時間間隔'),
          trailing: DropdownButton<int>(
            value: settings.slotMinutes,
            items: const <DropdownMenuItem<int>>[
              DropdownMenuItem<int>(value: 15, child: Text('15 分')),
              DropdownMenuItem<int>(value: 30, child: Text('30 分')),
              DropdownMenuItem<int>(value: 60, child: Text('60 分')),
            ],
            onChanged: (int? value) {
              if (value == null) {
                return;
              }
              onChanged(
                DaycareSettingsModel.fromMap({
                  ...settings.toMap(),
                  'slotMinutes': value,
                  'updatedAt': null,
                }),
              );
            },
          ),
        ),
        _intField(
          '最短臨托（分鐘）',
          settings.minDurationMinutes,
          'minDurationMinutes',
        ),
        _intField(
          '最長臨托（分鐘）',
          settings.maxDurationMinutes,
          'maxDurationMinutes',
        ),
        _intField('每日最大接待寵物數', settings.dailyMaxPets, 'dailyMaxPets'),
        SwitchListTile(
          title: const Text('禁止跨日'),
          value: settings.forbidOvernight,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'forbidOvernight': value,
                'updatedAt': null,
              }),
            );
          },
        ),
        SwitchListTile(
          title: const Text('超過營業時間禁止下單'),
          value: settings.blockOutsideHours,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'blockOutsideHours': value,
                'updatedAt': null,
              }),
            );
          },
        ),
        SwitchListTile(
          title: const Text('顯示剩餘名額'),
          value: settings.showRemainingSlots,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'showRemainingSlots': value,
                'updatedAt': null,
              }),
            );
          },
        ),
        SwitchListTile(
          title: const Text('允許店家拒絕特殊情況寵物'),
          value: settings.allowStaffRejectSpecial,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'allowStaffRejectSpecial': value,
                'updatedAt': null,
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _timeField(
    BuildContext context,
    String label,
    String value,
    String key,
  ) {
    return ListTile(
      title: Text(label),
      trailing: Text(value),
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: int.tryParse(value.split(':').first) ?? 9,
            minute: int.tryParse(value.split(':').last) ?? 0,
          ),
        );
        if (picked == null) {
          return;
        }
        final String text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        onChanged(
          DaycareSettingsModel.fromMap({
            ...settings.toMap(),
            key: text,
            'updatedAt': null,
          }),
        );
      },
    );
  }

  Widget _intField(String label, int value, String key) {
    return ListTile(
      title: Text(label),
      trailing: SizedBox(
        width: 80,
        child: TextFormField(
          initialValue: '$value',
          keyboardType: TextInputType.number,
          onChanged: (String raw) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                key: int.tryParse(raw) ?? value,
                'updatedAt': null,
              }),
            );
          },
        ),
      ),
    );
  }
}

class _PlanTab extends StatelessWidget {
  const _PlanTab({required this.settings, required this.onChanged});

  final DaycareSettingsModel settings;
  final ValueChanged<DaycareSettingsModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        FilledButton.icon(
          onPressed: () {
            final DaycarePlanModel plan = DaycarePlanModel(
              id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
              name: '每小時計費',
              type: DaycarePlanTypes.hourly,
              basePrice: 200,
              sortOrder: settings.plans.length,
            );
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'plans': <Map<String, dynamic>>[
                  ...settings.plans.map((DaycarePlanModel e) => e.toMap()),
                  plan.toMap(),
                ],
                'updatedAt': null,
              }),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('新增方案'),
        ),
        const SizedBox(height: 12),
        ...settings.plans.map((DaycarePlanModel plan) {
          return Card(
            child: ListTile(
              title: Text(plan.name),
              subtitle: Text(
                '${DaycarePlanTypes.label(plan.type)}　\$${plan.basePrice}',
              ),
              trailing: Switch(
                value: plan.enabled,
                onChanged: (bool value) {
                  final List<Map<String, dynamic>> next = settings.plans
                      .map(
                        (DaycarePlanModel e) => e.id == plan.id
                            ? e.copyWith(enabled: value).toMap()
                            : e.toMap(),
                      )
                      .toList();
                  onChanged(
                    DaycareSettingsModel.fromMap({
                      ...settings.toMap(),
                      'plans': next,
                      'updatedAt': null,
                    }),
                  );
                },
              ),
              onTap: () async {
                final DaycarePlanModel? edited =
                    await showDialog<DaycarePlanModel>(
                      context: context,
                      builder: (_) => _PlanEditor(plan: plan),
                    );
                if (edited == null) {
                  return;
                }
                final List<Map<String, dynamic>> next = settings.plans
                    .map(
                      (DaycarePlanModel e) =>
                          e.id == plan.id ? edited.toMap() : e.toMap(),
                    )
                    .toList();
                onChanged(
                  DaycareSettingsModel.fromMap({
                    ...settings.toMap(),
                    'plans': next,
                    'updatedAt': null,
                  }),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({required this.plan});
  final DaycarePlanModel plan;

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late DaycarePlanModel _plan;
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _extra;
  late final TextEditingController _sort;

  @override
  void initState() {
    super.initState();
    final String type = DaycarePlanTypes.isSelectable(widget.plan.type)
        ? widget.plan.type
        : DaycarePlanTypes.hourly;
    _plan = widget.plan.copyWith(type: type);
    _name = TextEditingController(text: _plan.name);
    _desc = TextEditingController(text: _plan.description);
    _price = TextEditingController(text: '${_plan.basePrice}');
    _extra = TextEditingController(text: '${_plan.extraPetSurcharge}');
    _sort = TextEditingController(text: '${_plan.sortOrder}');
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _extra.dispose();
    _sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('編輯臨托方案'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '方案名稱'),
              ),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: '說明'),
              ),
              DropdownButtonFormField<String>(
                initialValue: DaycarePlanTypes.isSelectable(_plan.type)
                    ? _plan.type
                    : DaycarePlanTypes.hourly,
                decoration: const InputDecoration(labelText: '計費方式'),
                items: DaycarePlanTypes.selectable
                    .map(
                      (String type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(DaycarePlanTypes.label(type)),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _plan = _plan.copyWith(type: value));
                },
              ),
              if (!DaycarePlanTypes.isSelectable(widget.plan.type))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '此為舊方案類型「${DaycarePlanTypes.label(widget.plan.type)}」，儲存後會改為每小時或每30分鐘計費。',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
                ),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '每個計費單位價格'),
              ),
              TextField(
                controller: _extra,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '第二隻以上每隻加價'),
              ),
              TextField(
                controller: _sort,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '排序'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('是否啟用'),
                value: _plan.enabled,
                onChanged: (bool value) {
                  setState(() => _plan = _plan.copyWith(enabled: value));
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _plan.copyWith(
                name: _name.text.trim(),
                description: _desc.text.trim(),
                basePrice: int.tryParse(_price.text) ?? _plan.basePrice,
                extraPetSurcharge:
                    int.tryParse(_extra.text) ?? _plan.extraPetSurcharge,
                sortOrder: int.tryParse(_sort.text) ?? _plan.sortOrder,
              ),
            );
          },
          child: const Text('確定'),
        ),
      ],
    );
  }
}

class _AddonTab extends StatelessWidget {
  const _AddonTab({
    required this.shopId,
    required this.settings,
    required this.onChanged,
  });

  final String shopId;
  final DaycareSettingsModel settings;
  final ValueChanged<DaycareSettingsModel> onChanged;

  void _setAllowed(List<String> ids) {
    onChanged(
      DaycareSettingsModel.fromMap({
        ...settings.toMap(),
        'allowedAddonIds': ids,
        'updatedAt': null,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('addons')
          .doc('main')
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic>? data = snapshot.data?.data();
            final List<Map<String, dynamic>> catalog =
                DaycareAddonCatalog.flatten(data);
            if (catalog.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('尚未建立或未啟用加購服務。請先到加購服務設定新增，價格仍在該頁修改。'),
                ),
              );
            }
            final Set<String> allowed = settings.allowedAddonIds.toSet();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Text(
                  '勾選後，前台臨托預約才會顯示這些既有加購服務。名稱與價格請回加購服務設定修改。',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: () => _setAllowed(
                        catalog
                            .map((Map<String, dynamic> e) => e['id'].toString())
                            .toList(),
                      ),
                      child: const Text('全選'),
                    ),
                    OutlinedButton(
                      onPressed: () => _setAllowed(const <String>[]),
                      child: const Text('全部取消'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...DaycareAddonCatalog.groups.map((Map<String, String> group) {
                  final List<Map<String, dynamic>> items = catalog
                      .where(
                        (Map<String, dynamic> e) =>
                            e['groupKey'] == group['key'],
                      )
                      .toList();
                  if (items.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Text(
                          group['label'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...items.map((Map<String, dynamic> item) {
                        final String id = (item['id'] ?? '').toString();
                        final bool on = allowed.contains(id);
                        return Card(
                          child: SwitchListTile(
                            title: Text(DaycareAddonCatalog.displayName(item)),
                            subtitle: Text(
                              '\$${item['price'] ?? 0}　'
                              '${DaycareAddonCatalog.chargeLabel(item)}　'
                              '${DaycareAddonCatalog.inventorySummary(item)}',
                            ),
                            value: on,
                            onChanged: (bool value) {
                              final List<String> next = List<String>.from(
                                settings.allowedAddonIds,
                              );
                              if (value) {
                                if (!next.contains(id)) {
                                  next.add(id);
                                }
                              } else {
                                next.remove(id);
                              }
                              _setAllowed(next);
                            },
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            );
          },
    );
  }
}

class _PayTab extends StatelessWidget {
  const _PayTab({required this.settings, required this.onChanged});

  final DaycareSettingsModel settings;
  final ValueChanged<DaycareSettingsModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: settings.depositType,
          decoration: const InputDecoration(labelText: '訂金方式'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: DaycareDepositTypes.none,
              child: Text('不收訂金，接回時付款'),
            ),
            DropdownMenuItem<String>(
              value: DaycareDepositTypes.fixed,
              child: Text('固定金額訂金'),
            ),
            DropdownMenuItem<String>(
              value: DaycareDepositTypes.percent,
              child: Text('百分比訂金'),
            ),
            DropdownMenuItem<String>(
              value: DaycareDepositTypes.full,
              child: Text('預約時全額付款'),
            ),
            DropdownMenuItem<String>(
              value: DaycareDepositTypes.staffDecide,
              child: Text('店員手動決定'),
            ),
          ],
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'depositType': value,
                'updatedAt': null,
              }),
            );
          },
        ),
        if (settings.depositType == DaycareDepositTypes.fixed ||
            settings.depositType == DaycareDepositTypes.percent)
          ListTile(
            title: Text(
              settings.depositType == DaycareDepositTypes.percent
                  ? '訂金百分比'
                  : '訂金金額',
            ),
            trailing: SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: '${settings.depositValue}',
                keyboardType: TextInputType.number,
                onChanged: (String raw) {
                  onChanged(
                    DaycareSettingsModel.fromMap({
                      ...settings.toMap(),
                      'depositValue': int.tryParse(raw) ?? 0,
                      'updatedAt': null,
                    }),
                  );
                },
              ),
            ),
          ),
        SwitchListTile(
          title: const Text('允許到店付款'),
          value: settings.allowCash,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'allowCash': value,
                'updatedAt': null,
              }),
            );
          },
        ),
        SwitchListTile(
          title: const Text('允許使用優惠券'),
          subtitle: const Text('關閉時前台不顯示優惠券，建立訂單也不套用折扣'),
          value: settings.allowCoupon,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'allowCoupon': value,
                'updatedAt': null,
              }),
            );
          },
        ),
        SwitchListTile(
          title: const Text('取消時退還訂金'),
          value: settings.refundDepositOnCancel,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'refundDepositOnCancel': value,
                'updatedAt': null,
              }),
            );
          },
        ),
        SwitchListTile(
          title: const Text('No-show 沒收訂金'),
          value: settings.forfeitDepositOnNoShow,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'forfeitDepositOnNoShow': value,
                'updatedAt': null,
              }),
            );
          },
        ),
      ],
    );
  }
}

class _PolicyTab extends StatelessWidget {
  const _PolicyTab({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('條款與住宿共用'),
            subtitle: const Text('臨托不再獨立管理條款。請到「入住規則設定」指定各條款適用住宿、臨托或兩者。'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopPolicyPage(shopId: shopId),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '黑名單沿用會員管理設定，前台住宿與臨托一律不可預約。疫苗與結紮不另設臨托專用限制。',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
      ],
    );
  }
}
