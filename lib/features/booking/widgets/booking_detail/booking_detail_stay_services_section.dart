// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_stay_services_section.dart
// 功能說明：入住期間服務：每日照護、照片、攝影機；依入住狀態與下載期限顯示。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_download_page.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_page.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_photo_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:petnest_saas/features/booking/widgets/customer_camera_entry.dart';

class BookingDetailStayServicesSection extends StatelessWidget {
  const BookingDetailStayServicesSection({
    super.key,
    required this.view,
    required this.bookingId,
    required this.downloadHoursAfterCheckout,
    this.daycareCareEnabled = false,
  });

  final BookingDetailViewData view;
  final String bookingId;
  final int downloadHoursAfterCheckout;
  final bool daycareCareEnabled;

  @override
  Widget build(BuildContext context) {
    final bool canView = view.canViewDailyCare(
      downloadHoursAfterCheckout: downloadHoursAfterCheckout,
      daycareCareEnabled: daycareCareEnabled,
    );
    final bool expired = view.dailyCareDownloadExpired(
      downloadHoursAfterCheckout: downloadHoursAfterCheckout,
    );
    final DateTime? deadline = view.dailyCareDownloadDeadline(
      downloadHoursAfterCheckout,
    );

    final bool canViewRecord = view.canViewDailyCareRecord(
      daycareCareEnabled: daycareCareEnabled,
    );
    if (!canViewRecord) {
      return const SizedBox.shrink();
    }

    if (!canView) {
      final bool tellExpired =
          expired ||
          (view.isDaycare &&
              (view.status == 'completed' || view.status == 'checked_out'));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle(context),
          _journalRow(context),
          if (tellExpired)
            BookingDetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '照片保存期限已結束',
                    style: TextStyle(
                      fontSize: BookingDetailUi.bodySize,
                      fontWeight: FontWeight.w700,
                      color: BookingDetailUi.of(context).text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '照護紀錄仍會保留，照片已依保存期限自動清除。',
                    style: TextStyle(
                      fontSize: BookingDetailUi.bodySize,
                      color: BookingDetailUi.of(context).muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    final String roomName = view.roomName;
    final String shopId = view.shopId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionTitle(context),
        _journalRow(context),
        BookingDetailEntryRow(
          icon: Icons.photo_library_outlined,
          title: '照護照片',
          subtitle: deadline != null
              ? '上傳完成即可查看與下載，可使用至 ${view.formatDateTime(deadline)}'
              : '上傳完成即可查看與下載預覽／高清版',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CustomerDailyCarePhotoPage(
                  shopId: shopId,
                  bookingId: bookingId,
                  roomName: roomName,
                ),
              ),
            );
          },
        ),
        BookingDetailEntryRow(
          icon: Icons.download_outlined,
          title: '全部下載',
          subtitle: deadline != null
              ? '實際結束後仍可下載至 ${view.formatDateTime(deadline)}'
              : '不限次數；短時間內請避免重複點擊',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CustomerDailyCareDownloadPage(
                  shopId: shopId,
                  bookingId: bookingId,
                  roomName: roomName,
                ),
              ),
            );
          },
        ),
        if (view.showCamera) CustomerCameraDetailEntry(bookingId: bookingId),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        view.isDaycare ? '本次安親回報' : '入住期間服務',
        style: TextStyle(
          fontSize: BookingDetailUi.sectionTitleSize,
          fontWeight: FontWeight.w700,
          color: BookingDetailUi.of(context).text,
        ),
      ),
    );
  }

  Widget _journalRow(BuildContext context) {
    return BookingDetailEntryRow(
      icon: Icons.pets_outlined,
      title: view.isDaycare ? '本次安親回報' : '每日照護紀錄',
      subtitle: view.isDaycare
          ? '查看本次安親回報'
          : (view.status == 'checked_in'
                ? '查看最新照護紀錄'
                : '查看住宿期間照護紀錄'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CustomerDailyCarePage(
              shopId: view.shopId,
              bookingId: bookingId,
              roomName: view.roomName,
              journalTitle: view.isDaycare ? '本次安親回報' : '每日照護紀錄',
            ),
          ),
        );
      },
    );
  }
}
