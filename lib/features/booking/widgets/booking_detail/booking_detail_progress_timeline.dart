// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_progress_timeline.dart
// 功能說明：訂單完整進度時間軸（預設收合後展開）

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

class BookingDetailProgressTimeline extends StatelessWidget {
  const BookingDetailProgressTimeline({super.key, required this.view});

  final BookingDetailViewData view;

  @override
  Widget build(BuildContext context) {
    final List<BookingDetailTimelineItem> items = view.timeline;
    return Column(
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: items[i].active
                          ? BookingDetailUi.of(context).success
                          : BookingDetailUi.of(context).border,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (i != items.length - 1)
                    Container(
                      width: 2,
                      height: 28,
                      color: BookingDetailUi.of(context).border,
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        items[i].title,
                        style: TextStyle(
                          fontSize: BookingDetailUi.bodySize,
                          color: BookingDetailUi.of(context).text,
                        ),
                      ),
                      if (items[i].time != null)
                        Text(
                          view.formatDateTime(items[i].time),
                          style: TextStyle(
                            fontSize: BookingDetailUi.captionSize,
                            color: BookingDetailUi.of(context).muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
