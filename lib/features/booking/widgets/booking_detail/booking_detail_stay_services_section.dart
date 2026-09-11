// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_stay_services_section.dart
// 功能說明：入住期間服務：每日照護、照片、攝影機；依入住狀態與下載期限顯示。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_device_service.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_download_page.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_page.dart';
import 'package:petnest_saas/features/booking/pages/customer_daily_care_photo_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:url_launcher/url_launcher.dart';

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

    if (view.isDaycare) {
      if (!daycareCareEnabled || view.status == 'cancelled') {
        return const SizedBox.shrink();
      }
    } else if (view.status != 'checked_in' && view.status != 'completed') {
      return const SizedBox.shrink();
    }

    if (view.status == 'completed' && expired) {
      return BookingDetailCard(
        child: Text(
          '照護照片下載期限已結束',
          style: TextStyle(
            fontSize: BookingDetailUi.bodySize,
            color: BookingDetailUi.of(context).muted,
          ),
        ),
      );
    }

    if (!canView) {
      return const SizedBox.shrink();
    }

    final String roomName = view.roomName;
    final String shopId = view.shopId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            view.isDaycare ? '本次安親回報' : '入住期間服務',
            style: TextStyle(
              fontSize: BookingDetailUi.sectionTitleSize,
              fontWeight: FontWeight.w700,
              color: BookingDetailUi.of(context).text,
            ),
          ),
        ),
        BookingDetailEntryRow(
          icon: Icons.pets_outlined,
          title: view.isDaycare ? '本次安親回報' : '每日照護紀錄',
          subtitle: view.isDaycare
              ? '查看本次安親回報'
              : (view.status == 'checked_in' ? '查看最新照護紀錄' : '查看住宿期間照護紀錄'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CustomerDailyCarePage(
                  shopId: shopId,
                  bookingId: bookingId,
                  roomName: roomName,
                  journalTitle: view.isDaycare ? '本次安親回報' : '每日照護紀錄',
                ),
              ),
            );
          },
        ),
        BookingDetailEntryRow(
          icon: Icons.photo_library_outlined,
          title: '照護照片',
          subtitle: deadline != null
              ? '可查看至 ${view.formatDateTime(deadline)}（實際結束後 24 小時）'
              : '上傳完成即可查看與下載預覽／高清版',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CustomerDailyCarePhotoPage(
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
        if (view.showCamera) _CameraEntry(view: view),
      ],
    );
  }
}

class _CameraEntry extends StatelessWidget {
  const _CameraEntry({required this.view});

  final BookingDetailViewData view;

  @override
  Widget build(BuildContext context) {
    final String shopId = view.shopId;
    final String roomId = (view.raw['roomId'] ?? '').toString().trim();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ShopDeviceService.instance.watchCameraDevicesByRoom(
        shopId: shopId,
        roomId: roomId,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError || !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            if (snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }
            final Map<String, dynamic> camera = snapshot.data!.docs.first
                .data();
            final String name = (camera['name'] ?? '房間攝影機').toString();
            final String url = (camera['url'] ?? '').toString().trim();
            if (url.isEmpty) {
              return const SizedBox.shrink();
            }
            return BookingDetailEntryRow(
              icon: Icons.videocam_outlined,
              title: name,
              subtitle: '開啟店家提供的攝影機畫面',
              onTap: () async {
                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('前往外部攝影機頁面'),
                      content: const Text('即將開啟店家提供的攝影機連結，請確認是否前往。'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('取消'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('前往'),
                        ),
                      ],
                    );
                  },
                );
                if (confirm != true) {
                  return;
                }
                final Uri? uri = Uri.tryParse(url);
                if (uri == null) {
                  return;
                }
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            );
          },
    );
  }
}
