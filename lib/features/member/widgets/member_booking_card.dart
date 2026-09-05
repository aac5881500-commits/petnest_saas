// 檔案名稱：lib/features/member/widgets/member_booking_card.dart
// 功能說明：會員訂單列表卡：沿用 BookingDetailViewData 顯示，不重算價格。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:petnest_saas/features/member/widgets/member_section_card.dart';
import 'package:petnest_saas/features/member/widgets/member_status_chip.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class MemberBookingCard extends StatelessWidget {
  const MemberBookingCard({super.key, required this.view});

  final BookingDetailViewData view;

  @override
  Widget build(BuildContext context) {
    final bool cancelled = view.status == 'cancelled';
    final bool completed = view.status == 'completed';
    final String petsText = view.petNames.isNotEmpty
        ? view.petNames
        : (view.petCount > 0 ? '${view.petCount} 隻寵物' : '寵物資料未填寫');
    final String shopTitle = view.shopName.trim().isEmpty
        ? '預約訂單'
        : view.shopName.trim();

    return Opacity(
      opacity: cancelled ? 0.82 : 1,
      child: MemberSectionCard(
        muted: cancelled,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  BookingDetailPage(data: view.raw, docId: view.docId),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                MemberStatusChip(
                  label: view.serviceLabel,
                  tone: view.isDaycare
                      ? MemberChipTone.neutral
                      : MemberChipTone.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shopTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: MemberUi.cardTitleSize,
                      fontWeight: FontWeight.w700,
                      color: MemberUi.of(context).text,
                    ),
                  ),
                ),
                MemberStatusChip(
                  label: view.statusTitle,
                  tone: cancelled
                      ? MemberChipTone.danger
                      : completed
                      ? MemberChipTone.success
                      : MemberChipTone.warning,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              view.roomAssignmentLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: MemberUi.bodySize,
                fontWeight: FontWeight.w600,
                color: MemberUi.of(context).text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                view.dateRangeLabel,
                view.durationLabel,
              ].where((String item) => item.trim().isNotEmpty).join(' ・ '),
              style: TextStyle(
                fontSize: MemberUi.captionSize,
                color: MemberUi.of(context).muted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _softChip(context, petsText),
                _softChip(context, '#${view.bookingCode}'),
                _softChip(context, view.paymentMethodLabel),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        view.totalAmountLabel,
                        style: TextStyle(
                          fontSize: MemberUi.captionSize,
                          color: MemberUi.of(context).muted,
                        ),
                      ),
                      Text(
                        'NT\$ ${view.totalAmount}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MemberUi.of(context).text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        view.isPaidInFull
                            ? '已付清'
                            : view.remainingAmount > 0
                            ? '尚需付款 NT\$ ${view.remainingAmount}'
                            : view.paymentStatusLabel,
                        style: TextStyle(
                          fontSize: MemberUi.captionSize,
                          fontWeight: FontWeight.w600,
                          color: view.isPaidInFull
                              ? MemberUi.of(context).success
                              : view.remainingAmount > 0
                              ? MemberUi.of(context).primary
                              : MemberUi.of(context).muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (completed && !view.reviewed)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: MemberStatusChip(
                      label: '可評價',
                      tone: MemberChipTone.primary,
                    ),
                  ),
                Icon(Icons.chevron_right, color: MemberUi.of(context).muted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _softChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: MemberUi.of(context).muted),
      ),
    );
  }
}
