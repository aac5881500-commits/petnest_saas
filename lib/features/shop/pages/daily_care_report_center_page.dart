// 檔案名稱：lib/features/shop/pages/daily_care_report_center_page.dart
// 功能說明：店家今日每日照護回報中心，集中列出住宿與安親的待填／已完成回報，並沿用既有填寫頁。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_report_center_item.dart';
import '../../../core/models/daily_care_report_center_snapshot.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/services/daily_care_report_center_service.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../../room/daily_care_record_edit_launcher.dart';

class DailyCareReportCenterPage extends StatefulWidget {
  const DailyCareReportCenterPage({
    super.key,
    required this.shopId,
    this.canOperate = true,
  });

  final String shopId;
  final bool canOperate;

  @override
  State<DailyCareReportCenterPage> createState() =>
      _DailyCareReportCenterPageState();
}

class _DailyCareReportCenterPageState extends State<DailyCareReportCenterPage> {
  int _retry = 0;
  DailyCareReportCenterStatusFilter _status =
      DailyCareReportCenterStatusFilter.pending;
  DailyCareReportCenterTypeFilter _type = DailyCareReportCenterTypeFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                return _ErrorPane(onRetry: _reload);
              }
              final DailyCareSettingModel setting =
                  settingSnap.data ?? const DailyCareSettingModel();
              if (settingSnap.connectionState == ConnectionState.waiting &&
                  settingSnap.data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!setting.enabled) {
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
                        return _ErrorPane(onRetry: _reload);
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
                      return _CenterBody(
                        snapshot: data,
                        setting: setting,
                        status: _status,
                        type: _type,
                        onStatus: (DailyCareReportCenterStatusFilter value) {
                          setState(() {
                            _status = value;
                          });
                        },
                        onType: (DailyCareReportCenterTypeFilter value) {
                          setState(() {
                            _type = value;
                          });
                        },
                      );
                    },
              );
            },
      ),
    );
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

class _CenterBody extends StatelessWidget {
  const _CenterBody({
    required this.snapshot,
    required this.setting,
    required this.status,
    required this.type,
    required this.onStatus,
    required this.onType,
  });

  final DailyCareReportCenterSnapshot snapshot;
  final DailyCareSettingModel setting;
  final DailyCareReportCenterStatusFilter status;
  final DailyCareReportCenterTypeFilter type;
  final ValueChanged<DailyCareReportCenterStatusFilter> onStatus;
  final ValueChanged<DailyCareReportCenterTypeFilter> onType;

  @override
  Widget build(BuildContext context) {
    final List<DailyCareReportCenterItem> visible = snapshot.filtered(
      status: status,
      type: type,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        const Text(
          '今天需回報的住宿與安親訂單',
          style: TextStyle(fontSize: 13.5, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        _SummaryCard(snapshot: snapshot),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: <Widget>[
            ChoiceChip(
              label: const Text('全部'),
              selected: status == DailyCareReportCenterStatusFilter.all,
              onSelected: (_) =>
                  onStatus(DailyCareReportCenterStatusFilter.all),
            ),
            ChoiceChip(
              label: const Text('待填'),
              selected: status == DailyCareReportCenterStatusFilter.pending,
              onSelected: (_) =>
                  onStatus(DailyCareReportCenterStatusFilter.pending),
            ),
            ChoiceChip(
              label: const Text('已完成'),
              selected: status == DailyCareReportCenterStatusFilter.completed,
              onSelected: (_) =>
                  onStatus(DailyCareReportCenterStatusFilter.completed),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            ChoiceChip(
              label: const Text('全部'),
              selected: type == DailyCareReportCenterTypeFilter.all,
              onSelected: (_) => onType(DailyCareReportCenterTypeFilter.all),
            ),
            ChoiceChip(
              label: const Text('住宿'),
              selected: type == DailyCareReportCenterTypeFilter.accommodation,
              onSelected: (_) =>
                  onType(DailyCareReportCenterTypeFilter.accommodation),
            ),
            ChoiceChip(
              label: const Text('安親'),
              selected: type == DailyCareReportCenterTypeFilter.daycare,
              onSelected: (_) =>
                  onType(DailyCareReportCenterTypeFilter.daycare),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                status == DailyCareReportCenterStatusFilter.completed
                    ? '今日尚無已完成回報'
                    : '今日沒有待填的照護回報',
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
            ),
          )
        else
          for (final DailyCareReportCenterItem item in visible)
            _SessionCard(item: item, setting: setting),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot});

  final DailyCareReportCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: <Widget>[
            _stat('待填', '${snapshot.pendingCount} 場'),
            _stat('已完成', '${snapshot.completedCount} 場'),
            _stat('共計', '${snapshot.totalCount} 場'),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.item, required this.setting});

  final DailyCareReportCenterItem item;
  final DailyCareSettingModel setting;

  @override
  Widget build(BuildContext context) {
    final bool completed = item.isCompleted;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(item.typeLabel),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.placeLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  completed ? '已完成' : '待填',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: completed
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                ),
              ],
            ),
            if (item.petNamesText.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text('寵物：${item.petNamesText}'),
            ],
            if (item.customerName.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text('客戶：${item.customerName}'),
            ],
            const SizedBox(height: 2),
            Text('場次：${item.sessionName}'),
            if (completed && item.updatedAt != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                '最後更新：${_formatTime(item.updatedAt!)}',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: item.canOperate
                    ? () => DailyCareRecordEditLauncher.open(
                        context: context,
                        shopId: item.shopId,
                        bookingId: item.bookingId,
                        recordDate: item.recordDate,
                        sessionIndex: item.sessionIndex,
                        roomId: item.roomId,
                        roomName: item.roomName,
                        serviceType: item.serviceType,
                        petIds: item.petIds,
                        setting: setting,
                      )
                    : null,
                child: Text(completed ? '查看／修改' : '立即填寫'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final String h = value.hour.toString().padLeft(2, '0');
    final String m = value.minute.toString().padLeft(2, '0');
    return '${value.month}/${value.day} $h:$m';
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('目前無法取得每日回報，請稍後再試', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重新整理')),
          ],
        ),
      ),
    );
  }
}
