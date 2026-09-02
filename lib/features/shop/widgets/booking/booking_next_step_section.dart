// lib/features/shop/widgets/booking/booking_next_step_section.dart
// 🔥 前台預約下一步按鈕：進入填寫資料頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
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

                  final extraPrice = (selectedRoomType!['extraPrice'] ?? 0)
                      .toInt();

                  final petCount = (selectedRoomType!['selectedPetCount'] ?? 1)
                      .toInt();

                  final extraPetCount = petCount > 1 ? petCount - 1 : 0;

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
