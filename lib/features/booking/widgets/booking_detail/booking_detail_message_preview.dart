// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_message_preview.dart
// 功能說明：訂單留言精簡卡：最新摘要、未讀數，點擊進入完整留言頁。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/pages/booking_message_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

class BookingDetailMessagePreview extends StatelessWidget {
  const BookingDetailMessagePreview({
    super.key,
    required this.view,
    required this.bookingId,
    this.sectionKey,
  });

  final BookingDetailViewData view;
  final String bookingId;
  final Key? sectionKey;

  @override
  Widget build(BuildContext context) {
    final String subtitle = view.lastMessageText.isEmpty
        ? '查看全部／聯絡店家'
        : view.lastMessageText;
    final String time = view.lastMessageAt == null
        ? ''
        : view.formatDateTime(view.lastMessageAt);

    return KeyedSubtree(
      key: sectionKey,
      child: BookingDetailCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => BookingMessagePage(
                bookingId: bookingId,
                bookingStatus: view.status,
                senderType: 'customer',
                shopId: view.shopId,
              ),
            ),
          );
        },
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const BookingDetailSectionTitle('訂單留言'),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: BookingDetailUi.bodySize,
                      color: BookingDetailUi.of(context).muted,
                    ),
                  ),
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: BookingDetailUi.captionSize,
                        color: BookingDetailUi.of(context).muted,
                      ),
                    ),
                ],
              ),
            ),
            if (view.customerUnreadCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: BookingDetailUi.of(context).primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${view.customerUnreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            Icon(Icons.chevron_right, color: BookingDetailUi.of(context).muted),
          ],
        ),
      ),
    );
  }
}
