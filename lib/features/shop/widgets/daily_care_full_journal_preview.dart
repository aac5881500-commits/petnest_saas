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
    bool singleDayMode = false,
    bool singleSessionMode = false,
  }) {
    final bool oneDay = singleDayMode || isDaycare;
    final DailyCareStayInfo stay = DailyCareStayInfo(
      roomName: isDaycare ? '安親區' : 'A1',
      pets: const <DailyCareStayPet>[
        DailyCareStayPet(name: '小米', photoUrl: ''),
      ],
      startDate: DateTime(2026, 9, 16),
      endDate: oneDay ? DateTime(2026, 9, 16) : DateTime(2026, 9, 18),
    );
    final List<String> dateKeys = oneDay
        ? const <String>['2026/09/16']
        : stay.careDateKeys();
    final DateTime recordDate =
        _parseDateKey(selectedDateKey) ?? DateTime(2026, 9, 16);
    final List<String> labels = singleSessionMode
        ? <String>[
            sessionLabels.isNotEmpty && sessionLabels.first.trim().isNotEmpty
                ? sessionLabels.first.trim()
                : '上午場',
          ]
        : const <String>['上午場', '下午場', '晚上場'];
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
      'water': '正常',
      'dryFood': '正常',
      'wetFood': '偏少',
      'snack': '正常',
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
      'temperature': '28',
      'humidity': '60',
      'generalNote': '今天整體狀況良好，活動量正常。',
    };
    final Map<String, dynamic> values = <String, dynamic>{};
    for (final String key in setting.enabledFields) {
      values[key] = samples[key] ?? '有';
    }
    values['stool'] = samples['stool'];
    values['urine'] = samples['urine'];
    values['temperature'] = '28';
    values['humidity'] = '60';
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

class DailyCarePreviewPhoneSize {
  const DailyCarePreviewPhoneSize({
    required this.id,
    required this.label,
    required this.size,
  });

  final String id;
  final String label;
  final Size size;

  static const DailyCarePreviewPhoneSize small = DailyCarePreviewPhoneSize(
    id: 'small',
    label: '小手機',
    size: Size(360, 780),
  );
  static const DailyCarePreviewPhoneSize standard = DailyCarePreviewPhoneSize(
    id: 'standard',
    label: '標準手機',
    size: Size(393, 852),
  );
  static const DailyCarePreviewPhoneSize large = DailyCarePreviewPhoneSize(
    id: 'large',
    label: '大手機',
    size: Size(430, 932),
  );

  static const List<DailyCarePreviewPhoneSize> all =
      <DailyCarePreviewPhoneSize>[small, standard, large];
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
    this.shopName = '',
    this.shopLogoUrl = '',
    this.phoneSize = DailyCarePreviewPhoneSize.standard,
    this.singleDayMode = false,
    this.singleSessionMode = false,
  });

  final DailyCareSettingModel setting;
  final bool isDaycare;
  final List<String> sessionLabels;
  final int sessionIndex;
  final bool showPhotos;
  final bool usePhoneFrame;
  final String shopName;
  final String shopLogoUrl;
  final DailyCarePreviewPhoneSize phoneSize;
  final bool singleDayMode;
  final bool singleSessionMode;

  static const String deviceNote =
      '此為標準手機比例預覽；不同廠牌、螢幕尺寸及瀏海／動態島設計，實際上下留白可能略有差異。';

  @override
  State<DailyCareFullJournalPreview> createState() =>
      _DailyCareFullJournalPreviewState();
}

class _DailyCareFullJournalPreviewState
    extends State<DailyCareFullJournalPreview> {
  String? _selectedDateKey;
  int? _selectedSessionIndex;

  static const EdgeInsets _phoneSafePadding = EdgeInsets.only(
    top: 47,
    bottom: 34,
  );

  @override
  void didUpdateWidget(DailyCareFullJournalPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionIndex != widget.sessionIndex ||
        oldWidget.singleSessionMode != widget.singleSessionMode) {
      _selectedSessionIndex = widget.sessionIndex;
    }
    if (oldWidget.singleDayMode != widget.singleDayMode) {
      _selectedDateKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int sessionIndex = _selectedSessionIndex ?? widget.sessionIndex;
    final DailyCareJournalDemoData demo = DailyCareJournalDemoData.build(
      setting: widget.setting,
      isDaycare: widget.isDaycare,
      sessionLabels: widget.sessionLabels,
      sessionIndex: sessionIndex,
      selectedDateKey: _selectedDateKey ?? '',
      showPhotos: widget.showPhotos && widget.setting.photoEnabled,
      singleDayMode: widget.singleDayMode,
      singleSessionMode: widget.singleSessionMode,
    );
    final String selectedDateKey =
        _selectedDateKey != null && demo.dateKeys.contains(_selectedDateKey)
        ? _selectedDateKey!
        : demo.dateKeys.first;
    final int safeSession = sessionIndex.clamp(0, demo.sessionTabs.length - 1);
    final Widget journal = DailyCareJournalRenderer(
      setting: widget.setting,
      stay: demo.stay,
      dateKeys: demo.dateKeys,
      selectedDateKey: selectedDateKey,
      sessionTabs: demo.sessionTabs,
      selectedSessionIndex: safeSession,
      record: demo.record,
      fallbackRoomName: demo.stay.roomName,
      photos: demo.photos,
      photosLoading: false,
      showPhotoSection:
          widget.setting.photoEnabled &&
          widget.setting.journalDisplay.showPhotoSection,
      shopName: widget.shopName,
      shopLogoUrl: widget.shopLogoUrl,
      isDaycare: widget.isDaycare,
      offerName: widget.isDaycare ? '示範安親' : 'A1',
      footer: const DailyCarePreviewServiceButtons(),
      onDateSelected: (String dateKey) {
        setState(() {
          _selectedDateKey = dateKey;
        });
      },
      onSessionSelected: (int index) {
        setState(() {
          _selectedSessionIndex = index;
        });
      },
    );

    final Widget phoneScreen = Stack(
      children: <Widget>[
        const Positioned.fill(child: ColoredBox(color: Color(0xFFEDE7E0))),
        Positioned.fill(
          child: DailyCareJournalPageBackground(setting: widget.setting),
        ),
        DailyCareJournalScaffold(
          setting: widget.setting,
          shopName: widget.shopName,
          leading: IconButton(icon: const BackButtonIcon(), onPressed: () {}),
          body: journal,
        ),
        if (widget.usePhoneFrame)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(child: DailyCarePreviewStatusBar()),
          ),
      ],
    );

    const Widget deviceNote = Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(
        DailyCareFullJournalPreview.deviceNote,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF9A8F86)),
      ),
    );

    if (!widget.usePhoneFrame) {
      return Column(
        children: <Widget>[
          Expanded(child: phoneScreen),
          deviceNote,
        ],
      );
    }

    final Size logical = widget.phoneSize.size;
    final Widget viewport = MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: logical,
        padding: _phoneSafePadding,
        viewPadding: _phoneSafePadding,
        viewInsets: EdgeInsets.zero,
      ),
      child: SizedBox(
        width: logical.width,
        height: logical.height,
        child: phoneScreen,
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                      child: viewport,
                    ),
                  ),
                ),
              ),
            ),
            deviceNote,
          ],
        ),
      ),
    );
  }
}

class DailyCarePreviewServiceButtons extends StatelessWidget {
  const DailyCarePreviewServiceButtons({super.key});

  static const Key photosButtonKey = ValueKey<String>(
    'preview-mock-photos-button',
  );
  static const Key cameraButtonKey = ValueKey<String>(
    'preview-mock-camera-button',
  );

  @override
  Widget build(BuildContext context) {
    final ButtonStyle compact = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll<EdgeInsets>(
        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.tonalIcon(
            key: photosButtonKey,
            onPressed: () {},
            style: compact,
            icon: const Icon(Icons.photo_library_outlined, size: 16),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('查看全部照護照片'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            key: cameraButtonKey,
            onPressed: () {},
            style: compact,
            icon: const Icon(Icons.videocam_outlined, size: 16),
            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('觀看攝影機')),
          ),
        ),
      ],
    );
  }
}

class DailyCarePreviewStatusBar extends StatelessWidget {
  const DailyCarePreviewStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.paddingOf(context).top;
    if (height <= 0) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            const Text(
              '10:32',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Expanded(
              child: Center(
                child: SizedBox(
                  width: 88,
                  height: 22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
            Icon(
              Icons.signal_cellular_alt,
              size: 14,
              color: Colors.black.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.wifi,
              size: 14,
              color: Colors.black.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.battery_full,
              size: 14,
              color: Colors.black.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
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
