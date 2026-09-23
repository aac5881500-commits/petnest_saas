// 檔案名稱：lib/features/shop/pages/shop_daycare_booking_confirm_page.dart
// 功能說明：安親預約確認 → 填寫資料／付款 → 確認訂單

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_fee_line_item.dart';
import 'package:petnest_saas/core/models/booking_order_form_answers.dart';
import 'package:petnest_saas/core/models/create_payment_request_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_addon_line.dart';
import 'package:petnest_saas/core/services/daycare_booking_validator.dart';
import 'package:petnest_saas/core/services/daycare_callable_payload.dart';
import 'package:petnest_saas/core/services/daycare_coupon_helper.dart';
import 'package:petnest_saas/core/services/daycare_date_override_service.dart';
import 'package:petnest_saas/core/services/daycare_enabled.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/payment_function_service.dart';
import 'package:petnest_saas/core/services/special_date_surcharge_calculator.dart';
import 'package:petnest_saas/core/services/special_date_surcharge_service.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/booking/models/booking_form_submit_data.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';
import 'package:petnest_saas/features/booking/pages/booking_success_page.dart';
import 'package:petnest_saas/features/payment/pages/ecpay_payment_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_points_redeem_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daycare_booking_summary_card.dart';

class ShopDaycareBookingConfirmPage extends StatefulWidget {
  const ShopDaycareBookingConfirmPage({
    super.key,
    required this.shopId,
    required this.shop,
    required this.settings,
    required this.startAt,
    required this.endAt,
    required this.plan,
    this.requestedRoomTypeId = '',
    this.requestedRoomTypeName = '',
    required this.selectedPetIds,
    required this.pets,
    required this.addons,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final DaycareSettingsModel settings;
  final DateTime startAt;
  final DateTime endAt;
  final DaycarePlanModel plan;
  final String requestedRoomTypeId;
  final String requestedRoomTypeName;
  final List<String> selectedPetIds;
  final List<Map<String, dynamic>> pets;
  final List<Map<String, dynamic>> addons;

  @override
  State<ShopDaycareBookingConfirmPage> createState() =>
      _ShopDaycareBookingConfirmPageState();
}

class _ShopDaycareBookingConfirmPageState
    extends State<ShopDaycareBookingConfirmPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _note = TextEditingController();
  List<MemberCouponModel> _coupons = const <MemberCouponModel>[];
  MemberCouponModel? _selectedCoupon;
  bool _loadingCoupons = true;
  int _requestedPoints = 0;
  int _pointDiscountNtd = 0;
  int _surchargeAmount = 0;
  bool _surchargeAllowsCoupon = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadMember();
    _loadCoupons();
    _loadSurcharge();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadMember() async {
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
  }

  Future<void> _loadSurcharge() async {
    final surcharges = await SpecialDateSurchargeService.instance
        .getEnabledSurcharges(widget.shopId);
    final calc = SpecialDateSurchargeCalculator.calculateDaycare(
      serviceDate: widget.startAt,
      isRoomBased: widget.settings.isRoomBased,
      roomTypeId: widget.requestedRoomTypeId,
      surcharges: surcharges,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _surchargeAmount = calc.totalAmount;
      _surchargeAllowsCoupon = calc.nightDetails.every(
        (SpecialDateSurchargeNightDetail d) =>
            d.surcharges.every((s) => s.allowCoupon),
      );
    });
  }

  Future<void> _loadCoupons() async {
    if (!widget.settings.allowCoupon) {
      setState(() => _loadingCoupons = false);
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingCoupons = false);
      return;
    }
    try {
      final List<MemberCouponModel> all = await MemberCouponService.instance
          .getMemberCoupons(shopId: widget.shopId, userId: user.uid);
      final List<MemberCouponModel> usable = all
          .where(DaycareCouponHelper.appliesToDaycare)
          .where((MemberCouponModel coupon) => coupon.roomTypeIds.isEmpty)
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _coupons = usable;
        _loadingCoupons = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCoupons = false);
      }
    }
  }

  List<Map<String, dynamic>> get _addonLines {
    final List<Map<String, dynamic>> lines = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> addon in widget.addons) {
      final DaycareAddonLineResult resolved = DaycareAddonLine.resolve(
        live: addon,
        requested: addon,
        orderPetIds: widget.selectedPetIds,
        allowedAddonIds: widget.settings.allowedAddonIds,
        scheduledStartAt: widget.startAt,
        scheduledEndAt: widget.endAt,
      );
      if (!resolved.ok) {
        continue;
      }
      lines.add(<String, dynamic>{...resolved.line, 'amount': resolved.amount});
    }
    return lines;
  }

  DaycareQuote get _quote {
    int addonAmount = 0;
    for (final Map<String, dynamic> addon in _addonLines) {
      addonAmount += (addon['amount'] as num).toInt();
    }
    DaycareQuote draft;
    if (widget.settings.isRoomBased) {
      final DaycareRoomTypeSetting roomSetting =
          widget.settings.roomTypeSetting(widget.requestedRoomTypeId) ??
          const DaycareRoomTypeSetting(roomTypeId: '');
      draft = DaycarePricingService.instance.quoteFromRoom(
        settings: widget.settings,
        room: DaycarePricingService.instance.quoteRoom(
          roomSetting: roomSetting,
          startAt: widget.startAt,
          endAt: widget.endAt,
          petCount: widget.selectedPetIds.length,
        ),
        addonAmount: addonAmount,
      );
    } else {
      draft = DaycarePricingService.instance.quote(
        settings: widget.settings,
        plan: widget.plan,
        startAt: widget.startAt,
        endAt: widget.endAt,
        petCount: widget.selectedPetIds.length,
        addonAmount: addonAmount,
      );
    }
    final int resolvedCoupon =
        _selectedCoupon == null || !_surchargeAllowsCoupon
        ? 0
        : DaycareCouponHelper.discountAmount(
            coupon: _selectedCoupon!,
            planAmount: draft.baseAmount,
            extraPetAmount: draft.extraPetAmount,
            addonAmount: addonAmount,
            surchargeAmount: _surchargeAmount,
            campaignDiscountAmount: draft.discountAmount,
            selectedAddons: _addonLines,
            specialDateAllowsCoupon: _surchargeAllowsCoupon,
          );
    int payable =
        draft.baseAmount +
        draft.extraPetAmount +
        addonAmount +
        _surchargeAmount -
        resolvedCoupon;
    if (widget.settings.isRoomBased) {
      payable =
          draft.totalAmount +
          _surchargeAmount -
          draft.surchargeAmount -
          resolvedCoupon;
    }
    final int pointAmount = _pointDiscountNtd.clamp(
      0,
      payable < 0 ? 0 : payable,
    );
    if (widget.settings.isRoomBased) {
      final DaycareRoomTypeSetting roomSetting =
          widget.settings.roomTypeSetting(widget.requestedRoomTypeId) ??
          const DaycareRoomTypeSetting(roomTypeId: '');
      return DaycarePricingService.instance.quoteFromRoom(
        settings: widget.settings,
        room: DaycarePricingService.instance.quoteRoom(
          roomSetting: roomSetting,
          startAt: widget.startAt,
          endAt: widget.endAt,
          petCount: widget.selectedPetIds.length,
        ),
        addonAmount: addonAmount,
        surchargeAmount: _surchargeAmount,
        couponAmount: resolvedCoupon,
        pointAmount: pointAmount,
      );
    }
    return DaycarePricingService.instance.quote(
      settings: widget.settings,
      plan: widget.plan,
      startAt: widget.startAt,
      endAt: widget.endAt,
      petCount: widget.selectedPetIds.length,
      addonAmount: addonAmount,
      surchargeAmount: _surchargeAmount,
      couponAmount: resolvedCoupon,
      pointAmount: pointAmount,
    );
  }

  List<String> get _petNames {
    return widget.pets
        .where(
          (Map<String, dynamic> pet) => widget.selectedPetIds.contains(
            (pet['petId'] ?? pet['id'] ?? '').toString(),
          ),
        )
        .map((Map<String, dynamic> pet) => (pet['name'] ?? '').toString())
        .where((String name) => name.isNotEmpty)
        .toList();
  }

  Future<void> _openForm() async {
    final DaycareQuote quote = _quote;
    if (!mounted) {
      return;
    }
    final List<BookingFeeLineItem> feeLines = _buildFeeLines(quote);
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
          roomPrice: quote.baseAmount + quote.extraPetAmount,
          addons: _addonLines,
          formKey: GlobalKey<FormState>(),
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
          feeRuleText: _ruleText(quote),
          theme: HomeBannerService.instance.themeFromShop(widget.shop),
          termsServiceType: PolicyApplicableService.daycare,
          showStepBackButton: true,
          feeLineItems: feeLines,
          onSubmitWithData: _submit,
          selectedPets: widget.pets
              .where(
                (Map<String, dynamic> pet) => widget.selectedPetIds.contains(
                  (pet['petId'] ?? pet['id'] ?? '').toString(),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _ruleText(DaycareQuote quote) {
    return DaycarePricingService.instance.hourlyRuleTextFromQuote(
      quote,
      extraBillingPrice: widget.settings.isRoomBased
          ? (widget.settings
                    .roomTypeSetting(widget.requestedRoomTypeId)
                    ?.extraBillingPrice ??
                0)
          : widget.plan.extraBillingPrice,
    );
  }

  List<BookingFeeLineItem> _buildFeeLines(DaycareQuote quote) {
    return DaycarePricingService.instance.customerFeeLines(
      quote: quote,
      primaryLabel: widget.settings.isRoomBased
          ? (widget.requestedRoomTypeName.isEmpty
                ? '安親房型・起步價格'
                : '${widget.requestedRoomTypeName}・起步價格')
          : widget.plan.name,
      depositType: widget.settings.depositType,
      isRoomBased: widget.settings.isRoomBased,
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

  Future<void> _submit(BookingFormSubmitData data) async {
    final String address = data.fullAddress;
    final String emergencyName = data.emergencyName;
    final String emergencyPhone = data.emergencyPhone;
    final String relation = data.emergencyRelation;
    final String emergencyAddress = data.emergencyAddress;
    final String phone2 = data.secondaryPhone;
    final int depositAmount = data.calculatedDeposit;
    final String paymentMethod = data.paymentMethod;
    final String payAmountType = data.payAmountType;
    final TermsConsentSnapshot termsConsent = data.termsConsent;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final dateOverride = await DaycareDateOverrideService.instance.get(
      shopId: widget.shopId,
      date: widget.startAt,
    );
    final DaycareValidationResult schedule =
        DaycareBookingValidator.validateSchedule(
          settings: widget.settings,
          startAt: widget.startAt,
          endAt: widget.endAt,
          dateOverride: dateOverride,
        );
    if (!schedule.isOk) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(schedule.error!)));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(DaycareEnabled.closedMessage)),
        );
      }
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> addonSnap =
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('addons')
            .doc('main')
            .get();
    final List<Map<String, dynamic>> liveAddons =
        DaycareAddonCatalog.allowedForDaycare(
          doc: addonSnap.data(),
          allowedAddonIds: liveSettings.allowedAddonIds,
          serviceDate: widget.startAt,
          petCount: widget.selectedPetIds.length,
        );
    for (final Map<String, dynamic> addon in widget.addons) {
      final String id = (addon['id'] ?? '').toString();
      if (!liveAddons.any((Map<String, dynamic> e) => e['id'] == id)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('所選加值服務已停用，請返回重新選擇')));
        }
        return;
      }
    }
    setState(() => _submitting = true);
    final DaycareQuote quote = _quote;
    try {
      final String requestId = FirebaseFirestore.instance
          .collection('bookings')
          .doc()
          .id;
      final List<Map<String, dynamic>> petSnaps =
          BookingOrderFormAnswers.attachToPets(
            pets: widget.pets
                .where(
                  (Map<String, dynamic> pet) => widget.selectedPetIds.contains(
                    (pet['petId'] ?? pet['id'] ?? '').toString(),
                  ),
                )
                .map(DaycareCallablePayload.petSnapshot)
                .toList(),
            byPetId: data.petFormAnswersByPetId,
          );
      final Map<String, dynamic> created = await DaycareFunctionService.instance
          .createBooking(<String, dynamic>{
            'shopId': widget.shopId,
            'requestId': requestId,
            'scheduledStartAt': DaycareTimeHelper.callableInstant(
              widget.startAt,
            ),
            'scheduledEndAt': DaycareTimeHelper.callableInstant(widget.endAt),
            'petIds': widget.selectedPetIds,
            'pets': petSnaps,
            'daycarePlanId': widget.settings.isRoomBased ? '' : widget.plan.id,
            'daycarePlanName': widget.settings.isRoomBased
                ? ''
                : widget.plan.name,
            'daycarePlanPriceSnapshot': widget.settings.isRoomBased
                ? <String, dynamic>{}
                : widget.plan.toMap(),
            'pricingMode': widget.settings.isRoomBased
                ? DaycarePricingModes.roomType
                : DaycarePricingModes.independentPlan,
            'requestedRoomTypeId': widget.settings.isRoomBased
                ? widget.requestedRoomTypeId
                : '',
            'requestedRoomTypeName': widget.settings.isRoomBased
                ? widget.requestedRoomTypeName
                : '',
            'requestedRoomTypePriceSnapshot': widget.settings.isRoomBased
                ? (widget.settings
                          .roomTypeSetting(widget.requestedRoomTypeId)
                          ?.toMap() ??
                      <String, dynamic>{})
                : <String, dynamic>{},
            'assignedRoomTypeId': null,
            'assignedRoomId': null,
            'assignedRoomName': null,
            'priceQuoteSnapshot': <String, dynamic>{
              ...quote.toPriceSnapshot(),
              'planId': widget.settings.isRoomBased ? '' : widget.plan.id,
              'planName': widget.settings.isRoomBased
                  ? widget.requestedRoomTypeName
                  : widget.plan.name,
              'includedMinutes': widget.settings.isRoomBased
                  ? (widget.settings
                            .roomTypeSetting(widget.requestedRoomTypeId)
                            ?.includedMinutes ??
                        quote.includedMinutes)
                  : widget.plan.includedMinutes,
              'basePrice': quote.baseAmount,
              'extraBillingMinutes': quote.extraBillingMinutes,
              'extraBillingPrice': widget.settings.isRoomBased
                  ? (widget.settings
                            .roomTypeSetting(widget.requestedRoomTypeId)
                            ?.extraBillingPrice ??
                        0)
                  : widget.plan.extraBillingPrice,
              'extraPetPrice': widget.settings.isRoomBased
                  ? (widget.settings
                            .roomTypeSetting(widget.requestedRoomTypeId)
                            ?.extraPetPrice ??
                        0)
                  : widget.plan.extraPetPrice,
              'maxBaseCharge': quote.maxBaseCharge,
              'petCount': widget.selectedPetIds.length,
              'scheduledStartAt': DaycareTimeHelper.callableInstant(
                widget.startAt,
              ),
              'scheduledEndAt': DaycareTimeHelper.callableInstant(widget.endAt),
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
            ...termsConsent.toBookingFields(),
            'policySignMethod': 'member_online',
            'paymentMethod': paymentMethod,
            'payAmountType': payAmountType,
            'depositAmount': depositAmount,
            if (_selectedCoupon != null) 'couponId': _selectedCoupon!.id,
            if (_selectedCoupon != null) 'couponName': _selectedCoupon!.name,
            'couponDiscountAmount': quote.couponAmount,
            'specialDateSurchargeAmount': quote.surchargeAmount,
            'pointAmount': quote.pointAmount,
            'requestedPoints': _requestedPoints,
            if (data.customFormAnswers != null)
              'customFormAnswers': data.customFormAnswers!.toCallableMap(),
            if (data.petFormAnswersByPetId.isNotEmpty)
              'petFormAnswersByPetId': data.petFormAnswersByPetId,
          });
      final String bookingId = (created['bookingId'] ?? requestId).toString();
      if (!mounted) {
        return;
      }
      final bool isEcpay =
          paymentMethod == 'credit_card' ||
          paymentMethod == 'atm' ||
          paymentMethod == 'cvs_code';
      if (isEcpay && !widget.settings.isRoomBased) {
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DaycareQuote quote = _quote;
    return Scaffold(
      appBar: AppBar(title: const Text('預約確認')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          DaycareBookingSummaryCard(
            dateText: DaycareTimeHelper.formatDate(widget.startAt),
            dropOffText: DaycareTimeHelper.formatHm(widget.startAt),
            pickUpText: DaycareTimeHelper.formatHm(widget.endAt),
            durationMinutes: quote.durationMinutes,
            petCount: widget.selectedPetIds.length,
            petNames: _petNames,
            planName: widget.settings.isRoomBased
                ? (widget.requestedRoomTypeName.isEmpty
                      ? '安親房型'
                      : widget.requestedRoomTypeName)
                : widget.plan.name,
            roomTypeName: widget.settings.isRoomBased
                ? '實際房間將由店家安排'
                : '房間將由店家安排',
          ),
          const SizedBox(height: 16),
          Text(
            '費用明細',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _ruleText(quote),
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ..._buildFeeLines(quote).map((BookingFeeLineItem line) {
            final String prefix = line.amount < 0
                ? '-NT\$ ${line.amount.abs()}'
                : 'NT\$ ${line.amount}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          line.label,
                          style: TextStyle(
                            fontWeight:
                                line.kind == BookingFeeLineKind.total ||
                                    line.kind == BookingFeeLineKind.payable
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (line.subtitle.isNotEmpty)
                          Text(
                            line.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    prefix,
                    style: TextStyle(
                      fontWeight:
                          line.kind == BookingFeeLineKind.total ||
                              line.kind == BookingFeeLineKind.payable
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (widget.settings.allowCoupon) ...<Widget>[
            const SizedBox(height: 20),
            const Text(
              '使用優惠券',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_loadingCoupons)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_coupons.isEmpty)
              const Text('目前沒有可使用的安親優惠券', style: TextStyle(color: Colors.grey))
            else
              Column(
                children: _coupons.map((MemberCouponModel coupon) {
                  final bool selected = _selectedCoupon?.id == coupon.id;
                  return RadioListTile<String>(
                    value: coupon.id,
                    groupValue: _selectedCoupon?.id,
                    title: Text(coupon.name),
                    subtitle: Text(
                      coupon.description.trim().isEmpty
                          ? '可用於安親'
                          : coupon.description,
                    ),
                    onChanged: (_) {
                      setState(() {
                        _selectedCoupon = selected ? null : coupon;
                      });
                    },
                  );
                }).toList(),
              ),
            if (_selectedCoupon != null)
              TextButton(
                onPressed: () => setState(() => _selectedCoupon = null),
                child: const Text('取消使用優惠券'),
              ),
          ],
          BookingPointsRedeemSection(
            shopId: widget.shopId,
            userId: FirebaseAuth.instance.currentUser?.uid ?? '',
            channel: 'daycare',
            payableAfterCoupon: quote.totalAmount + quote.pointAmount,
            requestedPoints: _requestedPoints,
            onRequestedPointsChanged: (int value) {
              if (_requestedPoints != value) {
                setState(() => _requestedPoints = value);
              }
            },
            onPreview: (int ntd, int used) {
              if (_pointDiscountNtd != ntd || _requestedPoints != used) {
                setState(() {
                  _pointDiscountNtd = ntd;
                  _requestedPoints = used;
                });
              }
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _openForm,
              child: const Text('下一步：填寫資料'),
            ),
          ),
        ],
      ),
    );
  }
}
