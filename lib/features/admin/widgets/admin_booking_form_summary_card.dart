// 檔案名稱：lib/features/admin/widgets/admin_booking_form_summary_card.dart
// 功能說明：桌機右欄表單摘要；點擊後在左欄展開完整表單。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_form_visibility.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_answers_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_focus.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_care_forms.dart';

class AdminBookingFormSummaryCard extends StatelessWidget {
  const AdminBookingFormSummaryCard({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.data,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> pets =
        AdminBookingFormAnswersSection.petsOf(data);
    final dynamic customerRaw =
        data['customFormAnswers'] ??
        data['bookingFormAnswers'] ??
        data['formAnswers'];
    final dynamic adminRaw = data['adminCustomFormAnswers'];
    final bool showCustomer = BookingFormVisibility.showCustomerSubmitForm(
      data: data,
      hasAnswers: AdminBookingFormAnswersSection.hasVisibleAnswers(
        customerRaw,
      ),
    );
    final bool showAdmin = BookingFormVisibility.showAdminCreateForm(
      data: data,
      isShopView: true,
      hasAnswers: AdminBookingFormAnswersSection.hasVisibleAnswers(adminRaw),
    );
    final int customerFilled = AdminBookingFormAnswersSection.filledCount(
      customerRaw,
    );
    final int adminFilled = AdminBookingFormAnswersSection.filledCount(
      adminRaw,
    );
    return AdminBookingDetailSection(
      title: '表單資料摘要',
      child: AdminBookingDetailCard(
        child: Column(
          children: <Widget>[
            _row(
              context,
              label: '寵物照護資料',
              trailing: AdminBookingPetCareFormsSummary(
                shopId: shopId,
                userId: PetShopFormAnswers.bookingUserId(data),
                pets: pets,
                bookingId: bookingId,
              ),
              anchor: AdminBookingFormAnchor.petCare,
            ),
            _row(
              context,
              label: '客戶送單表單',
              trailing: Text(
                showCustomer ? '已填 $customerFilled 題' : '無',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              anchor: AdminBookingFormAnchor.customerSubmit,
            ),
            _row(
              context,
              label: '手動訂單表單',
              trailing: Text(
                showAdmin
                    ? (adminFilled > 0 ? '已填 $adminFilled 題' : '可編輯')
                    : '無',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              anchor: AdminBookingFormAnchor.adminCreate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required Widget trailing,
    required AdminBookingFormAnchor anchor,
  }) {
    return InkWell(
      onTap: () {
        AdminBookingFormFocusScope.maybeOf(context)?.requestFocus(anchor);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            trailing,
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
