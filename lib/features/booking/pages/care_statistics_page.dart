// 檔案名稱：lib/features/booking/pages/care_statistics_page.dart
// 功能說明：整筆訂單照護統計頁。顧客端與店主端共用同一畫面，只讀既有回報。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_record_service.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../../../core/services/daily_care_statistics_service.dart';
import '../../../core/widgets/daily_care_journal_renderer.dart';
import '../widgets/care_statistics_view.dart';

void openCareStatisticsPage(
  BuildContext context, {
  required String shopId,
  required String bookingId,
  bool isAdmin = false,
  bool useShopQuery = false,
  String sourceCollection = 'bookings',
}) {
  final String collection = sourceCollection.trim().isEmpty
      ? 'bookings'
      : sourceCollection.trim();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return CareStatisticsPage(
          shopId: shopId,
          bookingId: bookingId,
          isAdmin: isAdmin,
          useShopQuery: useShopQuery,
          sourceCollection: collection,
        );
      },
    ),
  );
}

class CareStatisticsPage extends StatelessWidget {
  const CareStatisticsPage({
    super.key,
    required this.shopId,
    required this.bookingId,
    this.isAdmin = false,
    this.useShopQuery = false,
    this.sourceCollection = 'bookings',
  });

  final String shopId;
  final String bookingId;
  final bool isAdmin;
  final bool useShopQuery;
  final String sourceCollection;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DailyCareSettingModel>(
      stream: DailyCareSettingService.instance.streamSetting(shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DailyCareSettingModel> settingSnap,
          ) {
            final DailyCareSettingModel setting =
                settingSnap.data ?? const DailyCareSettingModel();
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(sourceCollection)
                  .doc(bookingId)
                  .snapshots(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                    bookingSnap,
                  ) {
                    if (bookingSnap.hasError) {
                      return _scaffold(const Text('讀取訂單失敗'));
                    }
                    if (!bookingSnap.hasData) {
                      return _scaffold(const CircularProgressIndicator());
                    }
                    if (bookingSnap.data?.exists != true) {
                      return _scaffold(const Text('找不到這筆訂單'));
                    }
                    final Map<String, dynamic> booking =
                        bookingSnap.data?.data() ?? <String, dynamic>{};
                    final DailyCareStatisticsScope scope =
                        DailyCareStatisticsScope.fromBooking(
                          bookingId: bookingId,
                          booking: booking,
                          setting: setting,
                        );
                    return StreamBuilder<List<DailyCareRecordModel>>(
                      stream: DailyCareRecordService.instance
                          .streamBookingRecords(
                            bookingId: bookingId,
                            shopId: useShopQuery ? shopId : null,
                            careDates: scope.careDates,
                            sessionCount: scope.sessionCount,
                          ),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<DailyCareRecordModel>>
                            recordSnap,
                          ) {
                            if (recordSnap.hasError) {
                              return _scaffold(const Text('讀取照護回報失敗'));
                            }
                            if (!recordSnap.hasData) {
                              return _scaffold(
                                const CircularProgressIndicator(),
                              );
                            }
                            final String code = (booking['bookingCode'] ?? '')
                                .toString()
                                .trim();
                            return _scaffold(
                              CareStatisticsBody(
                                request: scope.request,
                                records:
                                    recordSnap.data ??
                                    const <DailyCareRecordModel>[],
                                adminCaption: isAdmin && code.isNotEmpty
                                    ? '訂單 $code'
                                    : '',
                              ),
                            );
                          },
                    );
                  },
            );
          },
    );
  }

  Widget _scaffold(Widget body) {
    const Color ink = DailyCareJournalThemeTokens.headerInk;
    const Color cream = DailyCareJournalThemeTokens.cream;
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('本次照護統計'),
        backgroundColor: cream,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: body,
    );
  }
}
