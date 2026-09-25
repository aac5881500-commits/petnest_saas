// 檔案名稱：lib/features/shop/pages/daily_care_report_center_page.dart
// 功能說明：店家每日照護回報中心入口，沿用既有填寫頁與即時 snapshot。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_report_center_snapshot.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_report_center_service.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../widgets/daily_care_report_center_board.dart';

class DailyCareReportCenterPage extends StatefulWidget {
  const DailyCareReportCenterPage({
    super.key,
    required this.shopId,
    this.canOperate = true,
    this.focusBookingId = '',
    this.initialBookingId,
    this.embedded = false,
    this.focusServiceType = '',
    this.focusRecordDate,
    this.focusSessionIndex,
    this.focusBookingCode = '',
    this.focusRoomId = '',
    this.focusRoomName = '',
    this.focusRoomTypeName = '',
    this.focusCheckIn,
    this.focusCheckOut,
  });

  final String shopId;
  final bool canOperate;
  final String focusBookingId;
  final String? initialBookingId;
  final bool embedded;
  final String focusServiceType;
  final DateTime? focusRecordDate;
  final int? focusSessionIndex;
  final String focusBookingCode;
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
  late DailyCareReportCenterTypeFilter _type;
  String _query = '';
  DailyCareReportCenterSnapshot? _lastSnapshot;

  String get _bookingId {
    final String? initial = widget.initialBookingId;
    if (initial != null) {
      return initial.trim();
    }
    return widget.focusBookingId.trim();
  }

  bool get _compactEmbedded {
    return widget.embedded && widget.initialBookingId != null;
  }

  @override
  void initState() {
    super.initState();
    final String serviceType = widget.focusServiceType.trim();
    if (serviceType == DailyCareServiceTypes.daycare) {
      _type = DailyCareReportCenterTypeFilter.daycare;
    } else if (serviceType == DailyCareServiceTypes.accommodation) {
      _type = DailyCareReportCenterTypeFilter.stay;
    } else {
      _type = DailyCareReportCenterTypeFilter.all;
    }
    if (_bookingId.isNotEmpty) {
      _status = DailyCareReportCenterStatusFilter.all;
      _query = widget.focusBookingCode.trim();
    } else {
      _status = DailyCareReportCenterStatusFilter.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = StreamBuilder<DailyCareSettingModel>(
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
              return _messagePane('每日回報功能目前未啟用');
            }
            if (_compactEmbedded && _bookingId.isEmpty) {
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
                      if (snap.hasData &&
                          snap.data != null &&
                          !snap.data!.hasError) {
                        _lastSnapshot = snap.data;
                      }
                      return const _EmbeddedEmptyState();
                    },
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
                      if (_lastSnapshot == null) {
                        return DailyCareReportCenterErrorPane(onRetry: _reload);
                      }
                    }
                    final DailyCareReportCenterSnapshot? data = snap.hasData
                        ? snap.data
                        : _lastSnapshot;
                    if (data != null && !data.hasError) {
                      _lastSnapshot = data;
                    }
                    final DailyCareReportCenterSnapshot? live = _lastSnapshot;
                    if (live == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!live.settingEnabled) {
                      return _messagePane('每日回報功能目前未啟用');
                    }
                    return DailyCareReportCenterBoard(
                      snapshot: live,
                      setting: setting,
                      status: _status,
                      onStatus: (DailyCareReportCenterStatusFilter value) {
                        setState(() {
                          _status = value;
                        });
                      },
                      type: _type,
                      onType: (DailyCareReportCenterTypeFilter value) {
                        setState(() {
                          _type = value;
                        });
                      },
                      query: _query,
                      onQuery: (String value) {
                        setState(() {
                          _query = value;
                        });
                      },
                      focusBookingId: _bookingId,
                      focusRecordDate: widget.focusRecordDate,
                      focusSessionIndex: widget.focusSessionIndex,
                      embedded: _compactEmbedded,
                    );
                  },
            );
          },
    );
    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFFF7F8FA), child: body);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('每日回報')),
      body: body,
    );
  }

  Widget _messagePane(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _reload() {
    setState(() {
      _retry += 1;
      _lastSnapshot = null;
    });
  }
}

class _EmbeddedEmptyState extends StatelessWidget {
  const _EmbeddedEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.pets_outlined, size: 48, color: Color(0xFF90A4AE)),
            SizedBox(height: 16),
            Text(
              '選擇左側入住中的房間',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              '即可查看與填寫該筆訂單的每日回報',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
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
      return snapshot.totalCount <= 0 ? '目前沒有需處理的每日回報' : '目前沒有待填回報';
    }
    return '待填 ${snapshot.pendingCount} 場・已完成 ${snapshot.completedCount} 場';
  }
}
