// 檔案名稱：lib/core/models/daily_care_report_center_item.dart
// 功能說明：每日回報中心的一個回報場次資料模型。

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
    this.customerName = '',
    this.petIds = const <String>[],
    this.petNames = const <String>[],
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
  final String customerName;
  final List<String> petIds;
  final List<String> petNames;
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
      customerName: customerName,
      petIds: petIds,
      petNames: petNames,
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
