// 檔案名稱：lib/features/room/pages/daily_care_record_edit_page.dart
// 功能說明：整頁開啟一房一天一場的共同照護紀錄填寫表單。
// 🐾 每日照護紀錄填寫頁
// 實際填寫內容由 DailyCareRecordEditor 提供，
// 桌機每日回報右側快速處理面板共用同一個元件。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_entitlement.dart';
import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../widgets/daily_care_record_editor.dart';

class DailyCareRecordEditPage extends StatelessWidget {
  const DailyCareRecordEditPage({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.roomId,
    required this.customFields,
    required this.roomName,
    required this.recordDate,
    required this.sessionIndex,
    required this.sessionName,
    required this.enabledFields,
    required this.photoEnabled,
    this.serviceType = DailyCareServiceTypes.accommodation,
    this.petIds = const <String>[],
    this.entitlement,
    this.readOnly = false,
  });

  final String shopId;
  final String bookingId;
  final String roomId;
  final String roomName;
  final DateTime recordDate;
  final bool photoEnabled;
  final int sessionIndex;
  final String sessionName;
  final List<DailyCareCustomField> customFields;

  /// 店主在「每日照護紀錄設定」勾選的自選欄位。
  ///
  /// 室內溫度、室內濕度不在這裡，
  /// 因為兩者為系統固定必填欄位。
  final List<String> enabledFields;
  final String serviceType;
  final List<String> petIds;
  final DailyCareEntitlement? entitlement;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(title: Text('$sessionName照護紀錄')),
      body: DailyCareRecordEditor(
        shopId: shopId,
        bookingId: bookingId,
        roomId: roomId,
        roomName: roomName,
        recordDate: recordDate,
        sessionIndex: sessionIndex,
        sessionName: sessionName,
        customFields: customFields,
        enabledFields: enabledFields,
        photoEnabled: photoEnabled,
        serviceType: serviceType,
        petIds: petIds,
        entitlement: entitlement,
        readOnly: readOnly,
      ),
    );
  }
}
