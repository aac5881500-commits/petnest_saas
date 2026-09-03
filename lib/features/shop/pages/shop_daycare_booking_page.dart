// lib/features/shop/pages/shop_daycare_booking_page.dart
// 🐾 前台安親預約：沿用住宿日期表、寵物卡、加值、條款簽署與價格摘要

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_booking_validator.dart';
import 'package:petnest_saas/core/services/daycare_calendar_helper.dart';
import 'package:petnest_saas/core/services/daycare_date_availability.dart';
import 'package:petnest_saas/core/services/daycare_date_override_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_room_type_option.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_daycare_booking_confirm_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_pet_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_date_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';

class ShopDaycareBookingPage extends StatefulWidget {
  const ShopDaycareBookingPage({
    super.key,
    required this.shopId,
    required this.settings,
    required this.shop,
  });

  final String shopId;
  final DaycareSettingsModel settings;
  final Map<String, dynamic> shop;

  @override
  State<ShopDaycareBookingPage> createState() => _ShopDaycareBookingPageState();
}

class _ShopDaycareBookingPageState extends State<ShopDaycareBookingPage> {
  DateTime? _date;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Future<FrontCalendarPayload>? _calendarFuture;
  String? _dropOff;
  String? _pickUp;
  final List<String> _selectedPetIds = <String>[];
  List<Map<String, dynamic>> _pets = <Map<String, dynamic>>[];
  DaycarePlanModel? _plan;
  String? _selectedRoomTypeId;
  List<DaycareRoomTypeOption> _roomOptions = const <DaycareRoomTypeOption>[];
  List<Map<String, dynamic>> _addons = <Map<String, dynamic>>[];
  final Set<String> _selectedAddonIds = <String>{};
  bool _submitting = false;
  int? _remaining;
  bool _isBlacklisted = false;
  bool _policyRequired = false;
  bool _policyAccepted = false;
  int _policyVersion = 0;
  String _policyTitle = '安親須知';
  DaycareDateOverrideModel? _dateOverride;

  @override
  void initState() {
    super.initState();
    _loadExtras();
    _loadBlacklist();
    _refreshPolicy();
    _refreshRoomOptions();
    if (!widget.settings.isRoomBased &&
        widget.settings.customerPlans.length == 1) {
      _plan = widget.settings.customerPlans.first;
    }
  }

  @override
  void didUpdateWidget(covariant ShopDaycareBookingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.allowedAddonIds != widget.settings.allowedAddonIds) {
      _loadExtras();
    }
    if (oldWidget.settings.roomTypes != widget.settings.roomTypes ||
        oldWidget.settings.pricingMode != widget.settings.pricingMode) {
      _refreshRoomOptions();
    }
  }

  Future<void> _loadBlacklist() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> member =
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('members')
            .doc(user.uid)
            .get();
    if (!mounted) {
      return;
    }
    setState(() {
      _isBlacklisted = member.data()?['blacklisted'] == true;
    });
  }

  Future<void> _refreshPolicy() async {
    final Map<String, dynamic>? policy = await ShopPolicyService.instance
        .getCheckinPolicy(widget.shopId);
    if (!mounted) {
      return;
    }
    if (policy == null) {
      setState(() {
        _policyRequired = false;
        _policyAccepted = true;
        _policyVersion = 0;
      });
      return;
    }
    final Map<String, dynamic> filtered = ShopPolicyService.instance
        .filterPolicyForService(
          policy: policy,
          serviceType: PolicyApplicableService.daycare,
        );
    final bool required = ShopPolicyService.instance.policyRequiresSignature(
      filteredPolicy: filtered,
    );
    final User? user = FirebaseAuth.instance.currentUser;
    bool accepted = !required;
    if (required && user != null) {
      accepted = await ShopPolicyService.instance.hasAcceptedPolicy(
        shopId: widget.shopId,
        userId: user.uid,
        serviceType: PolicyApplicableService.daycare,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _policyRequired = required;
      _policyAccepted = accepted;
      _policyVersion = (filtered['version'] as num?)?.toInt() ?? 0;
      _policyTitle = required ? '安親須知' : '安親須知';
    });
  }

  Future<void> _loadExtras() async {
    final DocumentSnapshot<Map<String, dynamic>> addonSnap =
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('addons')
            .doc('main')
            .get();
    final List<Map<String, dynamic>> addons =
        DaycareAddonCatalog.allowedForDaycare(
          doc: addonSnap.data(),
          allowedAddonIds: widget.settings.allowedAddonIds,
          serviceDate: _date,
          petCount: _selectedPetIds.isEmpty ? 1 : _selectedPetIds.length,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _addons = addons;
      _selectedAddonIds.removeWhere(
        (String id) =>
            !addons.any((Map<String, dynamic> e) => e['id'].toString() == id),
      );
    });
  }

  Future<void> _refreshRoomOptions() async {
    if (!widget.settings.isRoomBased) {
      return;
    }
    final List<DaycareRoomTypeOption> options =
        await DaycareRoomTypeCatalog.load(
          shopId: widget.shopId,
          settings: widget.settings,
          petCount: _selectedPetIds.length,
          dailyRemaining: _remaining,
          startAt: _startAt,
          endAt: _endAt,
        );
    if (!mounted) {
      return;
    }
    final List<DaycareRoomTypeOption> selectable = options
        .where((DaycareRoomTypeOption e) => e.selectable)
        .toList();
    String? nextId = _selectedRoomTypeId;
    if (selectable.length == 1) {
      nextId = selectable.first.roomTypeId;
    } else if (nextId != null &&
        selectable.every((DaycareRoomTypeOption e) => e.roomTypeId != nextId)) {
      nextId = null;
    }
    setState(() {
      _roomOptions = options;
      _selectedRoomTypeId = nextId;
    });
  }

  Future<void> _refreshRemaining() async {
    if (_date == null) {
      return;
    }
    int? left = _remaining;
    if (widget.settings.showRemainingSlots) {
      left = await DaycareOccupancyService.instance.remainingPets(
        shopId: widget.shopId,
        serviceDate: _date!,
        dailyMaxPets: DaycareDateAvailability.dailyMaxPets(
          settings: widget.settings,
          override: _dateOverride,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _remaining = left);
    }
    await _refreshRoomOptions();
    await _loadExtras();
  }

  DateTime? get _startAt {
    if (_date == null || _dropOff == null) {
      return null;
    }
    return DaycareTimeHelper.combineDateAndTime(_date!, _dropOff!);
  }

  DateTime? get _endAt {
    if (_date == null || _pickUp == null) {
      return null;
    }
    return DaycareTimeHelper.combineDateAndTime(_date!, _pickUp!);
  }

  DaycareQuote? get _quote {
    if (_startAt == null || _endAt == null) {
      return null;
    }
    if (!widget.settings.isRoomBased && _plan == null) {
      return null;
    }
    int addonAmount = 0;
    final int minutes = _endAt!.difference(_startAt!).inMinutes;
    final int petCount = _selectedPetIds.isEmpty ? 1 : _selectedPetIds.length;
    for (final Map<String, dynamic> addon in _addons) {
      if (!_selectedAddonIds.contains((addon['id'] ?? '').toString())) {
        continue;
      }
      addonAmount += DaycarePricingService.instance.addonLineAmount(
        addon: addon,
        minutes: minutes,
        petCount: petCount,
      );
    }
    if (widget.settings.isRoomBased) {
      if (_selectedRoomTypeId == null) {
        return null;
      }
      final DaycareRoomTypeSetting? roomSetting = widget.settings
          .roomTypeSetting(_selectedRoomTypeId!);
      if (roomSetting == null || !roomSetting.enabled) {
        return null;
      }
      final DaycareRoomQuote roomQuote = DaycarePricingService.instance
          .quoteRoom(
            roomSetting: roomSetting,
            startAt: _startAt!,
            endAt: _endAt!,
            petCount: petCount,
          );
      return DaycarePricingService.instance.quoteFromRoom(
        settings: widget.settings,
        room: roomQuote,
        addonAmount: addonAmount,
        overtimeAmount: DaycarePricingService.instance.estimatedLatePickupFee(
          settings: widget.settings,
          roomSetting: roomSetting,
          endAt: _endAt!,
        ),
      );
    }
    return DaycarePricingService.instance.quote(
      settings: widget.settings,
      plan: _plan!,
      startAt: _startAt!,
      endAt: _endAt!,
      petCount: petCount,
      addonAmount: addonAmount,
    );
  }

  DaycareDayHours get _dayHours {
    return DaycareDateAvailability.hours(
      settings: widget.settings,
      override: _dateOverride,
    );
  }

  Future<void> _loadDateOverride() async {
    if (_date == null) {
      setState(() => _dateOverride = null);
      return;
    }
    final DaycareDateOverrideModel? override = await DaycareDateOverrideService
        .instance
        .get(shopId: widget.shopId, date: _date!);
    if (!mounted) {
      return;
    }
    setState(() => _dateOverride = override);
    _refreshRemaining();
  }

  Future<void> _openCalendar() async {
    final DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final int maxDays = _toInt(
      widget.shop['maxAdvanceBookingDays'],
      fallback: 30,
    );
    DateTime? tempDate = _date;
    final DateTime monthStart = DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      1,
    );
    final DateTime monthEnd = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + 1,
      0,
    );
    _calendarFuture = DaycareCalendarHelper.buildPayload(
      shopId: widget.shopId,
      shop: widget.shop,
      settings: widget.settings,
      firstDate: monthStart,
      lastDate: monthEnd,
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
                            shop: widget.shop,
                            settings: widget.settings,
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
                          _loadDateOverride();
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

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _openPolicy() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => LoginPage(redirectShopId: widget.shopId),
        ),
      );
      return;
    }
    final bool? accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ShopPolicyViewPage(
          shopId: widget.shopId,
          theme: HomeThemeModel.classicDefault,
          serviceType: PolicyApplicableService.daycare,
        ),
      ),
    );
    if (accepted == true) {
      await _refreshPolicy();
    }
  }

  Future<void> _submit() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => LoginPage(redirectShopId: widget.shopId),
        ),
      );
      return;
    }
    if (_isBlacklisted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前無法使用線上預約服務')));
      return;
    }
    if (_date == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇安親日期')));
      return;
    }
    if (_date == null || _startAt == null || _endAt == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請完整選擇時間')));
      return;
    }
    if (widget.settings.isRoomBased) {
      if (_selectedRoomTypeId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('請選擇安親房型')));
        return;
      }
    } else if (_plan == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇安親方案')));
      return;
    }
    final Map<String, dynamic>? liveShop = await ShopService.instance.getShop(
      widget.shopId,
    );
    final DaycareSettingsModel liveSettings = await DaycareSettingsService
        .instance
        .get(widget.shopId);
    if (!DaycareSettingsService.instance.isEnabledForShop(
      shop: liveShop,
      settings: liveSettings,
    )) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此店家尚未開放安親')));
      return;
    }
    if (liveSettings.isRoomBased) {
      await _refreshRoomOptions();
      final bool roomOk = _roomOptions.any(
        (DaycareRoomTypeOption e) =>
            e.selectable && e.roomTypeId == _selectedRoomTypeId,
      );
      if (!roomOk) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(DaycareRoomTypeCatalog.emptyReason(_roomOptions)),
          ),
        );
        return;
      }
    }
    final DaycareValidationResult schedule =
        DaycareBookingValidator.validateSchedule(
          settings: widget.settings,
          startAt: _startAt!,
          endAt: _endAt!,
          dateOverride: _dateOverride,
        );
    if (!schedule.isOk) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(schedule.error!)));
      return;
    }
    if (_selectedPetIds.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇寵物')));
      return;
    }
    final DaycareValidationResult addonCheck =
        DaycareBookingValidator.validateAllowedAddons(
          settings: liveSettings,
          addonIds: _selectedAddonIds.toList(),
        );
    if (!addonCheck.isOk) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(addonCheck.error!)));
      return;
    }
    final int petsLeft = await DaycareOccupancyService.instance.remainingPets(
      shopId: widget.shopId,
      serviceDate: _date!,
      dailyMaxPets: DaycareDateAvailability.dailyMaxPets(
        settings: widget.settings,
        override: _dateOverride,
      ),
    );
    if (petsLeft < _selectedPetIds.length) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('當日安親名額不足')));
      return;
    }
    await _refreshPolicy();
    if (_policyRequired && !_policyAccepted) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先閱讀並同意安親條款')));
      return;
    }
    final bool conflict = await DaycareOccupancyService.instance.hasPetConflict(
      shopId: widget.shopId,
      petIds: _selectedPetIds,
      startAt: _startAt!,
      endAt: _endAt!,
    );
    if (conflict) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此寵物在相同時段已有預約')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final List<Map<String, dynamic>> selectedAddons = _addons
          .where(
            (Map<String, dynamic> e) =>
                _selectedAddonIds.contains((e['id'] ?? '').toString()),
          )
          .toList();
      if (!mounted) {
        return;
      }
      final String roomName = _roomOptions
          .where(
            (DaycareRoomTypeOption e) => e.roomTypeId == _selectedRoomTypeId,
          )
          .map((DaycareRoomTypeOption e) => e.name)
          .fold<String>('', (String prev, String name) => name);
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ShopDaycareBookingConfirmPage(
            shopId: widget.shopId,
            shop: liveShop ?? widget.shop,
            settings: liveSettings,
            startAt: _startAt!,
            endAt: _endAt!,
            plan: _plan ?? const DaycarePlanModel(id: '', name: '安親房型'),
            requestedRoomTypeId: _selectedRoomTypeId ?? '',
            requestedRoomTypeName: roomName,
            selectedPetIds: List<String>.from(_selectedPetIds),
            pets: _pets,
            addons: selectedAddons,
            policyVersion: _policyVersion,
            policyTitle: _policyTitle,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String get _submitHint {
    if (_date == null) {
      return '請先選擇安親日期';
    }
    if (_dropOff == null || _pickUp == null) {
      return '請選擇預計送達與接回時間';
    }
    if (_selectedPetIds.isEmpty) {
      return '請先選擇安親寵物';
    }
    if (widget.settings.isRoomBased && _selectedRoomTypeId == null) {
      return '請選擇安親房型';
    }
    if (!widget.settings.isRoomBased && _plan == null) {
      return '請選擇安親方案';
    }
    if (_policyRequired && !_policyAccepted) {
      return '請先閱讀並同意安親條款';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final List<String> slots = DaycareTimeHelper.slots(
      start: _dayHours.earliestDropOff,
      end: _dayHours.latestPickUp,
      stepMinutes: widget.settings.slotMinutes,
    );
    final DaycareQuote? quote = _quote;
    final bool canSubmit =
        !_submitting &&
        !_isBlacklisted &&
        _date != null &&
        _startAt != null &&
        _endAt != null &&
        (widget.settings.isRoomBased || _plan != null) &&
        (!widget.settings.isRoomBased ||
            (_selectedRoomTypeId != null && _selectedPetIds.isNotEmpty)) &&
        _selectedPetIds.isNotEmpty &&
        (!_policyRequired || _policyAccepted);
    final String submitHint = _submitHint;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.settings.serviceName.isEmpty
              ? '安親預約'
              : widget.settings.serviceName,
        ),
      ),
      body: _isBlacklisted
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.block, size: 48, color: Colors.red.shade700),
                    const SizedBox(height: 12),
                    const Text(
                      '目前無法使用預約功能',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '目前無法使用線上預約服務。\n如需協助，請聯繫店家確認。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text(
                  (widget.shop['name'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('請先選擇安親日期，再安排送達與接回時間'),
                if (widget.settings.intro.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(widget.settings.intro),
                ],
                const SizedBox(height: 16),
                DaycareDateCard(date: _date, onTap: _openCalendar),
                if (_remaining != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('當日剩餘名額：$_remaining'),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _dropOff,
                  decoration: const InputDecoration(
                    labelText: '預計送達時間',
                    border: OutlineInputBorder(),
                  ),
                  items: slots
                      .map(
                        (String item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    setState(() => _dropOff = value);
                    _refreshRoomOptions();
                  },
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
                        (String item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    setState(() => _pickUp = value);
                    _refreshRoomOptions();
                  },
                ),
                const SizedBox(height: 20),
                BookingPetSection(
                  title: '選擇安親寵物（已選 ${_selectedPetIds.length} 隻）',
                  selectedPetIds: _selectedPetIds,
                  onPetsLoaded: (List<Map<String, dynamic>> pets) {
                    _pets = pets;
                  },
                  onTogglePet: (String petId, bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedPetIds.add(petId);
                      } else {
                        _selectedPetIds.remove(petId);
                      }
                    });
                    _refreshRoomOptions();
                    _loadExtras();
                  },
                ),
                const SizedBox(height: 20),
                if (!widget.settings.isRoomBased) ...<Widget>[
                  const Text(
                    '安親方案',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (widget.settings.customerPlans.isEmpty)
                    const Text('目前沒有可預約的安親方案'),
                  ...widget.settings.customerPlans.map((DaycarePlanModel plan) {
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
                ],
                if (widget.settings.isRoomBased) ...<Widget>[
                  const Text(
                    '安親房型／計價方案',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedPetIds.isEmpty
                        ? '請先選擇安親寵物，再確認房型。'
                        : '實際房間由店家確認訂單後分配。',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 8),
                  if (_roomOptions.isEmpty) const Text('尚未設定安親房型'),
                  ..._roomOptions.map((DaycareRoomTypeOption option) {
                    final bool petsReady = _selectedPetIds.isNotEmpty;
                    final bool selected =
                        petsReady && _selectedRoomTypeId == option.roomTypeId;
                    final bool canPick = petsReady && option.selectable;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: selected
                            ? const Color(0xFFFFF4EA)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            if (!petsReady) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('請先選擇安親寵物')),
                              );
                              return;
                            }
                            if (!option.selectable) {
                              return;
                            }
                            setState(
                              () => _selectedRoomTypeId = option.roomTypeId,
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFE8A87C)
                                    : const Color(0xFFF0E0CC),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        option.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF3A2A1A),
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFFB86B18),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  option.billingLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF3A2A1A),
                                  ),
                                ),
                                if (option.extraPetLabel.isNotEmpty)
                                  Text(
                                    option.extraPetLabel,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                Text(
                                  option.capacitySummary,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                if (option.overtimeSummary.isNotEmpty)
                                  Text(
                                    option.overtimeSummary,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                if (petsReady && !canPick)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      option.blockedReason ?? '目前不可選',
                                      style: const TextStyle(
                                        color: Color(0xFFC45C26),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                if (option.estimateAmount > 0 && canPick)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '預估 NT\$${option.estimateAmount}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                if (_addons.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  const Text(
                    '加值服務',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ..._addons.map((Map<String, dynamic> addon) {
                    final String id = (addon['id'] ?? '').toString();
                    final bool selected = _selectedAddonIds.contains(id);
                    return CheckboxListTile(
                      value: selected,
                      title: Text(DaycareAddonCatalog.displayName(addon)),
                      subtitle: Text(
                        '\$${addon['price'] ?? 0}　${DaycareAddonCatalog.chargeLabel(addon)}',
                      ),
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
                if (quote != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '費用摘要',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('基本費：\$${quote.baseAmount}'),
                          if (quote.extraPetAmount > 0)
                            Text('多寵加價：\$${quote.extraPetAmount}'),
                          if (quote.overtimeAmount > 0)
                            Text('預估超時費：\$${quote.overtimeAmount}'),
                          ..._addons
                              .where(
                                (Map<String, dynamic> e) => _selectedAddonIds
                                    .contains((e['id'] ?? '').toString()),
                              )
                              .map((Map<String, dynamic> addon) {
                                final int amount = DaycarePricingService
                                    .instance
                                    .addonLineAmount(
                                      addon: addon,
                                      minutes: quote.durationMinutes,
                                      petCount: _selectedPetIds.isEmpty
                                          ? 1
                                          : _selectedPetIds.length,
                                    );
                                return Text(
                                  '${DaycareAddonCatalog.displayName(addon)}：\$$amount',
                                );
                              }),
                          if (quote.surchargeAmount > 0)
                            Text('特殊日期加價：\$${quote.surchargeAmount}'),
                          if (quote.discountAmount > 0)
                            Text('優惠折扣：-\$${quote.discountAmount}'),
                          if (quote.couponAmount > 0)
                            Text('優惠券：-\$${quote.couponAmount}'),
                          if (quote.pointAmount > 0)
                            Text('點數折抵：-\$${quote.pointAmount}'),
                          const Divider(),
                          Text(
                            widget.settings.isRoomBased
                                ? '預估總額 NT\$${quote.totalAmount}'
                                : '合計 \$${quote.totalAmount}',
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
                if (_policyRequired) ...<Widget>[
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        _policyAccepted
                            ? Icons.verified
                            : Icons.policy_outlined,
                        color: _policyAccepted ? Colors.green : null,
                      ),
                      title: Text(
                        _policyAccepted ? '已閱讀並同意安親條款' : '請閱讀並同意安親條款',
                      ),
                      subtitle: Text('條款版本 v$_policyVersion'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openPolicy,
                    ),
                  ),
                ],
                const SizedBox(height: 88),
              ],
            ),
      bottomNavigationBar: _isBlacklisted
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!canSubmit && submitHint.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          submitHint,
                          style: const TextStyle(
                            color: Color(0xFFC45C26),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: canSubmit ? _submit : null,
                        child: Text(_submitting ? '處理中...' : '下一步：填寫資料'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
