// lib/features/shop/pages/shop_daycare_booking_page.dart
// 🐾 前台安親預約：沿用住宿日期表、寵物卡、加值與價格摘要

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_fee_line_item.dart';
import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
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
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_daycare_booking_confirm_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_pet_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_date_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_offer_card.dart';
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
  DaycareDateOverrideModel? _dateOverride;
  int _step = 1;

  @override
  void initState() {
    super.initState();
    _loadExtras();
    _loadBlacklist();
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
      if (_roomOptions.isNotEmpty || _selectedRoomTypeId != null) {
        setState(() {
          _roomOptions = const <DaycareRoomTypeOption>[];
          _selectedRoomTypeId = null;
        });
      }
      return;
    }
    final int dailyMax = DaycareDateAvailability.dailyMaxPets(
      settings: widget.settings,
      override: _dateOverride,
    );
    final List<DaycareRoomTypeOption> options =
        await DaycareRoomTypeCatalog.load(
          shopId: widget.shopId,
          settings: widget.settings,
          petCount: _selectedPetIds.length,
          dailyRemaining: dailyMax <= 0 ? null : _remaining,
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
    final int dailyMax = DaycareDateAvailability.dailyMaxPets(
      settings: widget.settings,
      override: _dateOverride,
    );
    if (!widget.settings.showRemainingSlots || dailyMax <= 0) {
      if (mounted) {
        setState(() => _remaining = dailyMax <= 0 ? -1 : _remaining);
      }
      await _refreshRoomOptions();
      await _loadExtras();
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
    final int dailyMax = DaycareDateAvailability.dailyMaxPets(
      settings: widget.settings,
      override: _dateOverride,
    );
    if (dailyMax > 0) {
      final int petsLeft = await DaycareOccupancyService.instance.remainingPets(
        shopId: widget.shopId,
        serviceDate: _date!,
        dailyMaxPets: dailyMax,
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
      return '請選擇送達與接回時間';
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
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final HomeThemeModel theme = HomeBannerService.instance.themeFromShop(
      widget.shop,
    );
    final List<String> slots = DaycareTimeHelper.slots(
      start: _dayHours.earliestDropOff,
      end: _dayHours.latestPickUp,
      stepMinutes: widget.settings.slotMinutes,
    );
    final DaycareQuote? quote = _quote;
    final String stepHint = _stepHint;
    final bool canAdvance = stepHint.isEmpty && !_submitting && !_isBlacklisted;
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.settings.serviceName.isEmpty
              ? '安親預約'
              : widget.settings.serviceName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isBlacklisted
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.block, size: 48, color: theme.primaryColor),
                    const SizedBox(height: 12),
                    Text(
                      '目前無法使用預約功能',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '目前無法使用線上預約服務。\n如需協助，請聯繫店家確認。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textColor),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: <Widget>[
                BookingStepIndicator(
                  currentStep: _step,
                  theme: theme,
                  labels: const <String>['日期與寵物', '方案與服務', '費用與確認'],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: <Widget>[
                      if (_step == 1) ..._stepDatePets(theme, slots),
                      if (_step == 2) ..._stepPlanAddons(theme),
                      if (_step == 3) ..._stepFees(theme, quote),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isBlacklisted
          ? null
          : BookingStickyBar(
              theme: theme,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (stepHint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        stepHint,
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      if (_step > 1)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _step -= 1),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.textColor,
                              side: BorderSide(color: theme.cardBorderColor),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('上一步'),
                          ),
                        ),
                      if (_step > 1) const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: BookingPrimaryButton(
                          theme: theme,
                          label: _submitting
                              ? '處理中...'
                              : (_step < 3 ? '下一步' : '下一步：填寫資料'),
                          onPressed: canAdvance
                              ? () {
                                  if (_step < 3) {
                                    setState(() => _step += 1);
                                    return;
                                  }
                                  _submit();
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  String get _stepHint {
    if (_step == 1) {
      if (_date == null) {
        return '請先選擇安親日期';
      }
      if (_dropOff == null || _pickUp == null) {
        return '請選擇送達與接回時間';
      }
      if (_startAt != null && _endAt != null && !_startAt!.isBefore(_endAt!)) {
        return '接回時間必須晚於送達時間';
      }
      if (_selectedPetIds.isEmpty) {
        return '請先選擇安親寵物';
      }
      return '';
    }
    if (_step == 2) {
      if (widget.settings.isRoomBased && _selectedRoomTypeId == null) {
        return '請選擇安親房型';
      }
      if (!widget.settings.isRoomBased && _plan == null) {
        return '請選擇安親方案';
      }
      return '';
    }
    return _submitHint;
  }

  List<Widget> _stepDatePets(HomeThemeModel theme, List<String> slots) {
    return <Widget>[
      Text(
        (widget.shop['name'] ?? '').toString(),
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: theme.textColor,
        ),
      ),
      const SizedBox(height: 8),
      Text('請先選擇安親日期，再安排送達與接回時間', style: TextStyle(color: theme.textColor)),
      if (widget.settings.intro.isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        Text(widget.settings.intro, style: TextStyle(color: theme.textColor)),
      ],
      const SizedBox(height: 16),
      BookingThemedCard(
        theme: theme,
        child: DaycareDateCard(date: _date, onTap: _openCalendar),
      ),
      if (widget.settings.showRemainingSlots && _date != null) ...<Widget>[
        const SizedBox(height: 8),
        Text(
          DaycareDateAvailability.dailyMaxPets(
                    settings: widget.settings,
                    override: _dateOverride,
                  ) <=
                  0
              ? '當日名額：不限量'
              : ((_remaining == null || _remaining! < 0)
                    ? '當日剩餘名額：計算中'
                    : '當日剩餘名額：$_remaining'),
          style: TextStyle(color: theme.textColor),
        ),
      ],
      const SizedBox(height: 16),
      BookingThemedCard(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '請選擇預計送達與接回寵物的時間。',
              style: TextStyle(color: theme.textColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _dropOff,
              decoration: InputDecoration(
                labelText: '送達時間',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
              decoration: InputDecoration(
                labelText: '接回時間',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
          ],
        ),
      ),
      const SizedBox(height: 16),
      BookingThemedCard(
        theme: theme,
        child: BookingPetSection(
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
      ),
    ];
  }

  List<Widget> _stepPlanAddons(HomeThemeModel theme) {
    final List<DaycarePlanModel> plans =
        List<DaycarePlanModel>.from(widget.settings.plans)..sort(
          (DaycarePlanModel a, DaycarePlanModel b) =>
              a.sortOrder.compareTo(b.sortOrder),
        );
    return <Widget>[
      if (!widget.settings.isRoomBased) ...<Widget>[
        Text(
          '選擇安親方案',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        if (plans.isEmpty) const Text('目前沒有可預約的安親方案'),
        ...plans.map((DaycarePlanModel plan) {
          final bool selected = _plan?.id == plan.id;
          return DaycareOfferCard(
            theme: theme,
            title: plan.name,
            lines: plan.customerSummaryLines,
            selected: selected,
            enabled: plan.enabled,
            blockedReason: plan.enabled ? null : '方案未啟用',
            onTap: () => setState(() => _plan = plan),
          );
        }),
      ],
      if (widget.settings.isRoomBased) ...<Widget>[
        Text(
          '選擇安親房型',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _selectedPetIds.isEmpty ? '請先選擇安親寵物，再確認房型。' : '實際房間由店家確認訂單後分配。',
          style: TextStyle(
            fontSize: 13,
            color: theme.textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        if (_roomOptions.isEmpty) const Text('尚未設定安親房型'),
        ..._roomOptions.map((DaycareRoomTypeOption option) {
          final bool petsReady = _selectedPetIds.isNotEmpty;
          final bool selected =
              petsReady && _selectedRoomTypeId == option.roomTypeId;
          final bool canPick = petsReady && option.selectable;
          final DaycareRoomTypeSetting setting = option.setting;
          return DaycareOfferCard(
            theme: theme,
            title: option.name,
            lines: DaycarePlanModel.offerDetailLines(
              includedMinutes: setting.includedMinutes,
              basePrice: setting.basePrice,
              extraBillingMinutes: setting.extraBillingMinutes,
              extraBillingPrice: setting.extraBillingPrice,
              maxBaseCharge: setting.maxBaseCharge,
              extraPetPrice: setting.extraPetPrice,
              maxPets: setting.maxPets,
              enabled: setting.enabled,
            ),
            selected: selected,
            enabled: canPick,
            blockedReason: petsReady && !canPick
                ? (option.blockedReason ?? '目前不可選')
                : (setting.enabled ? null : '方案未啟用'),
            onTap: () {
              if (!petsReady) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('請先選擇安親寵物')));
                return;
              }
              setState(() => _selectedRoomTypeId = option.roomTypeId);
            },
          );
        }),
      ],
      if (_addons.isNotEmpty) ...<Widget>[
        const SizedBox(height: 16),
        Text(
          '加值服務',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        ..._addons.map((Map<String, dynamic> addon) {
          final String id = (addon['id'] ?? '').toString();
          final bool selected = _selectedAddonIds.contains(id);
          return CheckboxListTile(
            value: selected,
            title: Text(DaycareAddonCatalog.displayName(addon)),
            subtitle: Text(
              '${DaycarePlanModel.moneyLabel((addon['price'] as num?)?.toInt() ?? 0)}　${DaycareAddonCatalog.chargeLabel(addon)}',
            ),
            activeColor: theme.primaryColor,
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
    ];
  }

  List<Widget> _stepFees(HomeThemeModel theme, DaycareQuote? quote) {
    if (quote == null) {
      return <Widget>[
        Text('請先完成日期、時間、寵物與方案選擇。', style: TextStyle(color: theme.textColor)),
      ];
    }
    final List<BookingFeeLineItem> lines = DaycarePricingService.instance
        .customerFeeLines(
          quote: quote,
          primaryLabel: _plan?.name ?? '安親方案',
          depositType: widget.settings.depositType,
          addonLines: _addons
              .where(
                (Map<String, dynamic> e) =>
                    _selectedAddonIds.contains((e['id'] ?? '').toString()),
              )
              .map(
                (Map<String, dynamic> addon) => BookingFeeLineItem(
                  label: DaycareAddonCatalog.displayName(addon),
                  amount: DaycarePricingService.instance.addonLineAmount(
                    addon: addon,
                    minutes: quote.durationMinutes,
                    petCount: _selectedPetIds.isEmpty
                        ? 1
                        : _selectedPetIds.length,
                  ),
                ),
              )
              .toList(),
        );
    return <Widget>[
      BookingThemedCard(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '費用明細',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 12),
            ...lines.map(
              (BookingFeeLineItem line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        line.label,
                        style: TextStyle(
                          color: theme.textColor,
                          fontWeight:
                              line.kind == BookingFeeLineKind.total ||
                                  line.kind == BookingFeeLineKind.payable
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      line.amount < 0
                          ? '-NT\$${line.amount.abs()}'
                          : 'NT\$${line.amount}',
                      style: TextStyle(
                        color: theme.textColor,
                        fontWeight:
                            line.kind == BookingFeeLineKind.total ||
                                line.kind == BookingFeeLineKind.payable
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '此為依預約時間計算的預估金額，實際金額將於接回時結算。',
              style: TextStyle(
                fontSize: 12,
                color: theme.textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
