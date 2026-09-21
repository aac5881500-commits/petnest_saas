// 檔案名稱：lib/core/models/daily_care_report_center_item.dart
// 功能說明：每日回報中心的一個回報場次資料模型（含房間看板顯示欄位）。

import 'daily_care_date_helper.dart';
import 'daily_care_entitlement.dart';
import 'daily_care_record_model.dart';

class DailyCareReportCenterItem {
  const DailyCareReportCenterItem({
    required this.id,
    required this.shopId,
    required this.bookingId,
    required this.sessionIndex,
    required this.sessionName,
    required this.recordDate,
    required this.entitlement,
    this.serviceType = DailyCareServiceTypes.accommodation,
    this.sourceCollection = 'bookings',
    this.roomId = '',
    this.roomName = '',
    this.roomTypeName = '',
    this.bookingCode = '',
    this.customerName = '',
    this.petIds = const <String>[],
    this.petNames = const <String>[],
    this.petPhotoUrl = '',
    this.checkInDate,
    this.checkOutDate,
    this.stayDayIndex,
    this.stayDayTotal,
    this.daycareStartAt,
    this.daycareEndAt,
    this.daycareTimeLabel = '',
    this.isCompleted = false,
    this.updatedAt,
    this.canOperate = true,
  });

  final String id;
  final String shopId;
  final String bookingId;
  final String sourceCollection;
  final String serviceType;
  final String roomId;
  final String roomName;
  final String roomTypeName;
  final String bookingCode;
  final String customerName;
  final List<String> petIds;
  final List<String> petNames;
  final String petPhotoUrl;
  final DateTime? checkInDate;
  final DateTime? checkOutDate;
  final int? stayDayIndex;
  final int? stayDayTotal;
  final DateTime? daycareStartAt;
  final DateTime? daycareEndAt;
  final String daycareTimeLabel;
  final DateTime recordDate;
  final int sessionIndex;
  final String sessionName;
  final bool isCompleted;
  final DateTime? updatedAt;
  final DailyCareEntitlement entitlement;
  final bool canOperate;

  bool get isDaycare => serviceType == DailyCareServiceTypes.daycare;

  String get typeLabel => isDaycare ? '安親' : '住宿';

  String get placeLabel {
    if (isDaycare) {
      return '安親';
    }
    return roomName.trim().isEmpty ? '住宿' : roomName.trim();
  }

  String get petNamesText {
    if (petNames.isEmpty) {
      return '';
    }
    return petNames.join('、');
  }

  String get petNamesShort {
    if (petNames.isEmpty) {
      return '';
    }
    if (petNames.length <= 2) {
      return petNames.join('、');
    }
    return '${petNames.take(2).join('、')} +${petNames.length - 2}';
  }

  String get stayDateText {
    if (checkInDate == null && checkOutDate == null) {
      return '';
    }
    if (checkInDate != null && checkOutDate != null) {
      return '${_dateText(checkInDate!)} ～ ${_dateText(checkOutDate!)}';
    }
    return _dateText(checkInDate ?? checkOutDate!);
  }

  String get stayProgressText {
    if (stayDayIndex == null || stayDayTotal == null || stayDayTotal! <= 0) {
      return '';
    }
    return '第 $stayDayIndex / $stayDayTotal 晚';
  }

  String get scheduleText {
    if (isDaycare) {
      return daycareTimeLabel.trim();
    }
    if (stayProgressText.isNotEmpty && stayDateText.isNotEmpty) {
      return '$stayDateText・$stayProgressText';
    }
    return stayDateText.isNotEmpty ? stayDateText : stayProgressText;
  }

  static String _dateText(DateTime value) {
    final DateTime day = DailyCareDateHelper.dateOnly(value);
    return '${day.month}/${day.day}';
  }

  DailyCareReportCenterItem copyWith({
    bool? isCompleted,
    DateTime? updatedAt,
    bool? canOperate,
  }) {
    return DailyCareReportCenterItem(
      id: id,
      shopId: shopId,
      bookingId: bookingId,
      sourceCollection: sourceCollection,
      serviceType: serviceType,
      roomId: roomId,
      roomName: roomName,
      roomTypeName: roomTypeName,
      bookingCode: bookingCode,
      customerName: customerName,
      petIds: petIds,
      petNames: petNames,
      petPhotoUrl: petPhotoUrl,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
      stayDayIndex: stayDayIndex,
      stayDayTotal: stayDayTotal,
      daycareStartAt: daycareStartAt,
      daycareEndAt: daycareEndAt,
      daycareTimeLabel: daycareTimeLabel,
      recordDate: recordDate,
      sessionIndex: sessionIndex,
      sessionName: sessionName,
      isCompleted: isCompleted ?? this.isCompleted,
      updatedAt: updatedAt ?? this.updatedAt,
      entitlement: entitlement,
      canOperate: canOperate ?? this.canOperate,
    );
  }
}
