// lib/features/shop/pages/shop_daycare_booking_confirm_page.dart
// 🐾 安親預約確認 → 填寫資料／付款 → 確認訂單

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_fee_line_item.dart';
import 'package:petnest_saas/core/models/create_payment_request_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/point_setting_model.dart';
import 'package:petnest_saas/core/services/daycare_addon_catalog.dart';
import 'package:petnest_saas/core/services/daycare_booking_validator.dart';
import 'package:petnest_saas/core/services/daycare_coupon_helper.dart';
import 'package:petnest_saas/core/services/daycare_date_override_service.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/payment_function_service.dart';
import 'package:petnest_saas/core/services/point_setting_service.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';
import 'package:petnest_saas/features/booking/pages/booking_success_page.dart';
import 'package:petnest_saas/features/payment/pages/ecpay_payment_page.dart';
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
  bool _pointsSpendEnabled = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadMember();
    _loadCoupons();
    _loadPoints();
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

  Future<void> _loadPoints() async {
    final PointSettingModel setting = await PointSettingService.instance
        .getPointSetting(widget.shopId);
    if (!mounted) {
      return;
    }
    setState(() => _pointsSpendEnabled = setting.daycareSpendEnabled);
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
    final int minutes = widget.endAt.difference(widget.startAt).inMinutes;
    final int petCount = widget.selectedPetIds.length;
    return widget.addons.map((Map<String, dynamic> addon) {
      final int amount = DaycarePricingService.instance.addonLineAmount(
        addon: addon,
        minutes: minutes,
        petCount: petCount,
      );
      return <String, dynamic>{...addon, 'amount': amount};
    }).toList();
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
    final int resolvedCoupon = _selectedCoupon == null
        ? 0
        : DaycareCouponHelper.discountAmount(
            coupon: _selectedCoupon!,
            planAmount: draft.baseAmount,
            extraPetAmount: draft.extraPetAmount,
            addonAmount: addonAmount,
            surchargeAmount: draft.surchargeAmount,
            campaignDiscountAmount: draft.discountAmount,
            selectedAddons: _addonLines,
            specialDateAllowsCoupon: true,
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
        couponAmount: resolvedCoupon,
      );
    }
    return DaycarePricingService.instance.quote(
      settings: widget.settings,
      plan: widget.plan,
      startAt: widget.startAt,
      endAt: widget.endAt,
      petCount: widget.selectedPetIds.length,
      addonAmount: addonAmount,
      couponAmount: resolvedCoupon,
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
          theme: HomeBannerService.instance.themeFromShop(widget.shop),
          termsServiceType: PolicyApplicableService.daycare,
          feeLineItems: feeLines,
          onSubmitWithData: _submit,
        ),
      ),
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

  Future<void> _submit(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('此店家尚未開放安親')));
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
      final List<Map<String, dynamic>> petSnaps = widget.pets
          .where(
            (Map<String, dynamic> pet) => widget.selectedPetIds.contains(
              (pet['petId'] ?? pet['id'] ?? '').toString(),
            ),
          )
          .map(
            (Map<String, dynamic> pet) => <String, dynamic>{
              'petId': (pet['petId'] ?? pet['id'] ?? '').toString(),
              'name': pet['name'],
              'breed': pet['breed'],
              'gender': pet['gender'],
              'isNeutered': pet['isNeutered'],
              'photoUrl': pet['photoUrl'] ?? '',
            },
          )
          .toList();
      final Map<String, dynamic> created = await DaycareFunctionService.instance
          .createBooking(<String, dynamic>{
            'shopId': widget.shopId,
            'requestId': requestId,
            'scheduledStartAt': widget.startAt.toIso8601String(),
            'scheduledEndAt': widget.endAt.toIso8601String(),
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
              'scheduledStartAt': widget.startAt.toIso8601String(),
              'scheduledEndAt': widget.endAt.toIso8601String(),
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
            addons: _addonLines,
            quote: quote,
            couponName: _selectedCoupon?.name ?? '',
          ),
          if (_pointsSpendEnabled && quote.pointAmount == 0) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              '此店安親可折抵點數，實際折抵金額會在店家確認後依點數設定計算。',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
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
