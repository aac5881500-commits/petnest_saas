// lib/features/booking/widgets/booking_detail/booking_detail_preparation_section.dart
// 下一步／入住前事項：準備公告、接回、餵食、條款、付款。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/features/booking/pages/booking_pet_care_info_page.dart';
import 'package:petnest_saas/features/booking/pages/booking_stay_arrangement_page.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

class BookingDetailPreparationSection extends StatelessWidget {
  const BookingDetailPreparationSection({
    super.key,
    required this.view,
    required this.guide,
    required this.onOpenTerms,
    required this.onOpenPayment,
  });

  final BookingDetailViewData view;
  final PreArrivalGuideModel? guide;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPayment;

  @override
  Widget build(BuildContext context) {
    final bool showGuide = guide != null && guide!.hasCustomerContent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            view.stayDataComplete ? '入住資料已完成' : '下一步／入住前事項',
            style: TextStyle(
              fontSize: BookingDetailUi.sectionTitleSize,
              fontWeight: FontWeight.w700,
              color: BookingDetailUi.of(context).text,
            ),
          ),
        ),
        if (showGuide)
          BookingDetailEntryRow(
            icon: Icons.checklist_outlined,
            title: guide!.displayTitle,
            subtitle: '查看需要攜帶的物品與注意事項',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PreArrivalGuidePage(guide: guide!),
                ),
              );
            },
          ),
        BookingDetailEntryRow(
          icon: Icons.schedule_outlined,
          title: view.isDaycare ? '送達與接回安排' : '入住與接回安排',
          subtitle: view.stayArrangementComplete
              ? (view.dateRangeLabel.isEmpty ? '已安排' : view.dateRangeLabel)
              : '尚未填寫時段',
          done: view.stayArrangementComplete,
          badge: view.stayArrangementComplete ? null : '待完成',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => BookingStayArrangementPage(view: view),
              ),
            );
          },
        ),
        BookingDetailEntryRow(
          icon: Icons.restaurant_outlined,
          title: '餵食與用藥安排',
          subtitle: view.feedingComplete ? '已提供寵物照護資料' : '尚未填寫餵食或用藥資料',
          done: view.feedingComplete,
          badge: view.feedingComplete ? null : '待完成',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => BookingPetCareInfoPage(view: view),
              ),
            );
          },
        ),
        BookingDetailEntryRow(
          icon: Icons.gavel_outlined,
          title: view.isDaycare ? '安親條款' : '住宿條款',
          subtitle: switch (view.termsState) {
            BookingDetailTermsState.confirmed =>
              '已確認 v${view.termsVersion}${view.termsAcceptedAt == null ? '' : '・${view.formatDateTime(view.termsAcceptedAt)}'}',
            BookingDetailTermsState.needsReconfirm => '條款已更新，請重新確認',
            BookingDetailTermsState.unconfirmed => '尚未確認條款',
          },
          done: view.termsState == BookingDetailTermsState.confirmed,
          badge: view.termsState == BookingDetailTermsState.confirmed
              ? null
              : (view.termsState == BookingDetailTermsState.needsReconfirm
                    ? '待完成'
                    : '必填'),
          onTap: onOpenTerms,
        ),
        if (!view.paymentTaskComplete)
          BookingDetailEntryRow(
            icon: Icons.payments_outlined,
            title: '尚未付款',
            subtitle: '尚需付款 NT\$ ${view.remainingAmount}',
            badge: '待完成',
            onTap: onOpenPayment,
          )
        else
          BookingDetailEntryRow(
            icon: Icons.payments_outlined,
            title: '付款',
            subtitle: '已付清',
            done: true,
            onTap: onOpenPayment,
          ),
      ],
    );
  }
}
