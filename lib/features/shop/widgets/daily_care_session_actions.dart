// 檔案名稱：lib/features/shop/widgets/daily_care_session_actions.dart
// 功能說明：每日回報場次的顧客端預覽與分享本場。未完成不可分享。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/daily_care_date_helper.dart';
import '../../../core/models/daily_care_journal_appearance.dart';
import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_report_center_item.dart';
import '../../../core/models/daily_care_report_data.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/models/daily_care_stay_info.dart';
import '../../../core/services/daily_care_record_service.dart';
import '../../../core/services/daily_care_report_export_service.dart';
import '../../../core/widgets/platform_media_library_scope.dart';
import '../../booking/pages/customer_daily_care_page.dart';

/// 手機與桌機共用的兩顆操作。分享只在場次已完成時可按。
class DailyCareSessionActionButtons extends StatelessWidget {
  const DailyCareSessionActionButtons({
    super.key,
    required this.completed,
    required this.onPreview,
    required this.onShare,
  });

  final bool completed;
  final VoidCallback? onPreview;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton(
            key: const ValueKey<String>('daily-care-customer-preview'),
            onPressed: onPreview,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '顧客端預覽',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            key: const ValueKey<String>('daily-care-share-session'),
            onPressed: completed ? onShare : null,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '分享本場',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

void openDailyCareCustomerPreview(
  BuildContext context,
  DailyCareReportCenterItem item,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return CustomerDailyCarePage(
          shopId: item.shopId,
          bookingId: item.bookingId,
          roomName: item.roomName,
          previewMode: true,
          initialDate: item.recordDate,
          initialSessionIndex: item.sessionIndex,
          journalTitle: DailyCareCustomerPreviewCopy.title,
        );
      },
    ),
  );
}

/// 已完成場次才產出精簡分享圖，並沿用既有下載／分享。
Future<void> shareDailyCareSession({
  required BuildContext context,
  required DailyCareReportCenterItem item,
  required DailyCareSettingModel setting,
}) async {
  if (!item.isCompleted) {
    return;
  }
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  final DialogRoute<void> dialog = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return const Center(child: CircularProgressIndicator());
    },
  );
  navigator.push(dialog);
  void closeDialog() {
    if (dialog.isActive) {
      navigator.removeRoute(dialog);
    }
  }

  try {
    final _LoadedShare loaded = await _loadShare(item: item, setting: setting);
    closeDialog();
    if (!context.mounted) {
      return;
    }
    await exportDailyCarePoster(
      context: context,
      data: loaded.data,
      setting: setting,
      guestName: item.customerName,
      daycare: item.isDaycare,
    );
    if (!context.mounted) {
      return;
    }
    final String done = kIsWeb ? '分享圖已產生，開始下載。' : '分享圖已產生，請選擇儲存或分享位置。';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
  } catch (error) {
    closeDialog();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('產生分享圖失敗：$error')));
    }
  }
}

Future<void> exportDailyCarePoster({
  required BuildContext context,
  required DailyCareReportData data,
  required DailyCareSettingModel setting,
  required String guestName,
  bool daycare = false,
}) async {
  final DailyCareReportExportService export =
      DailyCareReportExportService.instance;
  final ImageProvider? logo = await export.preloadLogo(
    context,
    data.shopLogoUrl,
  );
  if (!context.mounted) {
    return;
  }
  final DailyCareResolvedPageLook look = DailyCareJournalAppearance.pageLook(
    setting,
    assetLookup: (String id) => PlatformMediaLibraryScope.lookup(context, id),
  );
  final ImageProvider? background = look.hasImage
      ? await export.preloadLogo(context, look.resolvedUrl)
      : null;
  if (!context.mounted) {
    return;
  }
  await export.exportPng(
    context: context,
    data: data,
    logoProvider: logo,
    fileName: export.fileName(data: data),
    journalSetting: setting,
    backgroundProvider: background,
    guestName: guestName,
    daycare: daycare,
  );
}

List<DailyCareRecordModel> completedSessionRecords({
  required List<DailyCareRecordModel> records,
  required DateTime onlyDate,
  int? onlySessionIndex,
}) {
  final String key = DailyCareDateHelper.dateKey(onlyDate);
  return records.where((DailyCareRecordModel record) {
    if (record.completedAt == null) {
      return false;
    }
    if (onlySessionIndex != null && record.sessionIndex != onlySessionIndex) {
      return false;
    }
    final String recordKey = DailyCareDateHelper.dateKey(
      DailyCareDateHelper.calendarDateInTaipei(record.recordDate),
    );
    return recordKey == key;
  }).toList();
}

class _LoadedShare {
  const _LoadedShare({required this.data});

  final DailyCareReportData data;
}

Future<_LoadedShare> _loadShare({
  required DailyCareReportCenterItem item,
  required DailyCareSettingModel setting,
}) async {
  final String collection = item.sourceCollection.trim().isEmpty
      ? 'bookings'
      : item.sourceCollection.trim();
  final DocumentSnapshot<Map<String, dynamic>> bookingSnap =
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(item.bookingId)
          .get();
  final DocumentSnapshot<Map<String, dynamic>> shopSnap =
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(item.shopId)
          .get();
  final Map<String, dynamic> booking =
      bookingSnap.data() ?? <String, dynamic>{};
  final Map<String, dynamic> shop = shopSnap.data() ?? <String, dynamic>{};
  final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(
    booking,
    fallbackRoomName: item.roomName,
    shopLogoUrl: (shop['logoUrl'] ?? '').toString().trim(),
  );
  final int sessionCount = item.entitlement.finalReports > 0
      ? item.entitlement.finalReports
      : setting.sessionCount;
  final List<DailyCareRecordModel> records = await DailyCareRecordService
      .instance
      .streamBookingRecords(
        bookingId: item.bookingId,
        shopId: item.shopId,
        sessionCount: sessionCount < 1 ? 1 : sessionCount,
      )
      .first;
  final List<DailyCareRecordModel> scoped = completedSessionRecords(
    records: records,
    onlyDate: item.recordDate,
    onlySessionIndex: item.sessionIndex,
  );
  if (scoped.isEmpty) {
    throw StateError('尚未完成的場次不能分享');
  }
  final DailyCareReportData data = DailyCareReportExportService.instance
      .buildReport(
        booking: booking,
        shop: shop,
        stay: stay,
        setting: setting,
        records: scoped,
        onlyDate: item.recordDate,
        kind: DailyCareReportExportKind.singleDay,
      );
  return _LoadedShare(data: data);
}
