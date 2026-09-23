// 檔案名稱：lib/features/shop/pages/daily_care_report_center_page.dart
// 功能說明：店家今日每日照護回報中心入口，沿用既有填寫頁與即時 snapshot。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_date_helper.dart';
import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_report_center_item.dart';
import '../../../core/models/daily_care_report_center_snapshot.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_report_center_service.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../../room/daily_care_record_edit_launcher.dart';
import '../widgets/daily_care_report_center_board.dart';

class DailyCareReportCenterPage extends StatefulWidget {
  const DailyCareReportCenterPage({
    super.key,
    required this.shopId,
    this.canOperate = true,
    this.focusBookingId = '',
    this.focusRoomId = '',
    this.focusRoomName = '',
    this.focusRoomTypeName = '',
    this.focusCheckIn,
    this.focusCheckOut,
  });

  final String shopId;
  final bool canOperate;
  final String focusBookingId;
  final String focusRoomId;
  final String focusRoomName;
  final String focusRoomTypeName;
  final DateTime? focusCheckIn;
  final DateTime? focusCheckOut;

  @override
  State<DailyCareReportCenterPage> createState() =>
      _DailyCareReportCenterPageState();
}

class _DailyCareReportCenterPageState extends State<DailyCareReportCenterPage> {
  int _retry = 0;
  late DailyCareReportCenterStatusFilter _status;

  @override
  void initState() {
    super.initState();
    _status = widget.focusBookingId.trim().isEmpty
        ? DailyCareReportCenterStatusFilter.pending
        : DailyCareReportCenterStatusFilter.all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('每日回報中心')),
      body: StreamBuilder<DailyCareSettingModel>(
        key: ValueKey<int>(_retry),
        stream: DailyCareSettingService.instance.streamSetting(widget.shopId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<DailyCareSettingModel> settingSnap,
            ) {
              if (settingSnap.hasError) {
                return DailyCareReportCenterErrorPane(onRetry: _reload);
              }
              final DailyCareSettingModel setting =
                  settingSnap.data ?? const DailyCareSettingModel();
              if (settingSnap.connectionState == ConnectionState.waiting &&
                  settingSnap.data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!setting.enabled && !setting.daycareEnabled) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '每日回報功能目前未啟用',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }
              return StreamBuilder<DailyCareReportCenterSnapshot>(
                stream: DailyCareReportCenterService.instance.streamToday(
                  shopId: widget.shopId,
                  canOperate: widget.canOperate,
                ),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<DailyCareReportCenterSnapshot> snap,
                    ) {
                      if (snap.hasError || (snap.data?.hasError ?? false)) {
                        return DailyCareReportCenterErrorPane(onRetry: _reload);
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final DailyCareReportCenterSnapshot data = snap.data!;
                      if (!data.settingEnabled) {
                        return const Center(
                          child: Text(
                            '每日回報功能目前未啟用',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      final DailyCareReportCenterSnapshot view =
                          _focusedSnapshot(data);
                      if (widget.focusBookingId.trim().isNotEmpty &&
                          view.items.isEmpty) {
                        return _focusFallback(setting);
                      }
                      return DailyCareReportCenterBoard(
                        snapshot: view,
                        setting: setting,
                        status: _status,
                        onStatus: (DailyCareReportCenterStatusFilter value) {
                          setState(() {
                            _status = value;
                          });
                        },
                      );
                    },
              );
            },
      ),
    );
  }

  DailyCareReportCenterSnapshot _focusedSnapshot(
    DailyCareReportCenterSnapshot data,
  ) {
    final String bookingId = widget.focusBookingId.trim();
    if (bookingId.isEmpty) {
      return data;
    }
    final String roomId = widget.focusRoomId.trim();
    return DailyCareReportCenterSnapshot.fromItems(
      data.items.where((DailyCareReportCenterItem item) {
        if (item.bookingId != bookingId) {
          return false;
        }
        if (roomId.isEmpty) {
          return true;
        }
        return item.roomId == roomId || item.roomId.isEmpty;
      }).toList(),
      settingEnabled: data.settingEnabled,
    );
  }

  Widget _focusFallback(DailyCareSettingModel setting) {
    final String typeName = widget.focusRoomTypeName.trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              typeName.isEmpty
                  ? '此訂單今日沒有待填場次，仍可進入既有填寫頁'
                  : '此訂單（$typeName）今日沒有待填場次，仍可進入既有填寫頁',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                DailyCareRecordEditLauncher.open(
                  context: context,
                  shopId: widget.shopId,
                  bookingId: widget.focusBookingId,
                  recordDate: _focusRecordDate(),
                  sessionIndex: 0,
                  roomId: widget.focusRoomId,
                  roomName: widget.focusRoomName,
                  serviceType: DailyCareServiceTypes.accommodation,
                  setting: setting,
                );
              },
              child: const Text('前往每日照護填寫'),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _focusRecordDate() {
    final DateTime today = DailyCareDateHelper.todayInTaipei();
    if (DailyCareDateHelper.isCareDate(
      date: today,
      checkIn: widget.focusCheckIn,
      checkOut: widget.focusCheckOut,
    )) {
      return DailyCareDateHelper.dateOnly(today);
    }
    if (widget.focusCheckIn != null) {
      return DailyCareDateHelper.dateOnly(widget.focusCheckIn!);
    }
    return today;
  }

  void _reload() {
    setState(() {
      _retry += 1;
    });
  }
}

class DailyCareReportCenterMenuCopy {
  DailyCareReportCenterMenuCopy._();

  static String subtitle({
    required bool profileComplete,
    required DailyCareReportCenterSnapshot snapshot,
  }) {
    if (!profileComplete) {
      return '請先完成基本資料';
    }
    if (snapshot.pendingCount <= 0) {
      return '今日回報已完成';
    }
    return '待填 ${snapshot.pendingCount} 場・已完成 ${snapshot.completedCount} 場';
  }
}
