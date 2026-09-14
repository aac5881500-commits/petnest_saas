// 檔案名稱：lib/features/shop/widgets/daily_care_full_journal_preview.dart
// 功能說明：設定頁即時預覽。示範 Booking／權益／紀錄，共用客戶端 renderer，不讀寫 Firestore。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_entitlement.dart';
import '../../../core/models/daily_care_photo_model.dart';
import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_report_mode.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/models/daily_care_stay_info.dart';
import '../../../core/widgets/daily_care_card_surface.dart';
import '../../../core/widgets/daily_care_journal_renderer.dart';

class DailyCareJournalDemoData {
  const DailyCareJournalDemoData({
    required this.stay,
    required this.entitlement,
    required this.record,
    required this.dateKeys,
    required this.sessionTabs,
    required this.photos,
  });

  final DailyCareStayInfo stay;
  final DailyCareEntitlement entitlement;
  final DailyCareRecordModel record;
  final List<String> dateKeys;
  final List<DailyCareJournalSessionTab> sessionTabs;
  final List<DailyCarePhotoModel> photos;

  static const double phoneLogicalWidth = 390;

  static DailyCareJournalDemoData build({
    required DailyCareSettingModel setting,
    required bool isDaycare,
    required List<String> sessionLabels,
    required int sessionIndex,
    required String selectedDateKey,
    required bool showPhotos,
  }) {
    final DailyCareStayInfo stay = DailyCareStayInfo(
      roomName: isDaycare ? '安親區' : 'A1',
      pets: const <DailyCareStayPet>[
        DailyCareStayPet(name: '小米', photoUrl: ''),
      ],
      startDate: DateTime(2026, 9, 16),
      endDate: isDaycare ? DateTime(2026, 9, 16) : DateTime(2026, 9, 18),
    );
    final List<String> dateKeys = isDaycare
        ? const <String>['2026/09/16']
        : stay.careDateKeys();
    final DateTime recordDate = _parseDateKey(selectedDateKey) ??
        DateTime(2026, 9, 16);
    final List<String> labels = sessionLabels.isEmpty
        ? <String>[setting.sessionLabel(0)]
        : sessionLabels;
    final List<DailyCareJournalSessionTab> tabs =
        List<DailyCareJournalSessionTab>.generate(labels.length, (int index) {
          return DailyCareJournalSessionTab(
            sessionIndex: index,
            sessionName: labels[index],
          );
        });
    final int safeSession = sessionIndex.clamp(0, tabs.length - 1);
    final DailyCareEntitlement entitlement = DailyCareEntitlement(
      enabled: true,
      service: isDaycare ? 'daycare' : 'accommodation',
      finalReports: tabs.length,
      sessionLabels: labels,
      serviceDates: dateKeys,
      offerName: isDaycare ? '示範安親' : '示範房間',
      careDateRule: isDaycare
          ? DailyCareEntitlement.daycareCareDateRule
          : DailyCareEntitlement.stayCareDateRule,
    );
    final DailyCareRecordModel record = DailyCareRecordModel(
      id: 'demo-record',
      shopId: 'demo-shop',
      bookingId: 'demo-booking',
      roomId: 'demo-room',
      roomName: stay.roomName,
      recordDate: recordDate,
      sessionIndex: safeSession,
      sessionName: tabs[safeSession].sessionName,
      values: _demoValues(setting),
      petNotes: const <String, String>{},
      photoCount: showPhotos ? 3 : 0,
      createdAt: DateTime(2026, 9, 16, 10, 32),
      updatedAt: DateTime(2026, 9, 16, 10, 32),
      serviceType: isDaycare
          ? DailyCareServiceTypes.daycare
          : DailyCareServiceTypes.accommodation,
    );
    final List<DailyCarePhotoModel> photos = showPhotos
        ? List<DailyCarePhotoModel>.generate(3, (int index) {
            return DailyCarePhotoModel(
              id: 'demo-photo-$index',
              shopId: 'demo-shop',
              bookingId: 'demo-booking',
              roomId: 'demo-room',
              roomName: stay.roomName,
              recordDate: recordDate,
              sessionIndex: safeSession,
              sessionName: tabs[safeSession].sessionName,
              previewUrl: '',
              previewStoragePath: '',
              createdAt: DateTime(2026, 9, 16, 10, 32),
            );
          })
        : const <DailyCarePhotoModel>[];
    return DailyCareJournalDemoData(
      stay: stay,
      entitlement: entitlement,
      record: record,
      dateKeys: dateKeys,
      sessionTabs: tabs,
      photos: photos,
    );
  }

  static Map<String, dynamic> _demoValues(DailyCareSettingModel setting) {
    const Map<String, String> samples = <String, String>{
      'water': '一般',
      'dryFood': '有',
      'wetFood': '少',
      'snack': '無',
      'stool': '正常',
      'urine': '正常',
      'wandToy': '有',
      'scratchBoard': '有',
      'jumpPlatform': '無',
      'toyBall': '有',
      'catHouse': '有',
      'catnip': '無',
      'silverVine': '無',
      'catGrass': '有',
      'temperature': '26',
      'humidity': '55',
      'generalNote': '今天整體狀況良好，活動量正常。',
    };
    final Map<String, dynamic> values = <String, dynamic>{};
    for (final String key in setting.enabledFields) {
      values[key] = samples[key] ?? '有';
    }
    for (final DailyCareCustomField field in setting.customFields) {
      values[field.id] = field.inputType == 'text' ? '示範文字' : '正常';
    }
    return values;
  }

  static DateTime? _parseDateKey(String value) {
    final List<String> parts = value.split('/');
    if (parts.length != 3) {
      return null;
    }
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }
}

class DailyCareFullJournalPreview extends StatefulWidget {
  const DailyCareFullJournalPreview({
    super.key,
    required this.setting,
    required this.isDaycare,
    required this.sessionLabels,
    required this.sessionIndex,
    this.showPhotos = true,
    this.usePhoneFrame = true,
  });

  final DailyCareSettingModel setting;
  final bool isDaycare;
  final List<String> sessionLabels;
  final int sessionIndex;
  final bool showPhotos;
  final bool usePhoneFrame;

  @override
  State<DailyCareFullJournalPreview> createState() =>
      _DailyCareFullJournalPreviewState();
}

class _DailyCareFullJournalPreviewState
    extends State<DailyCareFullJournalPreview> {
  String? _selectedDateKey;

  @override
  void didUpdateWidget(DailyCareFullJournalPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDaycare != widget.isDaycare) {
      _selectedDateKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DailyCareJournalDemoData demo = DailyCareJournalDemoData.build(
      setting: widget.setting,
      isDaycare: widget.isDaycare,
      sessionLabels: widget.sessionLabels,
      sessionIndex: widget.sessionIndex,
      selectedDateKey: _selectedDateKey ?? '',
      showPhotos: widget.showPhotos && widget.setting.photoEnabled,
    );
    final String selectedDateKey =
        _selectedDateKey != null && demo.dateKeys.contains(_selectedDateKey)
        ? _selectedDateKey!
        : demo.dateKeys.first;
    final Widget journal = Stack(
      children: <Widget>[
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFFEDE7E0)),
        ),
        Positioned.fill(
          child: DailyCareJournalPageBackground(setting: widget.setting),
        ),
        DailyCareJournalRenderer(
          setting: widget.setting,
          stay: demo.stay,
          dateKeys: demo.dateKeys,
          selectedDateKey: selectedDateKey,
          sessionTabs: demo.sessionTabs,
          selectedSessionIndex: widget.sessionIndex.clamp(
            0,
            demo.sessionTabs.length - 1,
          ),
          record: demo.record,
          fallbackRoomName: demo.stay.roomName,
          photos: demo.photos,
          photosLoading: false,
          showPhotoSection: widget.setting.photoEnabled,
          onDateSelected: (String dateKey) {
            setState(() {
              _selectedDateKey = dateKey;
            });
          },
          onSessionSelected: null,
        ),
      ],
    );

    if (!widget.usePhoneFrame) {
      return journal;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 720;
        return Center(
          child: SizedBox(
            width: DailyCareJournalDemoData.phoneLogicalWidth,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF2C241C),
                borderRadius: BorderRadius.circular(36),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: journal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DailyCarePreviewSession {
  const DailyCarePreviewSession();

  static List<String> labelsFor(
    DailyCareSettingModel setting, {
    required bool isDaycare,
    String offerId = '',
  }) {
    final String mode = isDaycare
        ? setting.daycareReportMode
        : setting.stayReportMode;
    if (mode == DailyCareReportMode.paidAddon) {
      return (isDaycare ? setting.daycarePaidPlan : setting.stayPaidPlan)
          .resolvedLabels();
    }
    if (mode == DailyCareReportMode.includedByOffer) {
      final quota = isDaycare
          ? setting.daycareOfferQuotas[offerId]
          : setting.stayOfferQuotas[offerId];
      if (quota == null || !quota.configured) {
        return const <String>['尚未設定此房型／方案場次'];
      }
      return quota.resolvedLabels();
    }
    return isDaycare
        ? setting.resolvedDaycareSessionLabelsForCount(
            setting.daycareSessionCount,
          )
        : setting.resolvedStaySessionLabelsForCount(setting.sessionCount);
  }
}
