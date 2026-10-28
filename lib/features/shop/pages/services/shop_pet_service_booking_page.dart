import 'package:petnest_saas/core/models/pet_species.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:petnest_saas/core/models/pet_service_workflow.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pet_service_module.dart';
import 'package:petnest_saas/core/services/pet_service_module_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';

class ShopPetServiceBookingPage extends StatefulWidget {
  const ShopPetServiceBookingPage({
    super.key,
    required this.shopId,
    required this.module,
    this.repository,
  });
  final String shopId;
  final PetServiceModule module;
  final PetServiceModuleService? repository;
  @override
  State<ShopPetServiceBookingPage> createState() =>
      _ShopPetServiceBookingPageState();
}

class _ShopPetServiceBookingPageState extends State<ShopPetServiceBookingPage> {
  late final service = widget.repository ?? PetServiceModuleService();
  late Stream<PetServiceConfig> configStream;
  final key = GlobalKey<FormState>();
  final contact = TextEditingController(),
      phone = TextEditingController(),
      weight = TextEditingController(),
      details = TextEditingController();
  late final intake = [
    for (final _ in widget.module.questions) TextEditingController(),
  ];
  String? serviceId, staffId, requestId;
  String? selectedPetId;
  late Stream<List<Map<String, dynamic>>> petsStream;
  DateTime? date, endDate;
  int? time;
  bool acknowledged = false, busy = false;
  String? submittedId;
  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    petsStream = service.watchMyPets();
    configStream = service.watchConfig(widget.shopId, widget.module);
  }

  @override
  void dispose() {
    for (final c in [contact, phone, weight, details, ...intake]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(PetServiceConfig config, {bool end = false}) async {
    final now = serviceTaipeiNow();
    final today = DateTime(now.year, now.month, now.day);
    final first = end ? (date ?? today).add(const Duration(days: 1)) : today;
    final last = today.add(Duration(days: config.advanceDays));
    if (first.isAfter(last)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('接回日期已超出可預約範圍，請改選較早的入住日期')));
      return;
    }
    var initial = (end ? endDate : date) ?? first;
    if (initial.isBefore(first) || initial.isAfter(last)) initial = first;

    final chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (chosen != null && mounted) {
      setState(() {
        if (end) {
          endDate = chosen;
        } else {
          date = chosen;
          endDate = null;
          time = null;
        }
      });
    }
  }

  Future<void> _submit(
    PetServiceConfig config,
    Map<String, dynamic> item,
    Map<String, dynamic>? staff,
  ) async {
    if (!key.currentState!.validate()) return;
    if (date == null ||
        time == null ||
        !acknowledged ||
        (dogServiceNeedsPickupDate(widget.module, item) && endDate == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇日期、時間並確認預約須知。')));
      return;
    }
    if (dogServiceNeedsPickupDate(widget.module, item) &&
        !endDate!.isAfter(date!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('住宿接回日期需晚於入住日期；當日服務請選擇安親／評估方案')),
      );
      return;
    }
    final submittedDetails = [
      for (var i = 0; i < intake.length; i++)
        if (intake[i].text.trim().isNotEmpty)
          '${widget.module.questions[i]}：${intake[i].text.trim()}',
      if (details.text.trim().isNotEmpty) '其他需求：${details.text.trim()}',
    ].join('\n');
    if (submittedDetails.length > 3000) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('補充資料超過 3000 字，請縮短內容')));
      return;
    }
    final kg = double.tryParse(weight.text) ?? 0;
    final max = (item['maxWeight'] as num?)?.toDouble() ?? 0;
    if (max > 0 && kg > max) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('此項目體重上限為 $max kg，請選擇其他項目。')));
      return;
    }
    if (!petServiceTimes(
      config,
      date!,
      staff,
      widget.module.isDog ? 30 : (item['duration'] as num).toInt(),
    ).contains(time)) {
      setState(() => time = null);
      return;
    }
    if (service.currentUserId == null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPage(redirectShopId: widget.shopId),
        ),
      );
      if (!mounted || service.currentUserId == null) return;
    }
    setState(() => busy = true);
    requestId ??= service.newRequestId(widget.shopId);
    try {
      await service.submit(widget.shopId, requestId!, {
        'petId': selectedPetId,
        'petName': '',
        'module': widget.module.id,
        'serviceId': item['id'],
        'serviceName': item['name'],
        'staffId': staff?['id'] ?? '',
        'staffName': staff?['name'] ?? '由店家安排',
        'date': serviceDate(date!),
        'time': serviceTime(time!),
        'startsAt': Timestamp.fromDate(
          DateTime.utc(
            date!.year,
            date!.month,
            date!.day,
            time! ~/ 60,
            time! % 60,
          ).subtract(const Duration(hours: 8)),
        ),
        'endsAt': Timestamp.fromDate(
          DateTime.utc(
            (dogServiceNeedsPickupDate(widget.module, item) ? endDate! : date!)
                .year,
            (dogServiceNeedsPickupDate(widget.module, item) ? endDate! : date!)
                .month,
            (dogServiceNeedsPickupDate(widget.module, item) ? endDate! : date!)
                .day,
          ).subtract(const Duration(hours: 8)),
        ),
        'endDate': serviceDate(
          dogServiceNeedsPickupDate(widget.module, item) ? endDate! : date!,
        ),
        'contactName': contact.text.trim(),
        'phone': phone.text.trim(),
        'weight': kg,
        'details': submittedDetails,
        'noticeAccepted': true,
      });
      if (mounted) setState(() => submittedId = requestId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('申請未能確認送達，請重試。若服務或班表已變更，請重新選擇。')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text('${widget.module.title}預約'),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _MyServiceRequests(
                        shopId: widget.shopId,
                        module: widget.module,
                        repository: service,
                      ),
                    ),
                  ),
            child: const Text('我的申請'),
          ),
        ],
      ),
      body: submittedId != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.task_alt,
                      size: 60,
                      color: Color(0xff50609a),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '預約申請已送出',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('申請編號：$submittedId'),
                    const Text(
                      '目前狀態：待確認\n店家確認前，尚未成立預約或保留房間／時段。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('返回我要預約'),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<PetServiceConfig>(
              stream: configStream,
              builder: (context, s) {
                if (s.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('服務資料讀取失敗'),
                        TextButton(
                          onPressed: () => setState(_subscribe),
                          child: const Text('重試'),
                        ),
                      ],
                    ),
                  );
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final config = s.data!;
                if (!config.enabled || !config.ready) {
                  return const Center(child: Text('此服務目前尚未開放預約，請洽店家。'));
                }
                final items = config.services
                    .where((e) => e['enabled'] == true)
                    .toList();
                final staffList = config.staff
                    .where(
                      (e) =>
                          e['enabled'] == true &&
                          (serviceId == null ||
                              petStaffSupportsService(e, serviceId!)),
                    )
                    .toList();
                final item = items
                    .where((e) => e['id'] == serviceId)
                    .firstOrNull;
                final staff = staffList
                    .where((e) => e['id'] == staffId)
                    .firstOrNull;
                final times =
                    date == null ||
                        item == null ||
                        (!widget.module.isDog && staff == null)
                    ? <int>[]
                    : petServiceTimes(
                        config,
                        date!,
                        staff,
                        widget.module.isDog
                            ? 30
                            : (item['duration'] as num).toInt(),
                      );
                final validTime = times.contains(time) ? time : null;
                return AbsorbPointer(
                  absorbing: busy,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Form(
                          key: key,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xffeef1fb),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  widget.module.isHospital
                                      ? '選擇門診與醫師後提出申請，待院方確認。急迫狀況請直接電話聯絡醫院。'
                                      : '選擇服務與希望時間，店家確認後才成立預約。價格以店家評估及確認為準。',
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                '1. 選擇服務',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'service-$serviceId-${items.map((e) => e['id']).join()}',
                                ),
                                initialValue: item?['id'],
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '服務項目',
                                ),
                                items: [
                                  for (final e in items)
                                    DropdownMenuItem(
                                      value: e['id'] as String,
                                      child: Text(
                                        '${e['name']} · ${e['price'] == 0 ? '現場報價' : 'NT\$ ${e['price']}／${petServicePriceUnit(widget.module, e)} 起'}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setState(() {
                                  serviceId = v;
                                  staffId = null;
                                  endDate = null;
                                  time = null;
                                }),
                                validator: (v) => v == null ? '請選擇服務項目' : null,
                              ),
                              if (item != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    '${item['description']}\n${widget.module.isDog ? '' : '預計 ${item['duration']} 分鐘'}${(item['maxWeight'] ?? 0) > 0 ? ' · 體重上限 ${item['maxWeight']} kg' : ''}',
                                  ),
                                ),
                              if (!widget.module.isDog) ...[
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    'staff-$staffId-${staffList.map((e) => e['id']).join()}',
                                  ),
                                  initialValue: staff?['id'],
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: widget.module.isHospital
                                        ? '選擇醫師'
                                        : '選擇美容師',
                                  ),
                                  items: [
                                    for (final e in staffList)
                                      DropdownMenuItem(
                                        value: e['id'] as String,
                                        child: Text(
                                          '${e['name']} · ${e['description']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => setState(() {
                                    staffId = v;
                                    time = null;
                                  }),
                                  validator: (v) =>
                                      v == null ? '請選擇服務人員' : null,
                                ),
                              ],
                              const SizedBox(height: 22),
                              const Text(
                                '2. 希望日期與時間',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _pickDate(config),
                                    icon: const Icon(Icons.calendar_today),
                                    label: Text(
                                      date == null
                                          ? '選擇日期'
                                          : serviceDate(date!),
                                    ),
                                  ),
                                  if (item != null &&
                                      dogServiceNeedsPickupDate(
                                        widget.module,
                                        item,
                                      ))
                                    OutlinedButton.icon(
                                      onPressed: date == null
                                          ? null
                                          : () => _pickDate(config, end: true),
                                      icon: const Icon(Icons.event),
                                      label: Text(
                                        endDate == null
                                            ? '選擇接回日期'
                                            : serviceDate(endDate!),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                key: ValueKey(
                                  'time-$date-$staffId-$serviceId-$validTime',
                                ),
                                initialValue: validTime,
                                decoration: const InputDecoration(
                                  labelText: '希望開始時間',
                                ),
                                items: [
                                  for (final n in times)
                                    DropdownMenuItem(
                                      value: n,
                                      child: Text(serviceTime(n)),
                                    ),
                                ],
                                onChanged: (v) => setState(() => time = v),
                                validator: (v) => v == null ? '請選擇可申請時間' : null,
                              ),
                              if (date != null && times.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text('請先選擇服務／人員；若此日沒有時段，請改選其他日期。'),
                                ),
                              const SizedBox(height: 22),
                              const Text(
                                '3. 聯絡與寵物資料',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                ),
                              ),
                              _input(contact, '聯絡人', max: 80),
                              _input(phone, '聯絡電話', max: 30),
                              if (service.currentUserId == null)
                                FilledButton(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LoginPage(
                                          redirectShopId: widget.shopId,
                                        ),
                                      ),
                                    );
                                    if (mounted) setState(_subscribe);
                                  },
                                  child: const Text('登入並選擇我的寵物'),
                                ),
                              StreamBuilder<List<Map<String, dynamic>>>(
                                stream: petsStream,
                                builder: (context, snapshot) {
                                  if (snapshot.hasError)
                                    return const Text('寵物資料讀取失敗，請返回後重試');
                                  if (!snapshot.hasData)
                                    return const LinearProgressIndicator();
                                  final pets = snapshot.data!
                                      .where(
                                        (p) => config.acceptedSpecies.contains(
                                          PetSpecies.of(p),
                                        ),
                                      )
                                      .toList();
                                  final validId =
                                      pets.any(
                                        (p) => p['petId'] == selectedPetId,
                                      )
                                      ? selectedPetId
                                      : null;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        '可接待：${config.acceptedSpecies.map(PetSpecies.label).join('、')}',
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        key: ValueKey(
                                          'service-pet-$validId-${pets.map((p) => p['petId']).join()}',
                                        ),
                                        initialValue: validId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: '選擇我的寵物',
                                        ),
                                        items: [
                                          for (final p in pets)
                                            DropdownMenuItem(
                                              value: '${p['petId']}',
                                              child: Text(
                                                '${p['name']} · ${PetSpecies.label(PetSpecies.of(p))}',
                                              ),
                                            ),
                                        ],
                                        onChanged: (v) => setState(() {
                                          selectedPetId = v;
                                        }),
                                        validator: (v) =>
                                            v == null ? '請選擇符合服務種類的寵物' : null,
                                      ),
                                      if (pets.isEmpty)
                                        const Text('目前沒有符合種類的寵物，請新增或補齊寵物種類。'),
                                      TextButton.icon(
                                        icon: const Icon(Icons.add),
                                        label: const Text('新增寵物'),
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AddPetPage(
                                                shopId: widget.shopId,
                                              ),
                                            ),
                                          );
                                          if (mounted) setState(_subscribe);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                              _input(weight, '體重 kg', numeric: true, max: 8),
                              const SizedBox(height: 12),
                              const Text(
                                '4. 服務前資料',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                ),
                              ),
                              for (var i = 0; i < intake.length; i++)
                                _input(
                                  intake[i],
                                  widget.module.questions[i],
                                  lines: 2,
                                  max: 450,
                                  required:
                                      i == 0 ||
                                      (widget.module.isHospital && i == 1),
                                ),
                              _input(
                                details,
                                '其他需求（選填）',
                                lines: 3,
                                max: 900,
                                required: false,
                              ),
                              if (config.notice.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  color: const Color(0xfff5f6fa),
                                  child: Text(config.notice),
                                ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: acknowledged,
                                onChanged: (v) =>
                                    setState(() => acknowledged = v ?? false),
                                title: const Text('我已閱讀服務須知，了解這是待店家確認的預約申請。'),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed:
                                    item == null ||
                                        (!widget.module.isDog && staff == null)
                                    ? null
                                    : () => _submit(config, item, staff),
                                icon: busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send_outlined),
                                label: Text(busy ? '送出中…' : '送出預約申請'),
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    ),
  );
  Widget _input(
    TextEditingController c,
    String label, {
    int lines = 1,
    int max = 200,
    bool numeric = false,
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: c,
      maxLines: lines,
      maxLength: max,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      validator: (v) {
        if (required && (v ?? '').trim().isEmpty) return '請填寫此欄位';
        if (numeric) {
          final n = double.tryParse(v!);
          if (n == null || !n.isFinite || n <= 0 || n > 200) return '請填寫有效體重';
        }
        return null;
      },
    ),
  );
}

class _MyServiceRequests extends StatefulWidget {
  const _MyServiceRequests({
    required this.shopId,
    required this.module,
    this.repository,
  });
  final PetServiceModuleService? repository;
  final String shopId;
  final PetServiceModule module;
  @override
  State<_MyServiceRequests> createState() => _MyServiceRequestsState();
}

class _MyServiceRequestsState extends State<_MyServiceRequests> {
  late final service = widget.repository ?? PetServiceModuleService();
  late final stream = service.watchRequests(
    widget.shopId,
    widget.module.id,
    mine: true,
  );
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我的預約申請')),
    body: service.currentUserId == null
        ? Center(
            child: FilledButton(
              onPressed: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginPage(redirectShopId: widget.shopId),
                    ),
                  ).then((_) {
                    if (mounted) setState(() {});
                  }),
              child: const Text('登入查看申請'),
            ),
          )
        : StreamBuilder<List<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, s) {
              if (s.hasError) return const Center(child: Text('申請讀取失敗，請返回後重試'));
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.data!.isEmpty) return const Center(child: Text('目前沒有申請紀錄'));
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  for (final row in s.data!)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['petName']} · ${row['serviceName']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${row['date']} ${row['time']}\n${row['staffName']}\n狀態：${petServiceStatus(widget.module, '${row['status']}')}\n申請編號：${row['id']}',
                            ),
                            if ([
                              'pending',
                              'confirmed',
                            ].contains(row['status']))
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('取消這筆申請？'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('返回'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('取消申請'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok != true || !mounted) return;
                                        setState(() => busy = true);
                                        try {
                                          await service.transition(
                                            widget.shopId,
                                            row['id'],
                                            row['status'],
                                            'cancelled',
                                          );
                                        } catch (_) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  '取消失敗，請確認目前狀態後重試',
                                                ),
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => busy = false);
                                          }
                                        }
                                      },
                                child: const Text('取消申請'),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
  );
}
