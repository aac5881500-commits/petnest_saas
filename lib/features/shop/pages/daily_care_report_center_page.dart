// 檔案名稱：lib/features/shop/pages/daily_care_report_center_page.dart
// 功能說明：店家今日每日照護回報中心入口，沿用既有填寫頁與即時 snapshot。

import 'package:flutter/material.dart';

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
                      return DailyCareReportCenterBoard(
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
