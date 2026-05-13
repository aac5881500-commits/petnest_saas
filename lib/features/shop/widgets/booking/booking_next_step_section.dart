// lib/features/shop/widgets/booking/booking_next_step_section.dart
// 🔥 前台預約下一步按鈕：進入填寫資料頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';

class BookingNextStepSection extends StatelessWidget {
  const BookingNextStepSection({
    super.key,
    required this.canShow,
    required this.canSubmit,
    required this.isBlacklisted,
    required this.selectedRoomType,
    required this.nights,
    required this.totalPrice,
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
  });

  final bool canShow;
  final bool canSubmit;
  final bool isBlacklisted;
  final Map<String, dynamic>? selectedRoomType;
  final int nights;
  final int totalPrice;
  final List<Map<String, dynamic>> valueServices;

  final GlobalKey<FormState> formKey;
  final String shopId;
  final List<String> serviceTypes;
  final String? selectedServiceType;
  final TextEditingController customerNameController;
  final TextEditingController customerPhoneController;
  final TextEditingController noteController;
  final bool isSubmitting;

  final ValueChanged<String?> onServiceChanged;

  final void Function(
    String address,
    String emergencyName,
    String emergencyPhone,
    String relation,
    String emergencyAddress,
    String phone2,
    int depositAmount,
    String paymentMethod,
    String payAmountType,
  ) onSubmitWithData;

  @override
  Widget build(BuildContext context) {
    if (!canShow) {
      return const SizedBox();
    }

    final enabled =
        canSubmit && !isBlacklisted && selectedRoomType != null;

    return Column(
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: enabled
                ? () {
                    final basePrice =
                        (selectedRoomType!['price'] ?? 0).toInt();

                    final extraPrice =
                        (selectedRoomType!['extraPrice'] ?? 0).toInt();

                    final petCount =
                        (selectedRoomType!['selectedPetCount'] ?? 1).toInt();

                    final extraPetCount =
                        petCount > 1 ? petCount - 1 : 0;

                    final int roomSubtotal =
                        (basePrice * nights) +
                        (extraPetCount * extraPrice * nights);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingFormPage(
                          shopId: shopId,
                          totalPrice: totalPrice,
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
            child: const Text('下一步：填寫資料'),
          ),
        ),
      ],
    );
  }
}