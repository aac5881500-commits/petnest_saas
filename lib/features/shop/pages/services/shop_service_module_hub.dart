import 'package:petnest_saas/core/models/pet_service_workflow.dart';
import 'package:petnest_saas/features/shop/widgets/services/pet_service_overview.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pet_service_module.dart';
import 'package:petnest_saas/core/services/pet_service_module_service.dart';

class ShopServiceModuleHub extends StatefulWidget {
  const ShopServiceModuleHub({
    super.key,
    required this.shopId,
    required this.module,
    required this.canConfigure,
    required this.canManage,
    this.repository,
  });
  final String shopId;
  final PetServiceModule module;
  final bool canConfigure, canManage;
  final PetServiceModuleService? repository;
  @override
  State<ShopServiceModuleHub> createState() => _ShopServiceModuleHubState();
}

class _ShopServiceModuleHubState extends State<ShopServiceModuleHub> {
  late final service = widget.repository ?? PetServiceModuleService();
  late Stream<PetServiceConfig> configStream;
  late Stream<List<Map<String, dynamic>>> requestStream;
  String section = 'overview', filter = 'active', search = '';
  String? requestDate;
  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant ShopServiceModuleHub old) {
    super.didUpdateWidget(old);
    if (old.shopId != widget.shopId ||
        old.module.id != widget.module.id ||
        old.canManage != widget.canManage) {
      section = 'overview';
      _subscribe();
    }
  }

  void _subscribe() {
    configStream = service.watchConfig(widget.shopId, widget.module);
    requestStream = widget.canManage
        ? service.watchRequests(widget.shopId, widget.module.id)
        : Stream.value([]);
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(petServiceFailure(error))));
      }
    }
  }

  Widget _card(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: PetServiceMenuTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
    ),
  );
  Widget _group(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: PetServiceSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  void _filterRequests(String value) => setState(() {
    section = 'requests';
    requestDate = value == 'today' ? serviceDate(serviceTaipeiNow()) : null;
    filter = value == 'today' ? 'active' : value;
  });
  Future<void> _showServiceInfo(
    PetServiceConfig config, {
    bool intake = false,
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(intake ? '服務前資料' : '受理流程與須知'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: intake
                ? [
                    const Text('會員提出預約時，會依服務類型填寫以下資料：'),
                    const SizedBox(height: 12),
                    for (final question in widget.module.questions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(question)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text('客人的實際填寫內容可在「預約管理」的申請明細查看。'),
                  ]
                : [
                    Text(
                      widget.module.isDog
                          ? '適應評估 → 住宿／安親申請 → 店家確認 → 入住 → 照護紀錄 → 接回完成'
                          : widget.module.isHospital
                          ? '選擇門診與醫師 → 提出申請 → 院方確認 → 到院報到 → 處理紀錄 → 完成'
                          : '選擇項目與美容師 → 提出申請 → 店家確認 → 到店評估 → 美容紀錄 → 接回完成',
                    ),
                    const SizedBox(height: 16),
                    const Text('預約採人工受理。確認前請核對房間、人員與時段；資源提醒不會自動鎖房或鎖時段。'),
                    const SizedBox(height: 16),
                    const Text(
                      '目前服務須知',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      config.notice.isEmpty
                          ? '尚未填寫，可到「預約開放與須知」設定。'
                          : config.notice,
                    ),
                    if (widget.module.isHospital) ...[
                      const SizedBox(height: 16),
                      const Text('此模組管理門診預約與行政紀錄；完整病歷、處方及檢驗系統仍需另外串接。'),
                    ],
                  ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    ),
  );
  void _open(String value) => setState(() {
    section = value;
  });
  @override
  Widget build(BuildContext context) => StreamBuilder<PetServiceConfig>(
    stream: configStream,
    builder: (context, c) {
      if (c.hasError) return _error('模組資料讀取失敗');
      if (!c.hasData) return const Center(child: CircularProgressIndicator());
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: requestStream,
        builder: (context, r) {
          final config = c.data!, rows = r.data ?? [];
          return ColoredBox(
            color: const Color(0xfff7f8fc),
            child: LayoutBuilder(
              builder: (context, viewport) => Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: ListView(
                    padding: EdgeInsets.all(viewport.maxWidth < 720 ? 12 : 24),
                    children: [
                      Row(
                        children: [
                          if (section != 'overview')
                            IconButton(
                              onPressed: () => _open('overview'),
                              icon: const Icon(Icons.arrow_back),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.module.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.module.subtitle,
                                  style: const TextStyle(
                                    color: Color(0xff65718d),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(config.enabled ? '接受預約申請' : '尚未開放預約'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (section == 'overview')
                        PetServiceOverview(
                          module: widget.module,
                          config: config,
                          rows: rows,
                          canConfigure: widget.canConfigure,
                          canManage: widget.canManage,
                          loading: !r.hasData && !r.hasError,
                          failed: r.hasError,
                          onOpenRequests: () => _filterRequests('active'),
                          onOpenCatalogue: () => _open('services'),
                          onOpenStaff: () => _open('staff'),
                          onOpenSettings: () => _settings(config),
                          onOpenIntake: () =>
                              _showServiceInfo(config, intake: true),
                          onOpenWorkflow: () => _showServiceInfo(config),
                          onOpenRecord: () => _filterRequests('all'),
                          onFilter: _filterRequests,
                          onOpenRequest: (row) => _detail(row, config, rows),
                        ),
                      if (section == 'services' || section == 'staff')
                        _catalogue(config, section == 'staff'),
                      if (section == 'requests') ...[
                        if (r.hasError)
                          _error('預約資料讀取失敗')
                        else if (!r.hasData)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.date_range),
                                label: Text(requestDate ?? '依日期查看'),
                                onPressed: () async {
                                  final now = serviceTaipeiNow();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        DateTime.tryParse(requestDate ?? '') ??
                                        DateTime(now.year, now.month, now.day),
                                    firstDate: DateTime(now.year - 2),
                                    lastDate: DateTime(now.year + 3),
                                  );
                                  if (picked != null && mounted) {
                                    setState(
                                      () => requestDate = serviceDate(picked),
                                    );
                                  }
                                },
                              ),
                              if (requestDate != null)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => requestDate = null),
                                  child: const Text('全部日期'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              labelText: '搜尋寵物、聯絡人、電話、服務或人員',
                            ),
                            onChanged: (v) => setState(() => search = v.trim()),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final f in [
                                'active',
                                'pending',
                                'confirmed',
                                'arrived',
                                'completed',
                                'cancelled',
                                'declined',
                                'all',
                              ])
                                ChoiceChip(
                                  label: Text(
                                    f == 'active'
                                        ? '處理中'
                                        : f == 'all'
                                        ? '全部'
                                        : petServiceStatus(widget.module, f),
                                  ),
                                  selected: filter == f,
                                  onSelected: (_) => setState(() => filter = f),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (rows.where(_matches).isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(28),
                              child: Text('目前沒有符合的預約申請。'),
                            ),
                          for (final row in rows.where(_matches))
                            _card(
                              '${row['petName']} · ${row['serviceName']}',
                              '${row['date']} ${row['time']} · ${row['contactName']} · ${petServiceStatus(widget.module, '${row['status']}')}',
                              Icons.event_available,
                              () => _detail(row, config, rows),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  bool _matches(Map<String, dynamic> row) =>
      (filter == 'all' ||
          (filter == 'active'
              ? ['pending', 'confirmed', 'arrived'].contains(row['status'])
              : row['status'] == filter)) &&
      (requestDate == null || petRequestOnDate(row, requestDate!)) &&
      '${row['petName']} ${row['contactName']} ${row['serviceName']} ${row['phone']} ${row['staffName']}'
          .toLowerCase()
          .contains(search.toLowerCase());
  Widget _error(String text) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        TextButton(
          onPressed: () => setState(_subscribe),
          child: const Text('重新讀取'),
        ),
      ],
    ),
  );
  Widget _catalogue(PetServiceConfig config, bool staff) {
    final items = staff ? config.staff : config.services;
    return _group(staff ? widget.module.staffTitle : widget.module.catalogueTitle, [
      if (widget.canConfigure)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _editItem(config, staff, null),
            icon: const Icon(Icons.add),
            label: Text(staff ? '新增人員' : '新增項目'),
          ),
        ),
      const SizedBox(height: 12),
      if (items.isEmpty)
        Text(
          staff
              ? '尚未建立人員。請填寫實際姓名與班表。'
              : '尚未建立項目。可參考：${widget.module.suggestions.join('、')}',
        ),
      if (!staff && widget.canConfigure)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.module.suggestions.length; i++)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(widget.module.suggestions[i]),
                  onPressed: () => _editItem(config, false, {
                    'name': widget.module.suggestions[i],
                    'enabled': true,
                    'price': 0,
                    'duration': widget.module.isDog || widget.module.isHospital
                        ? 30
                        : 60,
                    'kind': widget.module.isDog
                        ? ['overnight', 'overnight', 'daycare', 'assessment'][i]
                        : widget.module.isHospital
                        ? [
                            'consultation',
                            'wellness',
                            'specialty',
                            'wellness',
                          ][i]
                        : ['bath', 'styling', 'addon', 'spa'][i],
                  }),
                ),
            ],
          ),
        ),
      for (final item in items)
        _card(
          '${item['name']} ${item['enabled'] == true ? '' : '（停用）'}',
          staff
              ? '${item['description']}\n${serviceTime(item['opens'] ?? 600)}–${serviceTime(item['closes'] ?? 1080)} · 每週 ${(item['days'] as List? ?? []).join('、')}'
              : '${petServiceCatalogueSummary(widget.module, item)}\n${item['description']}',
          staff ? Icons.person_outline : widget.module.icon,
          widget.canConfigure ? () => _editItem(config, staff, item) : null,
        ),
    ]);
  }

  Future<void> _editItem(
    PetServiceConfig config,
    bool staff,
    Map<String, dynamic>? item,
  ) async {
    final key = GlobalKey<FormState>();
    final name = TextEditingController(text: item?['name'] ?? '');
    final description = TextEditingController(text: item?['description'] ?? '');
    final price = TextEditingController(text: '${item?['price'] ?? 0}');
    final duration = TextEditingController(
      text: '${item?['duration'] ?? (widget.module.isHospital ? 30 : 60)}',
    );
    final limit = TextEditingController(text: '${item?['maxWeight'] ?? 0}');
    final capacity = TextEditingController(text: '${item?['capacity'] ?? 0}');
    var kind = petServiceKind(widget.module, item ?? {});
    var animalType = const ['dog', 'cat', 'both'].contains(item?['animalType'])
        ? item!['animalType'] as String
        : widget.module.isHospital
        ? 'both'
        : 'dog';
    final assignedServices =
        (item?['serviceIds'] is List ? item!['serviceIds'] as List : const [])
            .whereType<String>()
            .toList();
    var enabled = item?['enabled'] != false, busy = false;
    var opens = (item?['opens'] as num?)?.toInt() ?? 600,
        closes = (item?['closes'] as num?)?.toInt() ?? 1080;
    final days = List<int>.from(item?['days'] ?? [1, 2, 3, 4, 5, 6]);
    await _serviceDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(staff ? '人員與每週班表' : '服務項目'),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Form(
                  key: key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _field(
                        name,
                        staff ? '公開姓名' : '項目名稱',
                        required: true,
                        max: 80,
                      ),
                      _field(
                        description,
                        staff
                            ? '專長／公開介紹'
                            : widget.module.isDog
                            ? '房型／方案說明、適應條件'
                            : '服務內容／注意事項',
                        lines: 3,
                        max: 1500,
                      ),
                      if (!staff) ...[
                        DropdownButtonFormField<String>(
                          initialValue: kind,
                          decoration: const InputDecoration(labelText: '服務分類'),
                          items: [
                            for (final e in petServiceKinds(
                              widget.module,
                            ).entries)
                              DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                          ],
                          onChanged: busy ? null : (v) => set(() => kind = v!),
                        ),
                        const SizedBox(height: 12),
                        if (!widget.module.isDog)
                          DropdownButtonFormField<String>(
                            initialValue: animalType,
                            decoration: const InputDecoration(
                              labelText: '服務動物',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'dog', child: Text('狗狗')),
                              DropdownMenuItem(value: 'cat', child: Text('貓咪')),
                              DropdownMenuItem(
                                value: 'both',
                                child: Text('犬貓皆可'),
                              ),
                            ],
                            onChanged: busy
                                ? null
                                : (v) => set(() => animalType = v!),
                          ),
                        _field(price, '參考起價（0 表示現場評估）', number: true),
                        Text(
                          '計價單位：每${petServicePriceUnit(widget.module, {'kind': kind})}；實際費用依店家確認',
                        ),
                        if (widget.module.isDog)
                          _field(
                            capacity,
                            '同一方案接待量（0 表示尚未設定）',
                            number: true,
                            maxValue: 200,
                          ),
                        _field(
                          duration,
                          '時段所需分鐘（30–480）',
                          number: true,
                          minValue: 30,
                          maxValue: 480,
                        ),
                        if (widget.module.isDog || !widget.module.isHospital)
                          _field(
                            limit,
                            '體重上限 kg（0 表示不限）',
                            number: true,
                            maxValue: 200,
                          ),
                      ],
                      if (staff) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('可服務項目（不勾選表示全部）'),
                        ),
                        for (final entry in config.services.where(
                          (e) => e['enabled'] == true,
                        ))
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${entry['name']}'),
                            value: assignedServices.contains(entry['id']),
                            onChanged: busy
                                ? null
                                : (value) => set(() {
                                    if (value == true) {
                                      assignedServices.add(entry['id']);
                                    } else {
                                      assignedServices.remove(entry['id']);
                                    }
                                  }),
                          ),
                        _days(days, (v) {
                          set(
                            () =>
                                days.contains(v) ? days.remove(v) : days.add(v),
                          );
                        }),
                        _hours(
                          opens,
                          closes,
                          (a, b) => set(() {
                            opens = a;
                            closes = b;
                          }),
                        ),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('啟用'),
                        value: enabled,
                        onChanged: busy ? null : (v) => set(() => enabled = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!key.currentState!.validate()) return;
                        if (staff && (days.isEmpty || opens >= closes)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請設定有效班表')),
                          );
                          return;
                        }
                        set(() => busy = true);
                        try {
                          final data = config.editable,
                              bucket = serviceMap(
                                data[staff ? 'staff' : 'services'],
                              );
                          final id =
                              item?['id'] ??
                              service.newRequestId(widget.shopId);
                          bucket[id] = {
                            ...(serviceMap(item)..remove('id')),
                            'name': name.text.trim(),
                            'description': description.text.trim(),
                            'enabled': enabled,
                            if (staff) ...{
                              'serviceIds': assignedServices,
                              'days': days,
                              'opens': opens,
                              'closes': closes,
                            } else ...{
                              'kind': kind,
                              'animalType': widget.module.isDog
                                  ? 'dog'
                                  : animalType,
                              'capacity': int.parse(capacity.text),
                              'price': int.parse(price.text),
                              'duration': int.parse(duration.text),
                              'maxWeight': int.parse(limit.text),
                            },
                          };
                          data[staff ? 'staff' : 'services'] = bucket;
                          await service.saveConfig(
                            widget.shopId,
                            widget.module,
                            data,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (error) {
                          if (ctx.mounted) {
                            set(() => busy = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(petServiceFailure(error))),
                            );
                          }
                        }
                      },
                child: Text(busy ? '儲存中…' : '儲存'),
              ),
            ],
          ),
        ),
      ),
    );
    for (final c in [name, description, price, duration, limit, capacity]) {
      c.dispose();
    }
  }

  Future<void> _settings(PetServiceConfig config) async {
    final key = GlobalKey<FormState>();
    final notice = TextEditingController(text: config.notice);
    final advance = TextEditingController(text: '${config.advanceDays}');
    final days = [...config.days];
    final acceptedSpecies = [...config.acceptedSpecies];
    var enabled = config.enabled,
        busy = false,
        opens = config.opens,
        closes = config.closes;
    await _serviceDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: const Text('預約開放與須知'),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Form(
                  key: key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('接受前台預約申請'),
                        value: enabled,
                        onChanged: busy ? null : (v) => set(() => enabled = v),
                      ),
                      if (!widget.module.isDog) ...[
                        const ListTile(
                          title: Text('可接待的寵物種類'),
                          subtitle: Text('前台只顯示勾選種類的會員寵物'),
                        ),
                        for (final entry in {'cat': '貓咪', 'dog': '狗狗'}.entries)
                          CheckboxListTile(
                            title: Text(entry.value),
                            value: acceptedSpecies.contains(entry.key),
                            onChanged: busy
                                ? null
                                : (v) => set(() {
                                    if (v == true) {
                                      acceptedSpecies.add(entry.key);
                                    } else {
                                      acceptedSpecies.remove(entry.key);
                                    }
                                  }),
                          ),
                      ],
                      const Text('開放後出現在「我要預約」分類內。送出為待確認，店家核對後才成立。'),
                      _days(
                        days,
                        (v) => set(
                          () => days.contains(v) ? days.remove(v) : days.add(v),
                        ),
                      ),
                      _hours(
                        opens,
                        closes,
                        (a, b) => set(() {
                          opens = a;
                          closes = b;
                        }),
                      ),
                      _field(
                        advance,
                        '可提前預約天數（1–180）',
                        number: true,
                        minValue: 1,
                        maxValue: 180,
                      ),
                      _field(
                        notice,
                        widget.module.isDog
                            ? '入住／安親須知'
                            : widget.module.isHospital
                            ? '門診與報到須知'
                            : '美容服務須知',
                        lines: 5,
                        max: 3000,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!key.currentState!.validate()) return;
                        set(() => busy = true);
                        try {
                          await service
                              .saveConfig(widget.shopId, widget.module, {
                                ...config.editable,
                                'enabled': enabled,
                                'acceptedSpecies': acceptedSpecies,
                                'notice': notice.text.trim(),
                                'days': days,
                                'opens': opens,
                                'closes': closes,
                                'advanceDays': int.parse(advance.text),
                              });
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (error) {
                          if (ctx.mounted) {
                            set(() => busy = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(petServiceFailure(error))),
                            );
                          }
                        }
                      },
                child: Text(busy ? '儲存中…' : '儲存'),
              ),
            ],
          ),
        ),
      ),
    );
    notice.dispose();
    advance.dispose();
  }

  Future<void> _detail(
    Map<String, dynamic> initial,
    PetServiceConfig config,
    List<Map<String, dynamic>> rows,
  ) async {
    final note = TextEditingController();
    final recordControllers = [
      for (final _ in petServiceRecordFields(widget.module))
        TextEditingController(),
    ];
    final conflicts = petServiceConflicts(widget.module, initial, rows, config);
    var busy = false;
    await _serviceDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text('${initial['petName']} · 預約明細'),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '申請編號：${initial['id']}\n服務：${initial['serviceName']}\n希望日期：${initial['date']} ${initial['time']}\n${widget.module.isDog ? '接回日期：${initial['endDate']}\n' : ''}指定人員：${initial['staffName']}\n聯絡人：${initial['contactName']}\n電話：${initial['phone']}\n寵物：${initial['petName']}\n體重：${initial['weight']} kg\n疫苗類型：${(initial['petSnapshot'] as Map?)?['vaccineTypes'] ?? '未填寫'}\n補充資料：${initial['details']}',
                    ),
                    if (conflicts.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 12),
                        color: Colors.amber.shade50,
                        child: Text('接待資源提醒\n${conflicts.join('\n')}'),
                      ),
                    const Divider(height: 28),
                    Text(
                      widget.module.recordTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('僅供有預約管理權限的店家人員查看。'),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: service.records(widget.shopId, initial['id']),
                      builder: (context, s) {
                        if (s.hasError) return const Text('紀錄讀取失敗，請關閉後重試');
                        if (!s.hasData) return const LinearProgressIndicator();
                        if (s.data!.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('尚無紀錄'),
                          );
                        }
                        return Column(
                          children: [
                            for (final entry in s.data!)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${entry['note']}'),
                                subtitle: Text(
                                  petServiceTimestamp(entry['createdAt']),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    for (var i = 0; i < recordControllers.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextField(
                          controller: recordControllers[i],
                          maxLength: 500,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: petServiceRecordFields(widget.module)[i],
                          ),
                        ),
                      ),
                    TextField(
                      controller: note,
                      maxLines: 4,
                      maxLength: 900,
                      decoration: const InputDecoration(
                        labelText: '新增評估／服務／照護紀錄',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final text = composePetServiceRecord(
                                widget.module,
                                recordControllers.map((c) => c.text).toList(),
                                note.text,
                              );
                              if (text.isEmpty) return;
                              set(() => busy = true);
                              await _run(() async {
                                await service.addRecord(
                                  widget.shopId,
                                  initial['id'],
                                  text,
                                );
                                note.clear();
                                for (final controller in recordControllers) {
                                  controller.clear();
                                }
                              });
                              if (ctx.mounted) set(() => busy = false);
                            },
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('新增紀錄'),
                    ),
                    const Text('確認前請人工核對房間、人員與時段；此流程不自動鎖定資源。'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('關閉'),
              ),
              for (final next
                  in serviceTransitions[initial['status']] ?? <String>[])
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder: (c) => AlertDialog(
                              title: Text(
                                '變更為「${petServiceStatus(widget.module, next)}」？',
                              ),
                              content: Text(
                                conflicts.isNotEmpty && next == 'confirmed'
                                    ? '目前有接待資源提醒：\n${conflicts.join('\n')}\n請先核對並安排替代資源，再確認受理。'
                                    : '請確認已核對預約內容、接待資源與聯絡事項。',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('返回'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('確認變更'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true || !ctx.mounted) return;
                          set(() => busy = true);
                          var success = false;
                          await _run(() async {
                            await service.transition(
                              widget.shopId,
                              initial['id'],
                              initial['status'],
                              next,
                            );
                            success = true;
                          });
                          if (ctx.mounted) {
                            if (success) {
                              Navigator.pop(ctx);
                            } else {
                              set(() => busy = false);
                            }
                          }
                        },
                  child: Text(petServiceStatus(widget.module, next)),
                ),
            ],
          ),
        ),
      ),
    );
    note.dispose();
    for (final controller in recordControllers) {
      controller.dispose();
    }
  }
}

Widget _field(
  TextEditingController c,
  String label, {
  bool required = false,
  bool number = false,
  int lines = 1,
  int minValue = 0,
  int maxValue = 999999,
  int max = 300,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: TextFormField(
    controller: c,
    maxLines: lines,
    maxLength: number ? null : max,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      if (required && (v ?? '').trim().isEmpty) return '請填寫此欄位';
      if (number) {
        final n = int.tryParse(v ?? '');
        if (n == null || n < minValue || n > maxValue) {
          return '請輸入 $minValue–$maxValue 的整數';
        }
      }
      return null;
    },
  ),
);
Widget _days(List<int> days, ValueChanged<int> change) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Wrap(
    spacing: 6,
    children: [
      for (var i = 1; i <= 7; i++)
        FilterChip(
          label: Text('週${['一', '二', '三', '四', '五', '六', '日'][i - 1]}'),
          selected: days.contains(i),
          onSelected: (_) => change(i),
        ),
    ],
  ),
);
Widget _hours(int opens, int closes, void Function(int, int) change) => Wrap(
  spacing: 16,
  runSpacing: 8,
  children: [
    SizedBox(
      width: 160,
      child: DropdownButtonFormField<int>(
        initialValue: opens,
        decoration: const InputDecoration(labelText: '開始時間'),
        items: [
          for (var n = 0; n <= 1410; n += 30)
            DropdownMenuItem(value: n, child: Text(serviceTime(n))),
        ],
        onChanged: (v) => change(v!, closes),
      ),
    ),
    SizedBox(
      width: 160,
      child: DropdownButtonFormField<int>(
        initialValue: closes,
        decoration: const InputDecoration(labelText: '結束時間'),
        items: [
          for (var n = 30; n <= 1440; n += 30)
            DropdownMenuItem(value: n, child: Text(serviceTime(n))),
        ],
        onChanged: (v) => change(opens, v!),
      ),
    ),
  ],
);

// DialogRoute.popped completes before the reverse animation. Controllers must
// stay alive until the overlay is actually removed.
Future<void> _serviceDialog({
  required BuildContext context,
  required bool barrierDismissible,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
  await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
}
