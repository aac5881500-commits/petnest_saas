// 檔案名稱：lib/features/booking/pages/booking_stay_arrangement_page.dart
// 功能說明：查看訂單已儲存的入住／送達與接回時間，不另建表單。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

class BookingStayArrangementPage extends StatelessWidget {
  const BookingStayArrangementPage({super.key, required this.view});

  final BookingDetailViewData view;

  @override
  Widget build(BuildContext context) {
    return ShopFrontendThemeScope(
      shopId: view.shopId,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: BookingDetailUi.of(context).background,
          appBar: AppBar(
            title: Text(view.isDaycare ? '送達與接回安排' : '入住與接回安排'),
            backgroundColor: BookingDetailUi.of(context).background,
          ),
          body: BookingDetailUi.constrain(
            ListView(
              padding: const EdgeInsets.all(BookingDetailUi.pagePadding),
              children: <Widget>[
                BookingDetailCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _row(
                        context,
                        view.isDaycare ? '送達時間' : '入住日期',
                        view.isDaycare
                            ? view.formatDateTime(view.scheduledStartAt)
                            : view.formatDate(view.startDate),
                      ),
                      _row(
                        context,
                        view.isDaycare ? '預計接回' : '退房日期',
                        view.isDaycare
                            ? view.formatDateTime(view.scheduledEndAt)
                            : view.formatDate(view.endDate),
                      ),
                      if (view.actualStartAt != null)
                        _row(
                          context,
                          '實際開始',
                          view.formatDateTime(view.actualStartAt),
                        ),
                      if (view.actualEndAt != null)
                        _row(
                          context,
                          '實際結束',
                          view.formatDateTime(view.actualEndAt),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: BookingDetailUi.captionSize,
              color: BookingDetailUi.of(context).muted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: BookingDetailUi.bodySize,
              color: BookingDetailUi.of(context).text,
            ),
          ),
        ],
      ),
    );
  }
}
