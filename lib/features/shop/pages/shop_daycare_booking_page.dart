// 檔案名稱：lib/features/shop/pages/shop_daycare_booking_page.dart
// 功能說明：前台安親預約頁，負責日期、時段、寵物、方案與費用確認流程。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_fee_line_item.dart';
import 'package:petnest_saas/core/models/create_payment_request_model.dart';
import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_booking_validator.dart';
import 'package:petnest_saas/core/services/daycare_calendar_helper.dart';
import 'package:petnest_saas/core/services/daycare_callable_payload.dart';
import 'package:petnest_saas/core/services/daycare_coupon_helper.dart';
import 'package:petnest_saas/core/services/daycare_date_availability.dart';
import 'package:petnest_saas/core/services/daycare_date_override_service.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_room_type_option.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/payment_function_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/utils/callable_payload.dart';
import 'package:petnest_saas/core/utils/dropdown_value.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';
import 'package:petnest_saas/features/booking/pages/booking_success_page.dart';
import 'package:petnest_saas/features/payment/pages/ecpay_payment_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_member_coupon_ui.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_pet_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_booking_summary_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_offer_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';

class ShopDaycareBookingPage extends StatefulWidget {
  const ShopDaycareBookingPage({
    super.key,
    required this.shopId,
    required this.settings,
    required this.shop,
    this.debugPetsStream,
    this.debugLoggedIn,
    this.skipRemoteLoads = false,
    this.debugInitialStep = 1,
    this.debugDate,
    this.debugDropOff,
    this.debugPickUp,
    this.debugSelectedPetIds,
    this.debugPlan,
  });

  final String shopId;
  final DaycareSettingsModel settings;
  final Map<String, dynamic> shop;
  final Stream<List<Map<String, dynamic>>>? debugPetsStream;
  final bool? debugLoggedIn;

  /// 測試用：略過 Firestore 黑名單與加購載入。
  @visibleForTesting
  final bool skipRemoteLoads;
  @visibleForTesting
  final int debugInitialStep;
  @visibleForTesting
  final DateTime? debugDate;
  @visibleForTesting
  final String? debugDropOff;
  @visibleForTesting
  final String? debugPickUp;
  @visibleForTesting
  final List<String>? debugSelectedPetIds;
  @visibleForTesting
  final DaycarePlanModel? debugPlan;

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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _note = TextEditingController();
  List<MemberCouponModel> _coupons = const <MemberCouponModel>[];
  MemberCouponModel? _selectedCoupon;
  bool _loadingCoupons = false;
  String? _bookingRequestId;
  String? _bookingRequestSignature;

  @override
  void initState() {
    super.initState();
    if (!widget.skipRemoteLoads) {
      _loadExtras();
      _loadBlacklist();
      _loadMember();
      _loadCoupons();
    }
    _refreshRoomOptions();
    if (widget.debugDate != null) {
      _date = widget.debugDate;
    }
    if (widget.debugDropOff != null) {
      _dropOff = widget.debugDropOff;
    }
    if (widget.debugPickUp != null) {
      _pickUp = widget.debugPickUp;
    }
    if (widget.debugSelectedPetIds != null) {
      _selectedPetIds
        ..clear()
        ..addAll(widget.debugSelectedPetIds!);
    }
    _step = widget.debugInitialStep;
    if (widget.debugPlan != null) {
      _plan = widget.debugPlan;
    } else if (!widget.settings.isRoomBased &&
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

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadMember() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('user_profiles')
          .doc(user.uid)
          .get();
      final Map<String, dynamic>? data = doc.data();
      if (!mounted || data == null) {
        return;
      }
      _name.text = (data['name'] ?? user.displayName ?? '').toString();
      _phone.text = (data['phone'] ?? '').toString();
    } catch (_) {}
  }

  Future<void> _loadCoupons() async {
    if (widget.skipRemoteLoads || !widget.settings.allowCoupon) {
      if (mounted) {
        setState(() => _loadingCoupons = false);
      }
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _coupons = const <MemberCouponModel>[];
          _loadingCoupons = false;
        });
      }
      return;
    }
    setState(() => _loadingCoupons = true);
    try {
      final List<MemberCouponModel> all = await MemberCouponService.instance
          .getMemberCoupons(shopId: widget.shopId, userId: user.uid);
      final String roomTypeId = _selectedRoomTypeId ?? '';
      final List<MemberCouponModel> usable = all.where((
        MemberCouponModel coupon,
      ) {
        if (!DaycareCouponHelper.appliesToDaycare(coupon)) {
          return false;
        }
        if (coupon.roomTypeIds.isEmpty) {
          return true;
        }
        if (!widget.settings.isRoomBased || roomTypeId.isEmpty) {
          return false;
        }
        return DaycareCouponHelper.matchesRoomType(
          coupon: coupon,
          roomTypeId: roomTypeId,
        );
      }).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _coupons = usable;
        _loadingCoupons = false;
        if (_selectedCoupon != null &&
            usable.every(
              (MemberCouponModel e) => e.id != _selectedCoupon!.id,
            )) {
          _selectedCoupon = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCoupons = false);
      }
    }
  }

  Future<void> _loadBlacklist() async {
    try {
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
    } catch (_) {}
  }

  Future<void> _loadExtras() async {
    try {
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
    } catch (_) {}
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
    if (widget.skipRemoteLoads) {
      return;
    }
    try {
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
          selectable.every(
            (DaycareRoomTypeOption e) => e.roomTypeId != nextId,
          )) {
        nextId = null;
      }
      setState(() {
        _roomOptions = options;
        _selectedRoomTypeId = nextId;
      });
    } catch (_) {}
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
        couponAmount: _resolvedCouponAmount(
          planAmount: roomQuote.timeCharge,
          extraPetAmount: roomQuote.extraPetAmount,
          addonAmount: addonAmount,
        ),
      );
    }
    final DaycareQuote draft = DaycarePricingService.instance.quote(
      settings: widget.settings,
      plan: _plan!,
      startAt: _startAt!,
      endAt: _endAt!,
      petCount: petCount,
      addonAmount: addonAmount,
    );
    return DaycarePricingService.instance.quote(
      settings: widget.settings,
      plan: _plan!,
      startAt: _startAt!,
      endAt: _endAt!,
      petCount: petCount,
      addonAmount: addonAmount,
      couponAmount: _resolvedCouponAmount(
        planAmount: draft.timeCharge,
        extraPetAmount: draft.extraPetAmount,
        addonAmount: addonAmount,
      ),
    );
  }

  int _resolvedCouponAmount({
    required int planAmount,
    required int extraPetAmount,
    required int addonAmount,
  }) {
    if (_selectedCoupon == null) {
      return 0;
    }
    return DaycareCouponHelper.discountAmount(
      coupon: _selectedCoupon!,
      planAmount: planAmount,
      extraPetAmount: extraPetAmount,
      addonAmount: addonAmount,
      surchargeAmount: 0,
      campaignDiscountAmount: 0,
      selectedAddons: _selectedAddonMaps,
      specialDateAllowsCoupon: true,
    );
  }

  List<Map<String, dynamic>> get _selectedAddonMaps {
    return _addons
        .where(
          (Map<String, dynamic> e) =>
              _selectedAddonIds.contains((e['id'] ?? '').toString()),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _addonLines {
    if (_startAt == null || _endAt == null) {
      return const <Map<String, dynamic>>[];
    }
    final int minutes = _endAt!.difference(_startAt!).inMinutes;
    final int petCount = _selectedPetIds.isEmpty ? 1 : _selectedPetIds.length;
    return _selectedAddonMaps.map((Map<String, dynamic> addon) {
      final int amount = DaycarePricingService.instance.addonLineAmount(
        addon: addon,
        minutes: minutes,
        petCount: petCount,
      );
      return DaycareCallablePayload.addonSnapshot(addon, amount: amount);
    }).toList();
  }

  String get _primaryFeeLabel {
    if (widget.settings.isRoomBased) {
      final String name = _roomOptions
          .where(
            (DaycareRoomTypeOption e) => e.roomTypeId == _selectedRoomTypeId,
          )
          .map((DaycareRoomTypeOption e) => e.name)
          .fold<String>('', (String prev, String name) => name);
      return name.isEmpty ? '安親房型' : name;
    }
    return _plan?.name ?? '安親方案';
  }

  List<String> get _petNames {
    return _pets
        .where(
          (Map<String, dynamic> pet) => _selectedPetIds.contains(
            (pet['petId'] ?? pet['id'] ?? '').toString(),
          ),
        )
        .map((Map<String, dynamic> pet) => (pet['name'] ?? '').toString())
        .where((String name) => name.isNotEmpty)
        .toList();
  }

  List<BookingFeeLineItem> _feeLines(
    DaycareQuote quote, {
    bool includePayable = true,
  }) {
    return DaycarePricingService.instance.customerFeeLines(
      quote: quote,
      primaryLabel: _primaryFeeLabel,
      depositType: widget.settings.depositType,
      isRoomBased: widget.settings.isRoomBased,
      includePayable: includePayable,
      addonLines: _addonLines
          .map(
            (Map<String, dynamic> addon) => BookingFeeLineItem(
              label: DaycareAddonCatalog.displayName(addon),
              amount: (addon['amount'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
    );
  }

  DaycareDayHours get _dayHours {
    return DaycareDateAvailability.hours(
      settings: widget.settings,
      override: _dateOverride,
    );
  }

  String get _shopTitle {
    final String name = (widget.shop['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name;
    }
    if (widget.settings.serviceName.trim().isNotEmpty) {
      return widget.settings.serviceName.trim();
    }
    return '安親預約';
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Dialog(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Text('可預約日期載入失敗，請再試一次。'),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () {
                                  setState(() {
                                    _calendarFuture =
                                        DaycareCalendarHelper.buildPayload(
                                          shopId: widget.shopId,
                                          shop: widget.shop,
                                          settings: widget.settings,
                                          firstDate: monthStart,
                                          lastDate: monthEnd,
                                        );
                                  });
                                  setInnerState(() {});
                                },
                                child: const Text('重新載入'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return Dialog(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Text('目前沒有可顯示的安親日期。'),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('關閉'),
                              ),
                            ],
                          ),
                        ),
                      );
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
    if (!widget.skipRemoteLoads) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => LoginPage(redirectShopId: widget.shopId),
          ),
        );
        if (!mounted) {
          return;
        }
        user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return;
        }
        await _loadMember();
        await _loadCoupons();
      }
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
    if (widget.skipRemoteLoads) {
      await _openForm();
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
    await _openForm();
  }

  Future<void> _openForm() async {
    final DaycareQuote? quote = _quote;
    if (quote == null) {
      return;
    }
    if (!widget.skipRemoteLoads) {
      await _loadCoupons();
      if (!mounted) {
        return;
      }
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookingFormPage(
          shopId: widget.shopId,
          totalPrice: quote.totalAmount,
          originalTotal:
              quote.baseAmount +
              quote.extraPetAmount +
              quote.addonAmount +
              quote.surchargeAmount,
          discountAmount: quote.discountAmount + quote.couponAmount,
          discountCampaignName: _selectedCoupon?.name ?? '',
          roomPrice: quote.timeCharge + quote.extraPetAmount,
          addons: _addonLines,
          formKey: _formKey,
          customerNameController: _name,
          customerPhoneController: _phone,
          noteController: _note,
          serviceTypes: const <String>['daycare'],
          selectedServiceType: 'daycare',
          onServiceChanged: (_) {},
          onSubmit: () {},
          isSubmitting: _submitting,
          canSubmit: true,
          isBlacklisted: false,
          submitLabel: '確認訂單',
          feeSummaryTitle: '安親費用摘要',
          theme: HomeBannerService.instance.themeFromShop(widget.shop),
          termsServiceType: PolicyApplicableService.daycare,
          feeLineItems: _feeLines(quote, includePayable: false),
          skipRemoteLoads: widget.skipRemoteLoads,
          daycareDepositType: widget.settings.depositType,
          daycareDepositValue: quote.depositAmount,
          depositOverrideAmount:
              widget.settings.depositType == DaycareDepositTypes.fixed ||
                  widget.settings.depositType == DaycareDepositTypes.percent
              ? quote.depositAmount
              : null,
          onSubmitWithData: _submitOrder,
        ),
      ),
    );
  }

  Future<void> _submitOrder(
    String address,
    String emergencyName,
    String emergencyPhone,
    String relation,
    String emergencyAddress,
    String phone2,
    int depositAmount,
    String paymentMethod,
    String payAmountType,
    TermsConsentSnapshot termsConsent,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('請先登入後再送出預約');
    }
    final DaycareQuote? quote = _quote;
    if (quote == null || _startAt == null || _endAt == null) {
      throw Exception('請先完成安親日期與方案選擇');
    }
    final String signature = <String>[
      _startAt!.toIso8601String(),
      _endAt!.toIso8601String(),
      _selectedPetIds.join(','),
      _selectedRoomTypeId ?? '',
      _plan?.id ?? '',
      depositAmount.toString(),
      paymentMethod,
      payAmountType,
      _selectedCoupon?.id ?? '',
    ].join('||');
    setState(() {
      _submitting = true;
      if (_bookingRequestSignature != signature) {
        _bookingRequestId = FirebaseFirestore.instance
            .collection('bookings')
            .doc()
            .id;
        _bookingRequestSignature = signature;
      }
      _bookingRequestId ??= FirebaseFirestore.instance
          .collection('bookings')
          .doc()
          .id;
    });
    try {
      final String requestId = _bookingRequestId!;
      final List<Map<String, dynamic>> petSnaps = _pets
          .where(
            (Map<String, dynamic> pet) => _selectedPetIds.contains(
              (pet['petId'] ?? pet['id'] ?? '').toString(),
            ),
          )
          .map(DaycareCallablePayload.petSnapshot)
          .toList();
      final bool roomBased = widget.settings.isRoomBased;
      final DaycareRoomTypeSetting? roomSetting = roomBased
          ? widget.settings.roomTypeSetting(_selectedRoomTypeId ?? '')
          : null;
      final Map<String, dynamic> payload = <String, dynamic>{
        'shopId': widget.shopId,
        'requestId': requestId,
        'scheduledStartAt': _startAt!.toUtc().toIso8601String(),
        'scheduledEndAt': _endAt!.toUtc().toIso8601String(),
        'petIds': List<String>.from(_selectedPetIds),
        'pets': petSnaps,
        'daycarePlanId': roomBased ? '' : (_plan?.id ?? ''),
        'daycarePlanName': roomBased ? '' : (_plan?.name ?? ''),
        'daycarePlanPriceSnapshot': roomBased
            ? <String, dynamic>{}
            : (_plan?.toCallableSnapshot() ?? <String, dynamic>{}),
        'pricingMode': roomBased
            ? DaycarePricingModes.roomType
            : DaycarePricingModes.independentPlan,
        'requestedRoomTypeId': roomBased ? (_selectedRoomTypeId ?? '') : '',
        'requestedRoomTypeName': roomBased ? _primaryFeeLabel : '',
        'requestedRoomTypePriceSnapshot': roomBased
            ? (roomSetting?.toCallableSnapshot() ?? <String, dynamic>{})
            : <String, dynamic>{},
        'assignedRoomTypeId': null,
        'assignedRoomId': null,
        'assignedRoomName': null,
        'priceQuoteSnapshot': <String, dynamic>{
          ...quote.toPriceSnapshot(),
          'planId': roomBased ? '' : (_plan?.id ?? ''),
          'planName': _primaryFeeLabel,
          'includedMinutes': quote.includedMinutes,
          'basePrice': quote.baseAmount,
          'extraBillingMinutes': quote.extraBillingMinutes,
          'extraBillingPrice': roomBased
              ? (roomSetting?.extraBillingPrice ?? 0)
              : (_plan?.extraBillingPrice ?? 0),
          'extraPetPrice': roomBased
              ? (roomSetting?.extraPetPrice ?? 0)
              : (_plan?.extraPetPrice ?? 0),
          'maxBaseCharge': quote.maxBaseCharge,
          'petCount': _selectedPetIds.length,
          'scheduledStartAt': _startAt!.toUtc().toIso8601String(),
          'scheduledEndAt': _endAt!.toUtc().toIso8601String(),
        },
        'addons': _addonLines,
        'customerName': _name.text.trim(),
        'customerPhone': _phone.text.trim(),
        'address': address,
        'emergencyName': emergencyName,
        'emergencyPhone': emergencyPhone,
        'relation': relation,
        'emergencyAddress': emergencyAddress,
        'phone2': phone2,
        'note': _note.text.trim(),
        ...termsConsent.toCallableFields(),
        'policySignMethod': 'member_online',
        'paymentMethod': paymentMethod,
        'payAmountType': payAmountType,
        'depositAmount': depositAmount,
        if (_selectedCoupon != null) 'couponId': _selectedCoupon!.id,
        if (_selectedCoupon != null) 'couponName': _selectedCoupon!.name,
        'couponDiscountAmount': quote.couponAmount,
      };
      CallablePayload.assertValid(payload);
      final Map<String, dynamic> created = await DaycareFunctionService.instance
          .createBooking(payload);
      final String bookingId = (created['bookingId'] ?? requestId).toString();
      if (!mounted) {
        return;
      }
      final bool isEcpay =
          paymentMethod == 'credit_card' ||
          paymentMethod == 'atm' ||
          paymentMethod == 'cvs_code';
      if (isEcpay) {
        final int amount = payAmountType == 'deposit'
            ? depositAmount
            : quote.totalAmount;
        final String paymentRequestId = FirebaseFirestore.instance
            .collection('payments')
            .doc()
            .id;
        final paymentResult = await PaymentFunctionService.instance
            .createPayment(
              request: CreatePaymentRequestModel(
                shopId: widget.shopId,
                bookingId: bookingId,
                paymentMethod: paymentMethod,
                amountType: payAmountType == 'deposit'
                    ? PaymentAmountType.deposit
                    : PaymentAmountType.full,
                paymentPurpose: payAmountType == 'deposit'
                    ? PaymentPurpose.deposit
                    : PaymentPurpose.full,
                amount: amount,
                requestId: paymentRequestId,
              ),
            );
        if (!mounted) {
          return;
        }
        if (paymentResult.hasPaymentHtml) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EcpayPaymentPage(
                paymentHtml: paymentResult.paymentHtml,
                paymentId: paymentResult.paymentId,
                bookingId: bookingId,
              ),
            ),
            (Route<dynamic> route) => false,
          );
          return;
        }
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(
          builder: (_) => BookingSuccessPage(
            shopName: (widget.shop['name'] ?? '').toString(),
            shopId: widget.shopId,
            bookingId: bookingId,
            message: '訂單已送出，等待店家確認',
          ),
        ),
        (Route<dynamic> route) => false,
      );
    } on CallablePayloadException catch (error, stackTrace) {
      debugPrint(error.debugMessage);
      debugPrintStack(stackTrace: stackTrace);
      throw Exception(CallablePayload.userMessage);
    } on DaycareFunctionException catch (error, stackTrace) {
      debugPrint('[DaycareSubmit] failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _bookingRequestId = null;
      _bookingRequestSignature = null;
      throw Exception(error.message);
    } catch (error, stackTrace) {
      debugPrint('[DaycareSubmit] failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (error is! PaymentFunctionException) {
        _bookingRequestId = null;
        _bookingRequestSignature = null;
      }
      rethrow;
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
    HomeThemeModel theme;
    try {
      theme = HomeBannerService.instance.themeFromShop(widget.shop);
    } catch (_) {
      theme = HomeThemeModel.classicDefault;
    }
    List<String> slots;
    try {
      slots = DaycareTimeHelper.slots(
        start: _dayHours.earliestDropOff,
        end: _dayHours.latestPickUp,
        stepMinutes: widget.settings.slotMinutes,
      );
    } catch (_) {
      slots = <String>[];
    }
    slots = slots.toSet().toList();
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
        title: const Text(
          '寵物安親',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (_step == 1) ..._stepDatePets(theme, slots),
                            if (_step == 2) ..._stepPlanAddons(theme),
                            if (_step == 3) ..._stepFees(theme, quote),
                          ],
                        ),
                      ),
                    ),
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
                                    if (_step == 3) {
                                      _loadCoupons();
                                    }
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
      ..._dateAndTimeCards(theme, slots),
      const SizedBox(height: 16),
      BookingPetSection(
        theme: theme,
        title: '選擇安親寵物（已選 ${_selectedPetIds.length} 隻）',
        selectedPetIds: _selectedPetIds,
        petsStream: widget.debugPetsStream,
        isLoggedIn: widget.debugLoggedIn,
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
    ];
  }

  String _formatDate(DateTime date) {
    final String year = date.year.toString();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  List<Widget> _dateAndTimeCards(HomeThemeModel theme, List<String> slots) {
    return <Widget>[
      BookingThemedCard(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _shopTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '日期與寵物',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '請先選擇安親日期，再安排送達與接回時間',
              style: TextStyle(
                fontSize: 12,
                color: theme.textColor.withValues(alpha: 0.7),
              ),
            ),
            if (widget.settings.intro.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                widget.settings.intro,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 72,
                  child: Text(
                    '安親日期',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _date == null ? '尚未選擇' : _formatDate(_date!),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _openCalendar,
                icon: const Icon(Icons.calendar_month, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.cardBorderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                label: Text(
                  _date == null ? '選擇日期' : '重新選擇日期',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
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
            if (slots.isEmpty)
              Text(
                '目前沒有可選時段。請確認店家安親送達／接回時間設定。',
                style: TextStyle(color: theme.textColor),
              )
            else ...<Widget>[
              DropdownButtonFormField<String>(
                value: dropdownValueIfAllowed(_dropOff, slots),
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
                value: dropdownValueIfAllowed(_pickUp, slots),
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
          ],
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
              roomBased: true,
              remainingRooms: option.remainingRooms,
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
    if (quote == null || _startAt == null || _endAt == null) {
      return <Widget>[
        Text('請先完成日期、時間、寵物與方案選擇。', style: TextStyle(color: theme.textColor)),
      ];
    }
    final List<BookingFeeLineItem> lines = _feeLines(quote);
    return <Widget>[
      BookingMemberCouponSection(
        theme: theme,
        selectedCoupon: _selectedCoupon,
        availableCoupons: _coupons,
        loading: _loadingCoupons,
        couponBlockedBySpecialDate: false,
        unavailableReason: widget.settings.allowCoupon ? null : '此店安親目前不可使用優惠券',
        couponDiscountAmount: quote.couponAmount,
        onClear: () => setState(() => _selectedCoupon = null),
        onPick: _pickCoupon,
      ),
      const SizedBox(height: 12),
      DaycareBookingSummaryCard(
        theme: theme,
        dateText: DaycareTimeHelper.formatDate(_startAt!),
        dropOffText: DaycareTimeHelper.formatHm(_startAt!),
        pickUpText: DaycareTimeHelper.formatHm(_endAt!),
        durationMinutes: quote.durationMinutes,
        petCount: _selectedPetIds.length,
        petNames: _petNames,
        planName: _primaryFeeLabel,
        roomTypeName: '實際房間將由店家安排',
      ),
      const SizedBox(height: 12),
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

  Future<void> _pickCoupon() async {
    final MemberCouponModel? result = await showBookingMemberCouponPicker(
      context: context,
      theme: HomeBannerService.instance.themeFromShop(widget.shop),
      coupons: _coupons,
      selectedCoupon: _selectedCoupon,
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() => _selectedCoupon = result);
  }
}
