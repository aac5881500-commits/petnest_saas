// 檔案名稱：lib/features/admin/pages/admin_create_daycare_booking_page.dart
// 功能說明：後台手動新增臨托訂單：沿用住宿日期表、寵物、房型、加值與條款簽署方式

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_calendar_helper.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/admin/widgets/admin_member_search_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_quick_create_pet_dialog.dart';
import 'package:petnest_saas/features/admin/widgets/admin_selected_member_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_date_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';
import 'package:petnest_saas/features/shop/widgets/booking/policy_sign_method_field.dart';

class AdminCreateDaycareBookingPage extends StatefulWidget {
  const AdminCreateDaycareBookingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminCreateDaycareBookingPage> createState() =>
      _AdminCreateDaycareBookingPageState();
}

class _AdminCreateDaycareBookingPageState
    extends State<AdminCreateDaycareBookingPage> {
  final TextEditingController _keyword = TextEditingController();
  String _keywordText = '';
  Map<String, dynamic>? _member;
  Map<String, dynamic> _shop = const <String, dynamic>{};
  DaycareSettingsModel? _settings;
  DateTime? _date;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Future<FrontCalendarPayload>? _calendarFuture;
  String? _dropOff;
  String? _pickUp;
  DaycarePlanModel? _plan;
  final Set<String> _petIds = <String>{};
  List<Map<String, dynamic>> _pets = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _addons = <Map<String, dynamic>>[];
  final Set<String> _selectedAddonIds = <String>{};
  bool _submitting = false;
  final int _manualAdjust = 0;
  bool _policyRequired = false;
  int _policyVersion = 0;
  String? _policySignMethod;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final DaycareSettingsModel settings = await DaycareSettingsService.instance
        .get(widget.shopId);
    final Map<String, dynamic>? shop = await ShopService.instance.getShop(
      widget.shopId,
    );
    final QuerySnapshot<Map<String, dynamic>> addonSnap =
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('addons')
            .limit(1)
            .get();
    final Map<String, dynamic>? addonData = addonSnap.docs.isEmpty
        ? null
        : addonSnap.docs.first.data();
    final List<Map<String, dynamic>> addons =
        DaycareAddonCatalog.allowedForDaycare(
          doc: addonData,
          allowedAddonIds: settings.allowedAddonIds,
        );
    final Map<String, dynamic>? policy = await ShopPolicyService.instance
        .getCheckinPolicy(widget.shopId);
    bool required = false;
    int version = 0;
    if (policy != null) {
      final Map<String, dynamic> filtered = ShopPolicyService.instance
          .filterPolicyForService(
            policy: policy,
            serviceType: PolicyApplicableService.daycare,
          );
      required = ShopPolicyService.instance.policyRequiresSignature(
        filteredPolicy: filtered,
      );
      version = (filtered['version'] as num?)?.toInt() ?? 0;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _shop = shop ?? const <String, dynamic>{};
      _addons = addons;
      _policyRequired = required;
      _policyVersion = version;
    });
  }

  Future<void> _loadPets(String userId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
        .instance
        .collection('user_profiles')
        .doc(userId)
        .collection('pets')
        .get();
    setState(() {
      _pets = snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                <String, dynamic>{'id': d.id, ...d.data()},
          )
          .toList();
      _petIds.clear();
    });
  }

  Future<void> _openCalendar() async {
    final DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final int maxDays =
        int.tryParse((_shop['maxAdvanceBookingDays'] ?? '90').toString()) ?? 90;
    DateTime? tempDate = _date;
    _calendarFuture = DaycareCalendarHelper.buildPayload(
      shopId: widget.shopId,
      shop: _shop,
      settings: _settings ?? const DaycareSettingsModel(),
      firstDate: DateTime(_calendarMonth.year, _calendarMonth.month),
      lastDate: DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0),
    );
    await showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setInnerState) {
            return FutureBuilder<FrontCalendarPayload>(
              future: _calendarFuture,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<FrontCalendarPayload> snapshot,
                  ) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return BookingCalendarDialog(
                      payload: snapshot.data!,
                      calendarMonth: _calendarMonth,
                      today: today,
                      maxDays: maxDays,
                      tempStartDate: tempDate,
                      tempEndDate: tempDate,
                      rangeMessage: '',
                      singleDay: true,
                      onMonthChanged: (DateTime newMonth) {
                        setState(() {
                          _calendarMonth = newMonth;
                          _calendarFuture = DaycareCalendarHelper.buildPayload(
                            shopId: widget.shopId,
                            shop: _shop,
                            settings: _settings ?? const DaycareSettingsModel(),
                            firstDate: DateTime(newMonth.year, newMonth.month),
                            lastDate: DateTime(
                              newMonth.year,
                              newMonth.month + 1,
                              0,
                            ),
                          );
                        });
                        setInnerState(() {});
                      },
                      onDayTap: (DateTime date) {
                        tempDate = DateTime(date.year, date.month, date.day);
                        setInnerState(() {});
                      },
                      onCancel: () => Navigator.pop(context),
                      onConfirm: () {
                        if (tempDate != null) {
                          setState(() => _date = tempDate);
                        }
                        Navigator.pop(context);
                      },
                    );
                  },
            );
          },
        );
      },
    );
  }

  DaycareQuote? get _quote {
    final DaycareSettingsModel? settings = _settings;
    if (settings == null ||
        _plan == null ||
        _date == null ||
        _dropOff == null ||
        _pickUp == null) {
      return null;
    }
    final DateTime start = DaycareTimeHelper.combineDateAndTime(
      _date!,
      _dropOff!,
    );
    final DateTime end = DaycareTimeHelper.combineDateAndTime(_date!, _pickUp!);
    int addonAmount = 0;
    final int minutes = end.difference(start).inMinutes;
    for (final Map<String, dynamic> addon in _addons) {
      if (!_selectedAddonIds.contains((addon['id'] ?? '').toString())) {
        continue;
      }
      addonAmount += DaycarePricingService.instance.addonLineAmount(
        addon: addon,
        minutes: minutes,
        petCount: _petIds.isEmpty ? 1 : _petIds.length,
      );
    }
    return DaycarePricingService.instance.quote(
      settings: settings,
      plan: _plan!,
      startAt: start,
      endAt: end,
      petCount: _petIds.isEmpty ? 1 : _petIds.length,
      addonAmount: addonAmount,
      manualAdjust: _manualAdjust,
    );
  }

  Future<void> _addPet() async {
    final Map<String, dynamic>? created =
        await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => const AdminQuickCreatePetDialog(),
        );
    if (created == null || _member == null) {
      return;
    }
    final String userId =
        (_member!['userId'] ?? _member!['uid'] ?? _member!['id'] ?? '')
            .toString();
    final DocumentReference<Map<String, dynamic>> ref = FirebaseFirestore
        .instance
        .collection('user_profiles')
        .doc(userId)
        .collection('pets')
        .doc();
    await ref.set(created);
    await _loadPets(userId);
  }

  Future<void> _submit() async {
    final DaycareSettingsModel? settings = _settings;
    final Map<String, dynamic>? member = _member;
    if (settings == null ||
        member == null ||
        _plan == null ||
        _date == null ||
        _dropOff == null ||
        _pickUp == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請完整填寫臨托資料')));
      return;
    }
    if (_petIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇寵物')));
      return;
    }
    if (_policyRequired &&
        (_policySignMethod == null || _policySignMethod!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請記錄臨托條款簽署方式')));
      return;
    }
    final DateTime start = DaycareTimeHelper.combineDateAndTime(
      _date!,
      _dropOff!,
    );
    final DateTime end = DaycareTimeHelper.combineDateAndTime(_date!, _pickUp!);
    setState(() => _submitting = true);
    try {
      final List<Map<String, dynamic>> selectedAddons = _addons
          .where(
            (Map<String, dynamic> e) =>
                _selectedAddonIds.contains((e['id'] ?? '').toString()),
          )
          .toList();
      await DaycareFunctionService.instance.createBooking(<String, dynamic>{
        'shopId': widget.shopId,
        'source': 'admin',
        'userId': (member['userId'] ?? member['uid'] ?? member['id'] ?? '')
            .toString(),
        'customerName': (member['name'] ?? member['displayName'] ?? '')
            .toString(),
        'customerPhone': (member['phone'] ?? '').toString(),
        'scheduledStartAt': start.toIso8601String(),
        'scheduledEndAt': end.toIso8601String(),
        'petIds': _petIds.toList(),
        'pets': _pets
            .where((Map<String, dynamic> e) => _petIds.contains(e['id']))
            .toList(),
        'daycarePlanId': _plan!.id,
        'addons': selectedAddons,
        'manualAdjust': _manualAdjust,
        'policyVersion': _policyVersion,
        'policyKind': PolicyApplicableService.daycare,
        'policySignMethod': _policyRequired
            ? (_policySignMethod ?? PolicySignMethods.staffWitness)
            : '',
        'requestId': 'admin_dc_${DateTime.now().millisecondsSinceEpoch}',
      });
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('臨托訂單已建立')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DaycareSettingsModel? settings = _settings;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final List<String> slots = DaycareTimeHelper.slots(
      start: settings.earliestDropOff,
      end: settings.latestPickUp,
      stepMinutes: settings.slotMinutes,
    );
    final DaycareQuote? quote = _quote;
    return Scaffold(
      appBar: AppBar(title: const Text('新增臨托訂單')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            '選擇會員',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _keyword,
            decoration: const InputDecoration(
              labelText: '搜尋會員姓名或電話',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) => setState(() => _keywordText = value),
          ),
          AdminMemberSearchSection(
            shopId: widget.shopId,
            keyword: _keywordText,
            onSelectMember: (String userId, Map<String, dynamic> data) {
              setState(() {
                _member = <String, dynamic>{
                  'id': userId,
                  'userId': userId,
                  ...data,
                };
              });
              _loadPets(userId);
            },
          ),
          if (_member != null) AdminSelectedMemberCard(member: _member!),
          const SizedBox(height: 16),
          const Text(
            '臨托日期與時間',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          DaycareDateCard(date: _date, onTap: _openCalendar),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _dropOff,
            decoration: const InputDecoration(
              labelText: '送達時間',
              border: OutlineInputBorder(),
            ),
            items: slots
                .map(
                  (String t) =>
                      DropdownMenuItem<String>(value: t, child: Text(t)),
                )
                .toList(),
            onChanged: (String? value) => setState(() => _dropOff = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _pickUp,
            decoration: const InputDecoration(
              labelText: '預計接回時間',
              border: OutlineInputBorder(),
            ),
            items: slots
                .map(
                  (String t) =>
                      DropdownMenuItem<String>(value: t, child: Text(t)),
                )
                .toList(),
            onChanged: (String? value) => setState(() => _pickUp = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '選擇寵物',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (_member != null)
                TextButton.icon(
                  onPressed: _addPet,
                  icon: const Icon(Icons.add),
                  label: const Text('新增寵物'),
                ),
            ],
          ),
          ..._pets.map((Map<String, dynamic> pet) {
            final String id = (pet['id'] ?? '').toString();
            return CheckboxListTile(
              title: Text((pet['name'] ?? '寵物').toString()),
              subtitle: Text((pet['breed'] ?? '').toString()),
              value: _petIds.contains(id),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _petIds.add(id);
                  } else {
                    _petIds.remove(id);
                  }
                });
              },
            );
          }),
          const SizedBox(height: 8),
          const Text(
            '臨托方案',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          ...settings.enabledPlans.map((DaycarePlanModel plan) {
            final bool selected = _plan?.id == plan.id;
            return Card(
              color: selected ? Colors.blue.shade50 : null,
              child: ListTile(
                title: Text(plan.name),
                subtitle: Text(
                  '${DaycarePlanTypes.label(plan.type)} ｜ \$${plan.basePrice}',
                ),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
                onTap: () => setState(() => _plan = plan),
              ),
            );
          }),
          if (_addons.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              '加值服務',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            ..._addons.map((Map<String, dynamic> addon) {
              final String id = (addon['id'] ?? '').toString();
              return CheckboxListTile(
                value: _selectedAddonIds.contains(id),
                title: Text((addon['name'] ?? '').toString()),
                subtitle: Text('\$${addon['price'] ?? 0}'),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedAddonIds.add(id);
                    } else {
                      _selectedAddonIds.remove(id);
                    }
                  });
                },
              );
            }),
          ],
          if (_policyRequired) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              '臨托條款',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '目前臨托條款版本 v$_policyVersion。店員代客建立時必須記錄簽署方式，不可只勾選同意。',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            PolicySignMethodField(
              value: _policySignMethod,
              onChanged: (String value) =>
                  setState(() => _policySignMethod = value),
            ),
          ],
          if (quote != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '費用明細',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('臨托方案：\$${quote.baseAmount}'),
                    if (quote.extraPetAmount > 0)
                      Text('多寵物加價：\$${quote.extraPetAmount}'),
                    if (quote.addonAmount > 0)
                      Text('加值服務：\$${quote.addonAmount}'),
                    if (quote.manualAdjust != 0)
                      Text('店家手動調整：\$${quote.manualAdjust}'),
                    const Divider(),
                    Text(
                      '合計 \$${quote.totalAmount}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (quote.depositAmount > 0)
                      Text('訂金 \$${quote.depositAmount}'),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '建立中…' : '建立臨托訂單'),
          ),
        ],
      ),
    );
  }
}
