// 檔案名稱：lib/features/admin/pages/admin_create_daycare_booking_page.dart
// 功能說明：後台手動新增安親訂單：與住宿同一套階段版型，收費模式沿用店家 pricingMode

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_addon_line.dart';
import 'package:petnest_saas/core/services/daycare_addon_pet_guard.dart';
import 'package:petnest_saas/core/services/daycare_calendar_helper.dart';
import 'package:petnest_saas/core/services/daycare_callable_payload.dart';
import 'package:petnest_saas/core/services/daycare_enabled.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_room_type_option.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/shop_member_kind.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/admin/widgets/admin_create_flow_scaffold.dart';
import 'package:petnest_saas/features/admin/widgets/admin_create_custom_form_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_order_source_note_fields.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/services/custom_form_service.dart';
import 'package:petnest_saas/core/models/daily_care_addon_plan.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_addon_service.dart';
import 'package:petnest_saas/core/services/daily_care_entitlement_math.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daily_care_upgrade_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_create_payment_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_member_search_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_quick_create_member_dialog.dart';
import 'package:petnest_saas/features/admin/widgets/admin_quick_create_pet_dialog.dart';
import 'package:petnest_saas/features/admin/widgets/admin_selected_member_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_addon_selector.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_date_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_offer_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';
import 'package:petnest_saas/features/shop/widgets/booking/policy_sign_method_field.dart';
import 'package:petnest_saas/features/shop/widgets/daycare_enabled_gate.dart';

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
  final TextEditingController _note = TextEditingController();
  String _keywordText = '';
  int _step = 0;
  Map<String, dynamic>? _member;
  Map<String, dynamic> _shop = const <String, dynamic>{};
  DaycareSettingsModel? _settings;
  DateTime? _date;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Future<FrontCalendarPayload>? _calendarFuture;
  String? _dropOff;
  String? _pickUp;
  DaycarePlanModel? _plan;
  String? _selectedRoomTypeId;
  List<DaycareRoomTypeOption> _roomOptions = const <DaycareRoomTypeOption>[];
  final Set<String> _petIds = <String>{};
  List<Map<String, dynamic>> _pets = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _addons = <Map<String, dynamic>>[];
  final Set<String> _selectedAddonIds = <String>{};
  final Map<String, Set<String>> _addonPetIds = <String, Set<String>>{};
  final Map<String, Set<String>> _addonSlotKeys = <String, Set<String>>{};
  final Map<String, GlobalKey> _addonKeys = <String, GlobalKey>{};
  Set<String> _addonPetErrors = <String>{};
  bool _submitting = false;
  String? _submitRequestId;
  final int _manualAdjust = 0;
  bool _policyRequired = false;
  int _policyVersion = 0;
  String? _policySignMethod;
  bool _policyError = false;
  final GlobalKey _policyKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  ShopPaymentCatalog _paymentCatalog = const ShopPaymentCatalog(
    methods: <ShopPaymentMethodOption>[],
    isDepositMode: false,
    serviceType: PolicyApplicableService.daycare,
  );
  String? _paymentMethod;
  String _adminOrderSource = '電話預約';
  CustomFormModel? _adminForm;
  Map<String, dynamic> _adminFormAnswers = <String, dynamic>{};
  String? _timeSlotError;
  DailyCareSettingModel _dailyCareSetting = const DailyCareSettingModel();
  List<DailyCareAddonPlan> _dailyCarePlans = <DailyCareAddonPlan>[];
  String? _selectedDailyCareAddonId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _keyword.dispose();
    _note.dispose();
    _scrollController.dispose();
    super.dispose();
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

  bool _slotOk(String slot, {String? after}) {
    if (_date == null) {
      return false;
    }
    return DaycareTimeHelper.isSlotSelectable(
      slot: slot,
      date: _date!,
      now: DateTime.now(),
      afterSlot: after,
    );
  }

  void _revalidateSlots() {
    final DaycareSettingsModel? settings = _settings;
    if (_date == null || settings == null) {
      _timeSlotError = null;
      return;
    }
    final List<String> slots = DaycareTimeHelper.slots(
      start: settings.earliestDropOff,
      end: settings.latestPickUp,
      stepMinutes: settings.slotMinutes,
    );
    final bool anyDrop = slots.any(_slotOk);
    if (!anyDrop) {
      _dropOff = null;
      _pickUp = null;
      _timeSlotError = '今天已無有效可預約時段，請改選其他日期';
      return;
    }
    if (_dropOff != null && !_slotOk(_dropOff!)) {
      _dropOff = null;
      _pickUp = null;
      _timeSlotError = '送達時間已過期，請重新選擇';
      return;
    }
    if (_pickUp != null && !_slotOk(_pickUp!, after: _dropOff)) {
      _pickUp = null;
      _timeSlotError = '接回時間已失效，請重新選擇';
      return;
    }
    _timeSlotError = null;
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
      version = ShopPolicyService.servicePolicyVersion(
        policy: policy,
        serviceType: PolicyApplicableService.daycare,
      );
    }
    final ShopPaymentCatalog catalog = ShopPaymentMethods.resolve(
      shopData: shop ?? const <String, dynamic>{},
      serviceType: PolicyApplicableService.daycare,
      daycareDepositType: settings.depositType,
    );
    if (!mounted) {
      return;
    }
    final CustomFormModel adminForm = await CustomFormService.instance.getForm(
      shopId: widget.shopId,
      formType: CustomFormType.adminCreate,
    );
    DailyCareSettingModel careSetting = const DailyCareSettingModel();
    List<DailyCareAddonPlan> carePlans = <DailyCareAddonPlan>[];
    try {
      careSetting = await DailyCareSettingService.instance.getSetting(
        widget.shopId,
      );
      carePlans = await DailyCareAddonService.instance.listPlans(
        widget.shopId,
      );
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _shop = shop ?? const <String, dynamic>{};
      _addons = addons;
      _policyRequired = required;
      _policyVersion = version;
      _paymentCatalog = catalog;
      _adminForm = adminForm;
      _dailyCareSetting = careSetting;
      _dailyCarePlans = carePlans;
      _paymentMethod = ShopPaymentMethods.coerceAdminCreateMethod(
        catalog: catalog,
        selected: _paymentMethod,
      );
      if (settings.isRoomBased) {
        _plan = null;
      } else {
        _selectedRoomTypeId = null;
      }
    });
  }

  Future<void> _loadPets(String userId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('members')
        .doc(userId)
        .collection('pets')
        .get();

    if (!mounted) return;

    final String currentMemberId =
        (_member?['userId'] ?? _member?['uid'] ?? _member?['id'] ?? '')
            .toString();

    // 使用者若在讀取期間切換了會員，不讓舊查詢覆蓋新會員的寵物。
    if (currentMemberId != userId) return;

    setState(() {
      _pets = snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                <String, dynamic>{'id': d.id, 'petId': d.id, ...d.data()},
          )
          .toList();
      _petIds.clear();
    });

    await _refreshRoomOptions();
  }

  Future<void> _refreshRoomOptions() async {
    final DaycareSettingsModel? settings = _settings;
    if (settings == null || !settings.isRoomBased) {
      if (mounted) {
        setState(() => _roomOptions = const <DaycareRoomTypeOption>[]);
      }
      return;
    }
    if (_startAt == null || _endAt == null) {
      return;
    }
    final List<DaycareRoomTypeOption> options =
        await DaycareRoomTypeCatalog.load(
          shopId: widget.shopId,
          settings: settings,
          petCount: _petIds.isEmpty ? 1 : _petIds.length,
          startAt: _startAt,
          endAt: _endAt,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _roomOptions = options;
      if (_selectedRoomTypeId != null &&
          !options.any(
            (DaycareRoomTypeOption e) =>
                e.selectable && e.roomTypeId == _selectedRoomTypeId,
          )) {
        _selectedRoomTypeId = null;
      }
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
                          setState(() {
                            _date = tempDate;
                            _dropOff = null;
                            _pickUp = null;
                            _revalidateSlots();
                          });
                          _refreshRoomOptions();
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

  DailyCareEntitlement? _dailyCareQuote() {
    try {
      return DailyCareEntitlementMath.resolve(
        setting: _dailyCareSetting,
        isDaycare: true,
        shopDaycareOn: true,
        offerId: (_settings?.isRoomBased ?? false)
            ? (_selectedRoomTypeId ?? '')
            : (_plan?.id ?? ''),
        offerName: (_settings?.isRoomBased ?? false) ? '' : (_plan?.name ?? ''),
        purchaseAddon: _selectedDailyCareAddonId != null &&
            _selectedDailyCareAddonId!.isNotEmpty,
        nights: 1,
        startDate: _startAt,
        endDate: _endAt ?? _startAt,
      );
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _selectedAddonMaps {
    return _addons
        .where(
          (Map<String, dynamic> e) =>
              _selectedAddonIds.contains((e['id'] ?? '').toString()),
        )
        .map((Map<String, dynamic> addon) {
          final String id = (addon['id'] ?? '').toString();
          return <String, dynamic>{
            ...addon,
            'selectedPetIds': (_addonPetIds[id] ?? <String>{}).toList(),
            'selectedTimeSlots': (_addonSlotKeys[id] ?? <String>{})
                .map((String key) => <String, dynamic>{'id': key, 'label': key})
                .toList(),
          };
        })
        .toList();
  }

  DaycareQuote? get _quote {
    final DaycareSettingsModel? settings = _settings;
    if (settings == null || _startAt == null || _endAt == null) {
      return null;
    }
    int addonAmount = 0;
    for (final Map<String, dynamic> addon in _addons) {
      if (!_selectedAddonIds.contains((addon['id'] ?? '').toString())) {
        continue;
      }
      final String id = (addon['id'] ?? '').toString();
      final Map<String, dynamic> requested = <String, dynamic>{
        ...addon,
        'selectedPetIds': (_addonPetIds[id] ?? <String>{}).toList(),
        'selectedTimeSlots': (_addonSlotKeys[id] ?? <String>{})
            .map((String key) => <String, dynamic>{'id': key, 'label': key})
            .toList(),
      };
      final DaycareAddonLineResult resolved = DaycareAddonLine.resolve(
        live: addon,
        requested: requested,
        orderPetIds: _petIds.toList(),
        allowedAddonIds: settings.allowedAddonIds,
        scheduledStartAt: _startAt!,
        scheduledEndAt: _endAt!,
      );
      if (resolved.ok) {
        addonAmount += resolved.amount;
      }
    }
    final int careAmount = _dailyCareQuote()?.amount ?? 0;
    addonAmount += careAmount;
    final int petCount = _petIds.isEmpty ? 1 : _petIds.length;
    if (settings.isRoomBased) {
      if (_selectedRoomTypeId == null) {
        return null;
      }
      final DaycareRoomTypeSetting? roomSetting = settings.roomTypeSetting(
        _selectedRoomTypeId!,
      );
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
        settings: settings,
        room: roomQuote,
        addonAmount: addonAmount,
        manualAdjust: _manualAdjust,
      );
    }
    if (_plan == null) {
      return null;
    }
    return DaycarePricingService.instance.quote(
      settings: settings,
      plan: _plan!,
      startAt: _startAt!,
      endAt: _endAt!,
      petCount: petCount,
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
    if (userId.isEmpty) {
      return;
    }
    final String petId = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(userId)
        .collection('pets')
        .doc()
        .id;
    final Map<String, dynamic> pet = <String, dynamic>{
      ...created,
      'id': petId,
      'petId': petId,
    };
    if (_member!['isTempAdminMember'] != true) {
      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(userId)
          .collection('pets')
          .doc(petId)
          .set(<String, dynamic>{
            ...created,
            'petId': petId,
            'shopId': widget.shopId,
            'createdFrom': 'admin',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pets.add(pet);
      _petIds.add(petId);
    });
    await _refreshRoomOptions();
  }

  Future<void> _quickCreateMember() async {
    final Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AdminQuickCreateMemberDialog(defaultPhone: _keywordText),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      final String userId = FirebaseFirestore.instance
          .collection('user_profiles')
          .doc()
          .id;
      _member = <String, dynamic>{
        'userId': userId,
        'id': userId,
        'isTempAdminMember': true,
        'source': ShopMemberKind.adminSource,
        'name': result['name'],
        'phone': result['phone'],
        'email': '',
      };
      _pets = <Map<String, dynamic>>[];
      _petIds.clear();
      _paymentMethod = ShopPaymentMethods.coerceAdminCreateMethod(
        catalog: _paymentCatalog,
        selected: _paymentMethod,
      );
    });
  }

  String get _hint {
    final DaycareSettingsModel? settings = _settings;
    if (_step == 0) {
      if (_member == null) {
        return '請搜尋或快速建立會員';
      }
      if (_petIds.isEmpty) {
        return '請至少選擇一隻寵物';
      }
      return '';
    }
    if (_step == 1) {
      if (_date == null) {
        return '請先選擇安親日期';
      }
      if (_dropOff == null) {
        return '請選擇送達時間';
      }
      if (_pickUp == null ||
          _startAt == null ||
          _endAt == null ||
          !_startAt!.isBefore(_endAt!)) {
        return '請選擇有效的接回時間';
      }
      if (_timeSlotError != null) {
        return _timeSlotError!;
      }
      return '';
    }
    if (_step == 2) {
      if (settings == null) {
        return '安親設定載入中';
      }
      if (settings.isRoomBased && _selectedRoomTypeId == null) {
        return '請選擇安親房型';
      }
      if (!settings.isRoomBased && _plan == null) {
        return '請選擇安親方案';
      }
      return '';
    }
    if (_step == 3) {
      if (_paymentMethod == null ||
          !ShopPaymentMethods.isAdminCreateSelectable(_paymentMethod!)) {
        return '請選擇付款方式';
      }
      return '';
    }
    return '';
  }

  bool get _policyMissing =>
      _policyRequired &&
      (_policySignMethod == null || _policySignMethod!.isEmpty);

  Future<void> _scrollToPolicy() async {
    final BuildContext? target = _policyKey.currentContext;
    if (target == null) {
      return;
    }
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      alignment: 0.12,
      curve: Curves.easeOut,
    );
  }

  Future<void> _advance() async {
    if (_submitting) {
      return;
    }
    if (_hint.isNotEmpty) {
      return;
    }
    if (_step == 3 && _policyMissing) {
      setState(() => _policyError = true);
      await _scrollToPolicy();
      return;
    }
    if (_step == 3 && _adminForm?.shouldCollectAnswers == true) {
      final CustomFormValidationResult result =
          CustomFormAnswerSnapshot.validate(
            form: _adminForm!,
            answersByQuestionId: _adminFormAnswers,
          );
      if (!result.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isEmpty ? '請完成手動訂單表單必填題' : result.message,
            ),
          ),
        );
        return;
      }
    }
    if (_step == 1) {
      _revalidateSlots();
      if (_timeSlotError != null) {
        return;
      }
    }
    if (_step == 2) {
      final List<String> missing = DaycareAddonPetGuard.addonIdsMissingPets(
        selectedAddons: _selectedAddonMaps,
        addonPetIds: _addonPetIds,
      );
      setState(() => _addonPetErrors = missing.toSet());
      if (missing.isNotEmpty) {
        final GlobalKey key = _addonKeys.putIfAbsent(
          missing.first,
          GlobalKey.new,
        );
        final BuildContext? target = key.currentContext;
        if (target != null) {
          await Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 280),
            alignment: 0.12,
            curve: Curves.easeOut,
          );
        }
        return;
      }
    }
    if (_step < 4) {
      setState(() => _step += 1);
      if (_step == 2) {
        await _refreshRoomOptions();
      }
      return;
    }
    await _submit();
  }

  Future<String> _ensureMemberUserId(Map<String, dynamic> member) async {
    final String userId =
        (member['userId'] ?? member['uid'] ?? member['id'] ?? '').toString();
    if (userId.isEmpty) {
      throw const DaycareFunctionException('找不到會員資料');
    }
    if (member['isTempAdminMember'] != true) {
      return userId;
    }
    final DocumentReference<Map<String, dynamic>> memberRef = FirebaseFirestore
        .instance
        .collection('user_profiles')
        .doc(userId);
    final DocumentReference<Map<String, dynamic>> shopMemberRef =
        FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('members')
            .doc(userId);
    final WriteBatch batch = FirebaseFirestore.instance.batch();
    batch.set(memberRef, <String, dynamic>{
      'name': member['name'],
      'phone': member['phone'],
      'email': '',
      'shopIds': <String>[widget.shopId],
      'createdFrom': 'admin',
      'source': ShopMemberKind.adminSource,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(shopMemberRef, <String, dynamic>{
      'userId': userId,
      'name': member['name'] ?? '',
      'phone': member['phone'] ?? '',
      'email': '',
      'createdFrom': 'admin',
      'source': ShopMemberKind.adminSource,
      'shopId': widget.shopId,
      'petCount': _pets.length,
      'bookingCount': 0,
      'tags': <String>[],
      'blacklisted': false,
      'blacklistReason': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final Map<String, dynamic> pet in _pets) {
      final String petId = (pet['petId'] ?? pet['id'] ?? '').toString();
      if (petId.isEmpty) {
        continue;
      }
      final Map<String, dynamic> petData = <String, dynamic>{
        'petId': petId,
        'name': pet['name'] ?? '',
        'type': pet['type'] ?? '',
        'breed': pet['breed'] ?? '',
        'gender': pet['gender'] ?? '',
        'age': pet['age'] ?? '',
        'isNeutered': pet['isNeutered'] ?? false,
        'vaccine': pet['vaccine'] ?? '',
        'litterType': pet['litterType'] ?? '',
        'note': pet['note'] ?? '',
        'shopId': widget.shopId,
        'createdFrom': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.set(memberRef.collection('pets').doc(petId), petData);
      batch.set(shopMemberRef.collection('pets').doc(petId), petData);
    }
    await batch.commit();
    member['isTempAdminMember'] = false;
    member['source'] = ShopMemberKind.adminSource;
    member['userId'] = userId;
    return userId;
  }

  Future<void> _submit() async {
    final DaycareSettingsModel? settings = _settings;
    final Map<String, dynamic>? member = _member;
    if (settings == null ||
        member == null ||
        _startAt == null ||
        _endAt == null) {
      return;
    }
    if (!DaycareEnabled.isOn(shop: _shop, settings: settings)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DaycareEnabled.closedMessage)),
      );
      return;
    }
    final bool roomBased = settings.isRoomBased;
    if (roomBased && _selectedRoomTypeId == null) {
      return;
    }
    if (!roomBased && _plan == null) {
      return;
    }
    if (_policyMissing) {
      setState(() => _policyError = true);
      await _scrollToPolicy();
      return;
    }
    _revalidateSlots();
    if (_timeSlotError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_timeSlotError!)));
      return;
    }
    final String? paymentMethod = ShopPaymentMethods.coerceAdminCreateMethod(
      catalog: _paymentCatalog,
      selected: _paymentMethod,
    );
    if (paymentMethod == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇到店付款或銀行轉帳')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final String userId = await _ensureMemberUserId(member);
      final List<Map<String, dynamic>> addonSnaps = <Map<String, dynamic>>[];
      for (final Map<String, dynamic> addon in _addons) {
        final String id = (addon['id'] ?? '').toString();
        if (!_selectedAddonIds.contains(id)) {
          continue;
        }
        final Map<String, dynamic> requested = <String, dynamic>{
          ...addon,
          'selectedPetIds': (_addonPetIds[id] ?? <String>{}).toList(),
          'selectedTimeSlots': (_addonSlotKeys[id] ?? <String>{})
              .map((String key) => <String, dynamic>{'id': key, 'label': key})
              .toList(),
        };
        final DaycareAddonLineResult resolved = DaycareAddonLine.resolve(
          live: addon,
          requested: requested,
          orderPetIds: _petIds.toList(),
          allowedAddonIds: settings.allowedAddonIds,
          scheduledStartAt: _startAt!,
          scheduledEndAt: _endAt!,
        );
        if (!resolved.ok) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(resolved.error!)));
          setState(() => _submitting = false);
          return;
        }
        addonSnaps.add(
          DaycareCallablePayload.addonSnapshot(
            resolved.line,
            amount: resolved.amount,
          ),
        );
      }
      final DaycareRoomTypeSetting? roomSetting = roomBased
          ? settings.roomTypeSetting(_selectedRoomTypeId ?? '')
          : null;
      final String roomName = _roomOptions
          .where(
            (DaycareRoomTypeOption e) => e.roomTypeId == _selectedRoomTypeId,
          )
          .map((DaycareRoomTypeOption e) => e.name)
          .firstWhere((String name) => name.isNotEmpty, orElse: () => '');
      _submitRequestId ??= FirebaseFirestore.instance
          .collection('bookings')
          .doc()
          .id;
      final Map<String, dynamic> payload =
          DaycareCallablePayload.adminCreateBookingData(
            shopId: widget.shopId,
            userId: userId,
            customerName: (member['name'] ?? member['displayName'] ?? '')
                .toString(),
            customerPhone: (member['phone'] ?? '').toString(),
            scheduledStartAt: _startAt!.toUtc().toIso8601String(),
            scheduledEndAt: _endAt!.toUtc().toIso8601String(),
            petIds: _petIds.toList(),
            pets: _pets
                .where(
                  (Map<String, dynamic> e) => _petIds.contains(
                    (e['id'] ?? e['petId'] ?? '').toString(),
                  ),
                )
                .toList(),
            pricingMode: DaycarePricingModes.persist(settings.pricingMode),
            daycarePlanId: roomBased ? '' : (_plan?.id ?? ''),
            daycarePlanName: roomBased ? '' : (_plan?.name ?? ''),
            daycarePlanPriceSnapshot: roomBased
                ? <String, dynamic>{}
                : (_plan?.toCallableSnapshot() ?? <String, dynamic>{}),
            requestedRoomTypeId: roomBased ? (_selectedRoomTypeId ?? '') : '',
            requestedRoomTypeName: roomBased ? roomName : '',
            requestedRoomTypePriceSnapshot: roomBased
                ? (roomSetting?.toCallableSnapshot() ?? <String, dynamic>{})
                : <String, dynamic>{},
            addons: addonSnaps,
            manualAdjust: _manualAdjust,
            policyVersion: _policyVersion,
            policyKind: PolicyApplicableService.daycare,
            policySignMethod: _policyRequired ? (_policySignMethod ?? '') : '',
            paymentMethod: paymentMethod,
            termsType: PolicyApplicableService.daycare,
            note: _note.text.trim(),
            adminOrderSource: _adminOrderSource,
            adminCustomFormAnswers: _adminForm?.shouldCollectAnswers == true
                ? CustomFormAnswerSnapshot.build(
                    form: _adminForm!,
                    answersByQuestionId: _adminFormAnswers,
                  ).toCallableMap()
                : null,
            requestId: _submitRequestId!,
            dailyCareAddonId: _selectedDailyCareAddonId ?? '',
          );
      final Map<String, dynamic> created = await DaycareFunctionService.instance
          .createBooking(payload);
      if (!mounted) {
        return;
      }
      final String bookingId = (created['bookingId'] ?? '').toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('安親訂單已建立')));
      if (bookingId.isEmpty) {
        Navigator.pop(context);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AdminBookingRoute.page(
            bookingId: bookingId,
            shopId: widget.shopId,
            data: <String, dynamic>{
              'bookingKind': 'daycare',
              'shopId': widget.shopId,
            },
          ),
        ),
      );
    } on DaycareFunctionException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
    return DaycareEnabledGate(
      shopId: widget.shopId,
      title: '新增安親訂單',
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final DaycareSettingsModel? settings = _settings;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final HomeThemeModel theme = HomeBannerService.instance.themeFromShop(
      _shop,
    );
    final DaycareQuote? quote = _quote;
    final String offerLabel = settings.isRoomBased
        ? (_roomOptions
              .where(
                (DaycareRoomTypeOption e) =>
                    e.roomTypeId == _selectedRoomTypeId,
              )
              .map((DaycareRoomTypeOption e) => e.name)
              .firstWhere((String n) => n.isNotEmpty, orElse: () => ''))
        : (_plan?.name ?? '');
    return AdminCreateFlowScaffold(
      title: '手動新增安親訂單',
      theme: theme,
      stepIndex: _step,
      stepTitles: const <String>['會員與寵物', '日期與時間', '房型或方案', '費用與條款', '確認建立'],
      primaryLabel: _step == 4 ? '建立訂單' : '下一步',
      primaryEnabled: _hint.isEmpty && !_submitting,
      hint: _hint,
      actionHint: (_step == 3 && _policyMissing) ? '請先選擇安親條款確認方式' : '',
      onActionHint: (_step == 3 && _policyMissing) ? _scrollToPolicy : null,
      busy: _submitting,
      onBackStep: _step == 0 ? null : () => setState(() => _step -= 1),
      onPrimary: _advance,
      summary: AdminCreateFeeSummaryCard(
        theme: theme,
        lines: <String>[
          if (_member != null) '會員：${(_member!['name'] ?? '').toString()}',
          if (_petIds.isNotEmpty) '寵物：${_petIds.length} 隻',
          if (_date != null)
            '日期：${_date!.year}/${_date!.month.toString().padLeft(2, '0')}/${_date!.day.toString().padLeft(2, '0')}',
          if (_dropOff != null && _pickUp != null) '時間：$_dropOff–$_pickUp',
          if (offerLabel.isNotEmpty)
            settings.isRoomBased ? '預約房型：$offerLabel' : '方案：$offerLabel',
        ],
        totalLabel: '預估總額',
        totalAmount: quote == null
            ? ''
            : DaycarePlanModel.moneyLabel(quote.totalAmount),
      ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, 8, 16, _step == 3 ? 140 : 24),
        children: <Widget>[
          if (_step > 0 && _member != null) ...<Widget>[
            AdminSelectedMemberCard(member: _member!, shopId: widget.shopId),
            const SizedBox(height: 12),
          ],
          if (_step == 0) ..._stepMemberPets(theme),
          if (_step == 1) ..._stepDateTime(theme, settings),
          if (_step == 2) ..._stepOffer(theme, settings),
          if (_step == 3) ..._stepPay(theme, quote),
          if (_step == 4) ..._stepConfirm(theme, quote, offerLabel),
        ],
      ),
    );
  }

  List<Widget> _stepMemberPets(HomeThemeModel theme) {
    return <Widget>[
      BookingThemedCard(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '會員與寵物',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '可輸入姓名或電話搜尋會員。沒有會員時，可快速建立會員。',
              style: TextStyle(
                fontSize: 13,
                color: theme.textColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyword,
              decoration: InputDecoration(
                hintText: '搜尋會員姓名 / 電話',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (String value) => setState(() => _keywordText = value),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _quickCreateMember,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('沒有會員？快速建立會員'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
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
            _paymentMethod = ShopPaymentMethods.coerceAdminCreateMethod(
              catalog: _paymentCatalog,
              selected: _paymentMethod,
            );
          });
          _loadPets(userId);
        },
      ),
      if (_member != null) ...<Widget>[
        const SizedBox(height: 12),
        AdminSelectedMemberCard(member: _member!, shopId: widget.shopId),
        const SizedBox(height: 12),
        BookingThemedCard(
          theme: theme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '選擇寵物',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addPet,
                    icon: const Icon(Icons.add),
                    label: const Text('新增寵物'),
                  ),
                ],
              ),
              ..._pets.map((Map<String, dynamic> pet) {
                final String id = (pet['id'] ?? pet['petId'] ?? '').toString();
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
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
                    _refreshRoomOptions();
                  },
                );
              }),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _stepDateTime(
    HomeThemeModel theme,
    DaycareSettingsModel settings,
  ) {
    final List<String> slots = DaycareTimeHelper.slots(
      start: settings.earliestDropOff,
      end: settings.latestPickUp,
      stepMinutes: settings.slotMinutes,
    );
    return <Widget>[
      BookingThemedCard(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '安親日期與時間',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 10),
            DaycareDateCard(date: _date, onTap: _openCalendar),
            const SizedBox(height: 12),
            if (_timeSlotError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _timeSlotError!,
                  style: TextStyle(color: theme.primaryColor, fontSize: 13),
                ),
              ),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('drop-$_date-$_dropOff'),
              initialValue: _dropOff,
              decoration: InputDecoration(
                labelText: '送達時間',
                helperText: _date == null ? '請先選擇安親日期' : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: slots
                  .map(
                    (String t) => DropdownMenuItem<String>(
                      value: t,
                      enabled: _date != null && _slotOk(t),
                      child: Text(
                        t,
                        style: TextStyle(
                          color: _date != null && _slotOk(t)
                              ? null
                              : Colors.grey,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _date == null
                  ? null
                  : (String? value) {
                      setState(() {
                        _dropOff = value;
                        _pickUp = null;
                        _revalidateSlots();
                      });
                      _refreshRoomOptions();
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('pick-$_date-$_dropOff-$_pickUp'),
              initialValue: _pickUp,
              decoration: InputDecoration(
                labelText: '接回時間',
                helperText: _dropOff == null
                    ? (_date == null ? '請先選擇安親日期' : '請先選擇送達時間')
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: slots
                  .map(
                    (String t) => DropdownMenuItem<String>(
                      value: t,
                      enabled: _dropOff != null && _slotOk(t, after: _dropOff),
                      child: Text(
                        t,
                        style: TextStyle(
                          color: _dropOff != null && _slotOk(t, after: _dropOff)
                              ? null
                              : Colors.grey,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _dropOff == null
                  ? null
                  : (String? value) {
                      setState(() {
                        _pickUp = value;
                        _revalidateSlots();
                      });
                      _refreshRoomOptions();
                    },
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _stepOffer(HomeThemeModel theme, DaycareSettingsModel settings) {
    return <Widget>[
      BookingThemedCard(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              settings.isRoomBased ? '選擇安親房型' : '選擇安親方案',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              settings.isRoomBased
                  ? '實際房間仍於確認訂單後分配，這裡只選擇客戶預約的房型。'
                  : '實際房型／房間於後續分房決定，不影響方案價格。',
              style: TextStyle(
                fontSize: 13,
                color: theme.textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (settings.isRoomBased) ...<Widget>[
        if (_roomOptions.isEmpty)
          Text(
            DaycareRoomTypeCatalog.emptyReason(_roomOptions),
            style: TextStyle(color: theme.textColor),
          ),
        ..._roomOptions.map((DaycareRoomTypeOption option) {
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
            selected: _selectedRoomTypeId == option.roomTypeId,
            enabled: option.selectable,
            blockedReason: option.blockedReason,
            onTap: () => setState(() {
              _selectedRoomTypeId = option.roomTypeId;
              _selectedDailyCareAddonId = null;
            }),
          );
        }),
      ] else
        ...settings.customerPlans.map((DaycarePlanModel plan) {
          return DaycareOfferCard(
            theme: theme,
            title: plan.name,
            lines: DaycarePlanModel.offerDetailLines(
              includedMinutes: plan.includedMinutes,
              basePrice: plan.basePrice,
              extraBillingMinutes: plan.extraBillingMinutes,
              extraBillingPrice: plan.extraBillingPrice,
              maxBaseCharge: plan.maxBaseCharge,
              extraPetPrice: plan.extraPetPrice,
              maxPets: plan.maxPets,
              enabled: plan.enabled,
              roomBased: false,
            ),
            selected: _plan?.id == plan.id,
            enabled: plan.enabled,
            onTap: () => setState(() {
              _plan = plan;
              _selectedDailyCareAddonId = null;
            }),
          );
        }),
      if (_addons.isNotEmpty && _startAt != null && _endAt != null) ...<Widget>[
        const SizedBox(height: 8),
        DaycareAddonSelector(
          theme: theme,
          addons: _addons,
          selectedAddonIds: _selectedAddonIds,
          selectedPetIds: _petIds,
          pets: _pets,
          addonPetIds: _addonPetIds,
          addonSlotKeys: _addonSlotKeys,
          scheduledStartAt: _startAt!,
          scheduledEndAt: _endAt!,
          addonSubtotal: _quote?.addonAmount ?? 0,
          estimateTotal: _quote?.totalAmount ?? 0,
          showFeeSummary: true,
          errorAddonIds: _addonPetErrors,
          addonKeys: _addonKeys,
          onToggleAddon: (String id) {
            setState(() {
              if (_selectedAddonIds.contains(id)) {
                _selectedAddonIds.remove(id);
                _addonPetIds.remove(id);
                _addonSlotKeys.remove(id);
              } else {
                _selectedAddonIds.add(id);
              }
            });
          },
          onTogglePet: (String addonId, String petId) {
            setState(() {
              final Set<String> next = Set<String>.from(
                _addonPetIds[addonId] ?? <String>{},
              );
              if (!next.add(petId)) {
                next.remove(petId);
              }
              _addonPetIds[addonId] = next;
            });
          },
          onToggleSlot: (String addonId, String slotKey) {
            setState(() {
              final Set<String> next = Set<String>.from(
                _addonSlotKeys[addonId] ?? <String>{},
              );
              if (!next.add(slotKey)) {
                next.remove(slotKey);
              }
              _addonSlotKeys[addonId] = next;
            });
          },
        ),
      ],
      DailyCareUpgradeCard(
        setting: _dailyCareSetting,
        isDaycare: true,
        shopDaycareOn: true,
        offerId: settings.isRoomBased
            ? (_selectedRoomTypeId ?? '')
            : (_plan?.id ?? ''),
        offerName: settings.isRoomBased ? '' : (_plan?.name ?? ''),
        nights: 1,
        startDate: _startAt,
        endDate: _endAt ?? _startAt,
        selectedPlanId: _selectedDailyCareAddonId,
        onChanged: (String? id) {
          setState(() {
            _selectedDailyCareAddonId = id;
          });
        },
      ),
    ];
  }

  List<Widget> _stepPay(HomeThemeModel theme, DaycareQuote? quote) {
    return <Widget>[
      if (quote != null)
        BookingThemedCard(
          theme: theme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '費用',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text('起步／方案：${DaycarePlanModel.moneyLabel(quote.baseAmount)}'),
              if (quote.extraTimeAmount > 0)
                Text(
                  '超時：${DaycarePlanModel.moneyLabel(quote.extraTimeAmount)}',
                ),
              if (quote.extraPetAmount > 0)
                Text(
                  '多寵物加價：${DaycarePlanModel.moneyLabel(quote.extraPetAmount)}',
                ),
              if (quote.addonAmount - (_dailyCareQuote()?.amount ?? 0) > 0)
                Text(
                  '加購：${DaycarePlanModel.moneyLabel(quote.addonAmount - (_dailyCareQuote()?.amount ?? 0))}',
                ),
              if ((_dailyCareQuote()?.amount ?? 0) > 0)
                Text(
                  '照護加購：${DaycarePlanModel.moneyLabel(_dailyCareQuote()!.amount)}',
                ),
              if (_dailyCareQuote() != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  '照護基本包含每天 ${_dailyCareQuote()!.baseReports} 次、'
                  '${_dailyCareQuote()!.basePhotos} 張；升級後每天 '
                  '${_dailyCareQuote()!.finalReports} 次、'
                  '${_dailyCareQuote()!.finalPhotos} 張',
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '合計 ${DaycarePlanModel.moneyLabel(quote.totalAmount)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      BookingThemedCard(
        theme: theme,
        child: AdminOrderSourceNoteFields(
          adminOrderSource: _adminOrderSource,
          noteController: _note,
          onOrderSourceChanged: (String value) {
            setState(() => _adminOrderSource = value);
          },
        ),
      ),
      const SizedBox(height: 12),
      BookingThemedCard(
        theme: theme,
        child: AdminCreatePaymentSection(
          catalog: _paymentCatalog,
          selectedMethod: _paymentMethod,
          isManualMember: ShopMemberKind.isManualMember(_member),
          theme: theme,
          onSelected: (String id) {
            if (!ShopPaymentMethods.isAdminCreateSelectable(id)) {
              return;
            }
            setState(() => _paymentMethod = id);
          },
        ),
      ),
      const SizedBox(height: 12),
      AdminCreateCustomFormSection(
        form: _adminForm,
        answers: _adminFormAnswers,
        theme: theme,
        onChanged: (Map<String, dynamic> next) {
          setState(() => _adminFormAnswers = next);
        },
      ),
      const SizedBox(height: 12),
      if (_policyRequired)
        KeyedSubtree(
          key: _policyKey,
          child: PolicySignMethodField(
            value: _policySignMethod,
            title: '安親條款簽署方式',
            serviceLabel: '安親條款',
            showError: _policyError,
            theme: theme,
            onChanged: (String value) {
              setState(() {
                _policySignMethod = value;
                _policyError = false;
              });
            },
          ),
        ),
      if (_policyRequired) const SizedBox(height: 72),
    ];
  }

  List<Widget> _stepConfirm(
    HomeThemeModel theme,
    DaycareQuote? quote,
    String offerLabel,
  ) {
    return <Widget>[
      BookingThemedCard(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '確認建立',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '建立後會進入既有店主訂單詳細頁，並標示為手動建立。實際房間仍待確認後分配。',
              style: TextStyle(
                fontSize: 13,
                color: theme.textColor.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${(_member?['name'] ?? '').toString()} ｜ ${_petIds.length} 隻 ｜ '
              '$offerLabel ｜ ${quote == null ? '' : DaycarePlanModel.moneyLabel(quote.totalAmount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
