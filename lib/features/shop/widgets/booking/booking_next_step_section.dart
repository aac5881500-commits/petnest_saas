// 檔案名稱：lib/features/shop/widgets/booking/booking_next_step_section.dart
// 功能說明：前台預約下一步按鈕：進入填寫資料頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_fee_line_item.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_submit_helper.dart';

class BookingNextStepSection extends StatelessWidget {
  const BookingNextStepSection({
    super.key,
    required this.canShow,
    required this.canSubmit,
    required this.isBlacklisted,
    required this.selectedRoomType,
    required this.nights,
    required this.totalPrice,
    required this.originalTotal,
    required this.discountAmount,
    required this.discountCampaignName,
    required this.specialDateSurchargeAmount,
    required this.selectedPetIds,
    required this.startDate,
    required this.endDate,
    required this.valueServices,
    required this.formKey,
    required this.shopId,
    required this.serviceTypes,
    required this.selectedServiceType,
    required this.customerNameController,
    required this.customerPhoneController,
    required this.noteController,
    required this.isSubmitting,
    required this.onServiceChanged,
    required this.onSubmitWithData,
    this.theme = HomeThemeModel.classicDefault,
    this.compact = false,
  });

  final bool canShow;
  final bool canSubmit;
  final bool isBlacklisted;
  final Map<String, dynamic>? selectedRoomType;
  final int nights;
  final int totalPrice;
  final int originalTotal;
  final int discountAmount;
  final String discountCampaignName;
  final int specialDateSurchargeAmount;
  final List<Map<String, dynamic>> valueServices;
  final List<String> selectedPetIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final GlobalKey<FormState> formKey;
  final String shopId;
  final List<String> serviceTypes;
  final String? selectedServiceType;
  final TextEditingController customerNameController;
  final TextEditingController customerPhoneController;
  final TextEditingController noteController;
  final bool isSubmitting;

  final ValueChanged<String?> onServiceChanged;

  final Future<void> Function(
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
  )
  onSubmitWithData;

  final HomeThemeModel theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!canShow) {
      return const SizedBox();
    }

    final enabled = canSubmit && !isBlacklisted && selectedRoomType != null;

    return Column(
      children: [
        if (!compact) ...[const SizedBox(height: 8)],
        BookingPrimaryButton(
          theme: theme,
          label: '下一步：填寫資料',
          onPressed: enabled
              ? () async {
                  if (startDate != null &&
                      endDate != null &&
                      selectedPetIds.isNotEmpty) {
                    try {
                      await BookingSubmitHelper.checkDuplicatePetBooking(
                        shopId: shopId,
                        selectedPetIds: selectedPetIds,
                        startDate: startDate!,
                        endDate: endDate!,
                      );
                    } catch (e) {
                      final message = e.toString().replaceFirst(
                        'Exception: ',
                        '',
                      );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));

                      return;
                    }
                  }

                  final basePrice = (selectedRoomType!['price'] ?? 0).toInt();

                  final int extraPrice =
                      ((selectedRoomType!['extraPrice'] ?? 0) is num
                      ? (selectedRoomType!['extraPrice'] as num).toInt()
                      : int.tryParse(
                              (selectedRoomType!['extraPrice'] ?? 0).toString(),
                            ) ??
                            0);

                  final petCount = (selectedRoomType!['selectedPetCount'] ?? 1)
                      .toInt();

                  final int extraPetCount = petCount > 1 ? petCount - 1 : 0;
                  final int extraPetTotal = extraPetCount * extraPrice * nights;
                  final String roomName = (selectedRoomType!['name'] ?? '住宿房型')
                      .toString();
                  final List<BookingFeeLineItem>
                  feeLines = <BookingFeeLineItem>[
                    BookingFeeLineItem(
                      label: '$roomName・固定日價',
                      amount: basePrice * nights,
                    ),
                    if (extraPetTotal > 0)
                      BookingFeeLineItem(
                        label: extraPetCount == 1
                            ? '第 2 隻寵物加收'
                            : '第 2～${extraPetCount + 1} 隻寵物加收',
                        amount: extraPetTotal,
                      ),
                    if (specialDateSurchargeAmount > 0)
                      BookingFeeLineItem(
                        label: '特殊日期加價',
                        amount: specialDateSurchargeAmount,
                      ),
                    ...valueServices.map(
                      (Map<String, dynamic> addon) => BookingFeeLineItem(
                        label: (addon['name'] ?? '加值服務').toString(),
                        amount: (addon['amount'] ?? addon['price'] ?? 0) is num
                            ? (addon['amount'] ?? addon['price'] as num).toInt()
                            : int.tryParse(
                                    (addon['amount'] ?? addon['price'] ?? 0)
                                        .toString(),
                                  ) ??
                                  0,
                      ),
                    ),
                    if (discountAmount > 0)
                      BookingFeeLineItem(
                        label: discountCampaignName.trim().isEmpty
                            ? '優惠折抵'
                            : discountCampaignName,
                        amount: -discountAmount,
                        kind: BookingFeeLineKind.discount,
                      ),
                    BookingFeeLineItem(
                      label: '預估總額',
                      amount: totalPrice,
                      kind: BookingFeeLineKind.total,
                    ),
                    BookingFeeLineItem(
                      label: '本次應付',
                      amount: totalPrice,
                      kind: BookingFeeLineKind.payable,
                    ),
                  ];

                  final int roomSubtotal =
                      (basePrice * nights) +
                      (extraPetCount * extraPrice * nights) +
                      specialDateSurchargeAmount;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingFormPage(
                        shopId: shopId,
                        totalPrice: totalPrice,
                        originalTotal: originalTotal,
                        discountAmount: discountAmount,
                        discountCampaignName: discountCampaignName,
                        roomPrice: roomSubtotal,
                        addons: valueServices,
                        formKey: formKey,
                        customerNameController: customerNameController,
                        customerPhoneController: customerPhoneController,
                        noteController: noteController,
                        serviceTypes: serviceTypes,
                        selectedServiceType: selectedServiceType,
                        onServiceChanged: onServiceChanged,
                        onSubmitWithData: onSubmitWithData,
                        onSubmit: () {},
                        isSubmitting: isSubmitting,
                        canSubmit: canSubmit,
                        isBlacklisted: isBlacklisted,
                        theme: theme,
                        termsServiceType: PolicyApplicableService.accommodation,
                        feeLineItems: feeLines,
                      ),
                    ),
                  );
                }
              : null,
        ),
      ],
    );
  }
}
