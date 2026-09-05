// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_completion_section.dart
// 功能說明：完成後：點數、評價、客戶備註。取消原因已在狀態摘要。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_review_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

class BookingDetailCompletionSection extends StatelessWidget {
  const BookingDetailCompletionSection({
    super.key,
    required this.view,
    required this.bookingId,
  });

  final BookingDetailViewData view;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    if (view.status != 'completed' && !view.showCustomerNote) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (view.showEarnedPoints)
          BookingDetailCard(
            child: Text(
              '本次獲得點數：${view.earnedPoints}',
              style: TextStyle(
                fontSize: BookingDetailUi.bodySize,
                color: BookingDetailUi.of(context).text,
              ),
            ),
          ),
        if (view.showReview)
          BookingDetailReviewSection(
            bookingId: bookingId,
            data: view.raw,
            bookingStatus: view.status,
            titleOverride: view.reviewLabel,
          ),
        if (view.showCustomerNote)
          BookingDetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const BookingDetailSectionTitle('備註'),
                const SizedBox(height: 8),
                Text(
                  view.customerNote,
                  style: TextStyle(
                    fontSize: BookingDetailUi.bodySize,
                    color: BookingDetailUi.of(context).text,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
