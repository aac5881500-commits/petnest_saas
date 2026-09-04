// lib/features/shop/pages/shop_daycare_settings_page.dart
// 🐾 安親後台設定（分頁：基本／時間名額／方案／加購／付款／條款）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/shop_addon_page.dart';
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
      ).showSnackBar(const SnackBar(content: Text('安親設定已儲存')));
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
        appBar: AppBar(title: const Text('安親設定')),
        body: Center(child: Text(_error!)),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('安親設定'),
          actions: <Widget>[
            ShopTaskCenterButton(shopId: widget.shopId),
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '儲存中' : '儲存'),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: '基本設定'),
              Tab(text: '收費方式'),
              Tab(text: '加購與付款'),
              Tab(text: '條款'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.all(16),
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
                const Divider(height: 32),
                _TimeTab(
                  shopId: widget.shopId,
                  settings: _settings,
                  onChanged: (DaycareSettingsModel value) {
                    setState(() => _settings = value);
                  },
                ),
              ],
            ),
            _PricingTab(
              shopId: widget.shopId,
              settings: _settings,
              onChanged: (DaycareSettingsModel value) {
                setState(() => _settings = value);
              },
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _AddonTab(
                  shopId: widget.shopId,
                  settings: _settings,
                  onChanged: (DaycareSettingsModel value) {
                    setState(() => _settings = value);
                  },
                ),
                const Divider(height: 32),
                _PayTab(
                  settings: _settings,
                  onChanged: (DaycareSettingsModel value) {
                    setState(() => _settings = value);
                  },
                ),
              ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        BookingEntryCardEditor(shopId: shopId),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('開放安親服務'),
          subtitle: const Text('開啟後客戶端即可預約安親，無需重新登入。'),
          value: settings.enabled,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'enabled': value,
                'updatedAt': null,
              }),
            );
          },
        ),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: '安親服務名稱'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: intro,
          maxLines: 4,
          decoration: const InputDecoration(labelText: '安親介紹'),
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: <Widget>[
        const Text('日期開放管理', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          '所有日期預設可預約，只有你關閉的日期才不可預約。',
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
        _timeField(context, '每日營業開始時間', settings.openTime, 'openTime'),
        _timeField(context, '每日營業結束時間', settings.closeTime, 'closeTime'),
        _timeField(
          context,
          '最早送達',
          settings.earliestDropOff,
          'earliestDropOff',
        ),
        _timeField(context, '最晚接回', settings.latestPickUp, 'latestPickUp'),
        _intField('每日最大接待寵物數', settings.dailyMaxPets, 'dailyMaxPets'),
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            '0 代表不限制。額滿由實際訂單計算，不必手動設定。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 8),
        const Text('逾時接回費', style: TextStyle(fontWeight: FontWeight.w700)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('是否收取逾時接回費'),
          subtitle: const Text('實際接回晚於預定接回時間，完成安親時才結算。'),
          value: settings.latePickupEnabled,
          onChanged: (bool value) {
            onChanged(
              DaycareSettingsModel.fromMap({
                ...settings.toMap(),
                'latePickupEnabled': value,
                'updatedAt': null,
              }),
            );
          },
        ),
        if (settings.latePickupEnabled) ...<Widget>[
          ListTile(
            title: const Text('免費寬限時間'),
            trailing: DropdownButton<int>(
              value: settings.overtimeGraceMinutes,
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 0, child: Text('不寬限')),
                DropdownMenuItem<int>(value: 15, child: Text('15 分鐘')),
                DropdownMenuItem<int>(value: 30, child: Text('30 分鐘')),
                DropdownMenuItem<int>(value: 60, child: Text('60 分鐘')),
              ],
              onChanged: (int? value) {
                if (value == null) {
                  return;
                }
                onChanged(
                  DaycareSettingsModel.fromMap({
                    ...settings.toMap(),
                    'overtimeGraceMinutes': value,
                    'updatedAt': null,
                  }),
                );
              },
            ),
          ),
          ListTile(
            title: const Text('寬限後加收方式'),
            trailing: DropdownButton<int>(
              value: settings.latePickupUnitMinutes,
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 30, child: Text('每 30 分鐘加收')),
                DropdownMenuItem<int>(value: 60, child: Text('每 1 小時加收')),
              ],
              onChanged: (int? value) {
                if (value == null) {
                  return;
                }
                onChanged(
                  DaycareSettingsModel.fromMap({
                    ...settings.toMap(),
                    'latePickupUnitMinutes': value,
                    'updatedAt': null,
                  }),
                );
              },
            ),
          ),
          _intField('每次加收金額', settings.latePickupPrice, 'latePickupPrice'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              DaycarePricingService.instance.shopLatePickupExample(settings),
              style: const TextStyle(fontSize: 13, color: Color(0xFFC45C26)),
            ),
          ),
        ],
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
          title: const Text('允許店家拒絕特殊狀況寵物'),
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

  void _setPlans(List<DaycarePlanModel> plans) {
    onChanged(
      DaycareSettingsModel.fromMap({
        ...settings.toMap(),
        'plans': plans.map((DaycarePlanModel e) => e.toMap()).toList(),
        'updatedAt': null,
      }),
    );
  }

  Future<void> _edit(BuildContext context, {DaycarePlanModel? existing}) async {
    final DaycarePlanModel draft =
        existing ??
        DaycarePlanModel(
          id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
          name: '4 小時安親方案',
          includedMinutes: 240,
          basePrice: 880,
          extraBillingMinutes: 60,
          extraBillingPrice: 200,
          sortOrder: settings.plans.length,
        );
    final DaycarePlanModel? edited = await showDialog<DaycarePlanModel>(
      context: context,
      builder: (_) => _PlanEditor(plan: draft, isNew: existing == null),
    );
    if (edited == null) {
      return;
    }
    if (existing == null) {
      _setPlans(<DaycarePlanModel>[...settings.plans, edited]);
      return;
    }
    _setPlans(
      settings.plans
          .map((DaycarePlanModel e) => e.id == existing.id ? edited : e)
          .toList(),
    );
  }

  void _move(int index, int delta) {
    final int nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= settings.plans.length) {
      return;
    }
    final List<DaycarePlanModel> next = List<DaycarePlanModel>.from(
      settings.plans,
    );
    final DaycarePlanModel item = next.removeAt(index);
    next.insert(nextIndex, item);
    _setPlans(
      next.asMap().entries.map((MapEntry<int, DaycarePlanModel> e) {
        return e.value.copyWith(sortOrder: e.key);
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('新增方案'),
        ),
        const SizedBox(height: 12),
        ...settings.plans.asMap().entries.map((
          MapEntry<int, DaycarePlanModel> entry,
        ) {
          final int index = entry.key;
          final DaycarePlanModel plan = entry.value;
          return Card(
            child: ListTile(
              title: Text(plan.name),
              subtitle: Text(plan.customerSummaryLines.join('\n')),
              isThreeLine: plan.customerSummaryLines.length > 1,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: '上移',
                    onPressed: index == 0 ? null : () => _move(index, -1),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: '下移',
                    onPressed: index == settings.plans.length - 1
                        ? null
                        : () => _move(index, 1),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  Switch(
                    value: plan.enabled,
                    onChanged: (bool value) {
                      _setPlans(
                        settings.plans
                            .map(
                              (DaycarePlanModel e) => e.id == plan.id
                                  ? e.copyWith(enabled: value)
                                  : e,
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
              onTap: () => _edit(context, existing: plan),
            ),
          );
        }),
      ],
    );
  }
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({required this.plan, this.isNew = false});
  final DaycarePlanModel plan;
  final bool isNew;

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late DaycarePlanModel _plan;
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _included;
  late final TextEditingController _price;
  late final TextEditingController _extraBilling;
  late final TextEditingController _extraPet;
  late final TextEditingController _maxCharge;
  late final TextEditingController _maxPets;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _name = TextEditingController(text: _plan.name);
    _desc = TextEditingController(text: _plan.description);
    _included = TextEditingController(text: '${_plan.includedMinutes}');
    _price = TextEditingController(text: '${_plan.basePrice}');
    _extraBilling = TextEditingController(text: '${_plan.extraBillingPrice}');
    _extraPet = TextEditingController(text: '${_plan.extraPetPrice}');
    _maxCharge = TextEditingController(text: '${_plan.maxBaseCharge}');
    _maxPets = TextEditingController(text: '${_plan.maxPets}');
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _included.dispose();
    _price.dispose();
    _extraBilling.dispose();
    _extraPet.dispose();
    _maxCharge.dispose();
    _maxPets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? '新增安親方案' : '編輯安親方案'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '名稱'),
              ),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: '說明（選填）'),
              ),
              TextField(
                controller: _included,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '起步時間（分鐘）',
                  helperText: '例如 240 代表 4 小時',
                ),
              ),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '起步價格'),
              ),
              DropdownButtonFormField<int>(
                initialValue: _plan.extraBillingMinutes == 30 ? 30 : 60,
                decoration: const InputDecoration(labelText: '超過起步時間後的加收單位'),
                items: const <DropdownMenuItem<int>>[
                  DropdownMenuItem<int>(value: 30, child: Text('每 30 分鐘')),
                  DropdownMenuItem<int>(value: 60, child: Text('每 1 小時')),
                ],
                onChanged: (int? value) {
                  if (value != null) {
                    setState(
                      () => _plan = _plan.copyWith(extraBillingMinutes: value),
                    );
                  }
                },
              ),
              TextField(
                controller: _extraBilling,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '每次加收金額'),
              ),
              TextField(
                controller: _extraPet,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '每多 1 隻寵物加收'),
              ),
              TextField(
                controller: _maxCharge,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '最高時間費用',
                  helperText: '0 代表不限制',
                ),
              ),
              TextField(
                controller: _maxPets,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '最多容納寵物數'),
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
                name: _name.text.trim().isEmpty ? '安親方案' : _name.text.trim(),
                description: _desc.text.trim(),
                includedMinutes:
                    int.tryParse(_included.text) ?? _plan.includedMinutes,
                basePrice: int.tryParse(_price.text) ?? _plan.basePrice,
                extraBillingPrice:
                    int.tryParse(_extraBilling.text) ?? _plan.extraBillingPrice,
                extraPetPrice:
                    int.tryParse(_extraPet.text) ?? _plan.extraPetPrice,
                maxBaseCharge:
                    int.tryParse(_maxCharge.text) ?? _plan.maxBaseCharge,
                maxPets: int.tryParse(_maxPets.text) ?? _plan.maxPets,
              ),
            );
          },
          child: const Text('確定'),
        ),
      ],
    );
  }
}

class _PricingTab extends StatelessWidget {
  const _PricingTab({
    required this.shopId,
    required this.settings,
    required this.onChanged,
  });

  final String shopId;
  final DaycareSettingsModel settings;
  final ValueChanged<DaycareSettingsModel> onChanged;

  void _patch(Map<String, dynamic> extra) {
    onChanged(
      DaycareSettingsModel.fromMap(<String, dynamic>{
        ...settings.toMap(),
        ...extra,
        'updatedAt': null,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          '收費方式',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _ModeCard(
          selected: settings.isRoomBased,
          title: '依房型安親計費',
          subtitle: '店家確認並安排房型後，依房型與當日住宿價格結算。',
          onTap: () => _patch(<String, dynamic>{
            'pricingMode': DaycarePricingModes.roomType,
          }),
        ),
        const SizedBox(height: 8),
        _ModeCard(
          selected: !settings.isRoomBased,
          title: '獨立時數／方案計費',
          subtitle: '適用一般安親店，可在客戶送單時直接依時數或方案計價。',
          onTap: () => _patch(<String, dynamic>{
            'pricingMode': DaycarePricingModes.independentPlan,
          }),
        ),
        const SizedBox(height: 16),
        if (settings.isRoomBased)
          _RoomPricingEditor(
            shopId: shopId,
            settings: settings,
            onChanged: onChanged,
          )
        else ...<Widget>[
          const Text(
            '獨立時數／方案計費',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '客戶選擇方案後依起步時間與超過後加收計算，店家確認時再分配房型與房間。',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _PlanTab(settings: settings, onChanged: onChanged),
        ],
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFF4EA) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFFE8A87C) : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? const Color(0xFFC45C26) : Colors.grey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomPricingEditor extends StatelessWidget {
  const _RoomPricingEditor({
    required this.shopId,
    required this.settings,
    required this.onChanged,
  });

  final String shopId;
  final DaycareSettingsModel settings;
  final ValueChanged<DaycareSettingsModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('room_types')
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                snapshot.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (docs.isEmpty) {
              return const Text('尚未建立住宿房型，無法設定依房型安親價格。');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: docs.map((
                QueryDocumentSnapshot<Map<String, dynamic>> doc,
              ) {
                final String name = (doc.data()['name'] ?? doc.id).toString();
                final int stayCapacity =
                    ((doc.data()['capacity'] as num?)?.toInt() ?? 0);
                final DaycareRoomTypeSetting current =
                    settings.roomTypeSetting(doc.id) ??
                    DaycareRoomTypeSetting(
                      roomTypeId: doc.id,
                      maxPets: stayCapacity > 0 ? stayCapacity.clamp(1, 20) : 1,
                    );
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    title: Text(name),
                    subtitle: Text(
                      current.enabled
                          ? 'NT\$${current.basePrice}　最多 ${current.maxPets} 隻'
                          : '未開放安親',
                    ),
                    children: <Widget>[
                      SwitchListTile(
                        title: const Text('是否啟用'),
                        value: current.enabled,
                        onChanged: (bool value) {
                          _upsert(current.copyWith(enabled: value));
                        },
                      ),
                      _textTile('說明（選填）', current.description, (String v) {
                        _upsert(current.copyWith(description: v));
                      }),
                      _numTile('起步時間（分鐘）', current.includedMinutes, (int v) {
                        _upsert(current.copyWith(includedMinutes: v));
                      }),
                      _numTile('起步價格', current.basePrice, (int v) {
                        _upsert(current.copyWith(basePrice: v));
                      }),
                      DropdownButtonFormField<int>(
                        initialValue: current.extraBillingMinutes == 30
                            ? 30
                            : 60,
                        decoration: const InputDecoration(
                          labelText: '超過起步時間後的加收單位',
                        ),
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem<int>(
                            value: 30,
                            child: Text('每 30 分鐘'),
                          ),
                          DropdownMenuItem<int>(
                            value: 60,
                            child: Text('每 1 小時'),
                          ),
                        ],
                        onChanged: (int? value) {
                          if (value != null) {
                            _upsert(
                              current.copyWith(extraBillingMinutes: value),
                            );
                          }
                        },
                      ),
                      _numTile('每次加收金額', current.extraBillingPrice, (int v) {
                        _upsert(current.copyWith(extraBillingPrice: v));
                      }),
                      _numTile('每多 1 隻寵物加收', current.extraPetPrice, (int v) {
                        _upsert(current.copyWith(extraPetPrice: v));
                      }),
                      _numTile('最高時間費用（0 不限制）', current.maxBaseCharge, (int v) {
                        _upsert(current.copyWith(maxBaseCharge: v));
                      }),
                      _numTile('最多容納寵物數', current.maxPets, (int v) {
                        _upsert(current.copyWith(maxPets: v.clamp(1, 20)));
                      }),
                    ],
                  ),
                );
              }).toList(),
            );
          },
    );
  }

  Widget _textTile(String label, String value, ValueChanged<String> onChanged) {
    return ListTile(
      title: Text(label),
      subtitle: TextFormField(initialValue: value, onChanged: onChanged),
    );
  }

  Widget _numTile(String label, int value, ValueChanged<int> onChanged) {
    return ListTile(
      title: Text(label),
      trailing: SizedBox(
        width: 90,
        child: TextFormField(
          initialValue: '$value',
          keyboardType: TextInputType.number,
          onChanged: (String raw) {
            onChanged(int.tryParse(raw) ?? value);
          },
        ),
      ),
    );
  }

  void _upsert(DaycareRoomTypeSetting next) {
    final List<Map<String, dynamic>> list = settings.roomTypes
        .map((DaycareRoomTypeSetting e) => e.toMap())
        .toList();
    final int index = list.indexWhere(
      (Map<String, dynamic> e) => e['roomTypeId'] == next.roomTypeId,
    );
    if (index >= 0) {
      list[index] = next.toMap();
    } else {
      list.add(next.toMap());
    }
    onChanged(
      DaycareSettingsModel.fromMap(<String, dynamic>{
        ...settings.toMap(),
        'roomTypes': list,
        'updatedAt': null,
      }),
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
              return Column(
                children: <Widget>[
                  const Text('尚未建立加值服務。請先到加購服務設定新增，價格仍在該頁修改。'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ShopAddonPage(shopId: shopId),
                        ),
                      );
                    },
                    child: const Text('前往建立加值服務'),
                  ),
                ],
              );
            }
            final Set<String> allowed = settings.allowedAddonIds.toSet();
            final Set<String> catalogIds = catalog
                .map((Map<String, dynamic> e) => (e['id'] ?? '').toString())
                .toSet();
            final List<String> missingIds = settings.allowedAddonIds
                .where((String id) => !catalogIds.contains(id))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '勾選後，前台安親預約才會顯示這些既有加購服務。名稱與價格請回加購服務設定修改。',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: () => _setAllowed(
                        catalog
                            .where(DaycareAddonCatalog.isItemEnabled)
                            .map((Map<String, dynamic> e) => e['id'].toString())
                            .toList(),
                      ),
                      child: const Text('全選'),
                    ),
                    OutlinedButton(
                      onPressed: () => _setAllowed(const <String>[]),
                      child: const Text('全部取消'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ShopAddonPage(shopId: shopId),
                          ),
                        );
                      },
                      child: const Text('加購服務設定'),
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
                        final bool live = DaycareAddonCatalog.isItemEnabled(
                          item,
                        );
                        final bool on = allowed.contains(id);
                        return Card(
                          child: SwitchListTile(
                            title: Text(DaycareAddonCatalog.displayName(item)),
                            subtitle: Text(
                              live
                                  ? '\$${item['price'] ?? 0}　'
                                        '${DaycareAddonCatalog.chargeLabel(item)}　'
                                        '${DaycareAddonCatalog.inventorySummary(item)}'
                                  : '服務已停用',
                            ),
                            value: on,
                            onChanged: live
                                ? (bool value) {
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
                                  }
                                : (on
                                      ? (bool value) {
                                          final List<String> next =
                                              List<String>.from(
                                                settings.allowedAddonIds,
                                              )..remove(id);
                                          _setAllowed(next);
                                        }
                                      : null),
                          ),
                        );
                      }),
                    ],
                  );
                }),
                if (missingIds.isNotEmpty) ...<Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(
                      '已選但找不到的服務',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...missingIds.map(
                    (String id) => Card(
                      child: SwitchListTile(
                        title: Text(id),
                        subtitle: const Text('服務已停用'),
                        value: true,
                        onChanged: (_) {
                          _setAllowed(
                            List<String>.from(settings.allowedAddonIds)
                              ..remove(id),
                          );
                        },
                      ),
                    ),
                  ),
                ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            subtitle: const Text('安親不再獨立管理條款。請到「入住規則設定」指定各條款適用住宿、安親或兩者。'),
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
          '黑名單沿用會員管理設定，前台住宿與安親一律不可預約。疫苗與結紮不另設安親專用限制。',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
      ],
    );
  }
}
