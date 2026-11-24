// 檔案名稱：lib/features/room/daily_care_record_edit_launcher.dart
// 功能說明：開啟既有每日照護填寫頁（住宿房務與安親回報共用）

import 'package:flutter/material.dart';

import '../../core/models/daily_care_entitlement.dart';
import '../../core/models/daily_care_record_model.dart';
import '../../core/models/daily_care_setting_model.dart';
import '../../core/services/daily_care_report_eligibility.dart';
import '../../core/services/daily_care_setting_service.dart';
import 'pages/daily_care_record_edit_page.dart';

class DailyCareRecordEditLauncher {
  DailyCareRecordEditLauncher._();

  static Future<bool?> open({
    required BuildContext context,
    required String shopId,
    required String bookingId,
    required DateTime recordDate,
    required int sessionIndex,
    String roomId = '',
    String roomName = '',
    String serviceType = DailyCareServiceTypes.accommodation,
    List<String> petIds = const <String>[],
    DailyCareSettingModel? setting,
    DailyCareEntitlement? entitlement,
    bool readOnly = false,
    bool asDialog = false,
  }) async {
    final DailyCareSettingModel resolved =
        setting ?? await DailyCareSettingService.instance.getSetting(shopId);
    if (!context.mounted) {
      return null;
    }
    final bool daycare = serviceType == DailyCareServiceTypes.daycare;
    if (entitlement != null &&
        !DailyCareReportEligibility.isEntitled(entitlement)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本訂單未包含每日照護回報')));
      return null;
    }
    final String fromEntitlement =
        entitlement?.sessionLabelAt(sessionIndex).trim() ?? '';
    final String sessionName = fromEntitlement.isNotEmpty
        ? fromEntitlement
        : (daycare
              ? resolved.daycareSessionLabelAt(sessionIndex)
              : resolved.sessionLabelAt(sessionIndex));
    Widget editor(BuildContext context) => DailyCareRecordEditPage(
      shopId: shopId,
      bookingId: bookingId,
      roomId: roomId,
      roomName: roomName,
      recordDate: recordDate,
      sessionIndex: sessionIndex,
      sessionName: sessionName,
      customFields: resolved.customFields,
      enabledFields: resolved.enabledFields,
      photoEnabled: resolved.photoEnabled,
      serviceType: serviceType,
      petIds: petIds,
      entitlement: entitlement,
      readOnly: readOnly,
    );
    if (asDialog) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 20,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            width: 1000,
            height: MediaQuery.sizeOf(context).height * .9,
            child: editor(context),
          ),
        ),
      );
    }
    return Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: editor));
  }
}
