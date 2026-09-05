// 檔案名稱：lib/features/shop/pages/shop_export_report_page.dart
// 功能說明：依日期範圍匯出選定報表或全部營運資料。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/report_downloader_stub.dart'
    if (dart.library.html) 'package:petnest_saas/core/services/report_downloader_web.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_export_service.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/features/shop/widgets/report_range_selector.dart';
import 'package:petnest_saas/features/shop/widgets/shop_report_widgets.dart';

class ShopExportReportPage extends StatefulWidget {
  const ShopExportReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopExportReportPage> createState() => _ShopExportReportPageState();
}

class _ShopExportReportPageState extends State<ShopExportReportPage> {
  ReportRange _range = ReportRange.thisMonth();
  ShopReportExportKind _kind = ShopReportExportKind.all;
  bool _exporting = false;

  Future<void> _exportExcel() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Excel 下載目前只支援 Web 後台')));
      return;
    }

    setState(() {
      _exporting = true;
    });

    try {
      final Uint8List bytes = await ShopReportExportService.instance.buildExcel(
        shopId: widget.shopId,
        range: _range,
        kind: _kind,
      );
      final String start = ShopReportFormat.date.format(_range.startDate);
      final String end = ShopReportFormat.date.format(_range.endDate);
      final String fileName = 'PetNest_${_kind.fileLabel}_$start-$end.xlsx'
          .replaceAll('/', '');

      await downloadExcelFile(bytes: bytes, fileName: fileName);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Excel 報表已開始下載')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Excel 匯出')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Excel 營運報表',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '匯出會套用上方選擇的日期範圍。金額為數字、日期為 yyyy/MM/dd。',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ReportRangeSelector(
            range: _range,
            onChanged: (ReportRange value) {
              setState(() {
                _range = value;
              });
            },
          ),
          const SizedBox(height: 8),
          const ReportNote(
            '全部營運資料會分成多個工作表：營運總覽、日期統計、營收、房型、加購、會員。Web 後台可下載；App 版暫不提供檔案下載。',
          ),
          ...ShopReportExportKind.values.map((ShopReportExportKind kind) {
            final bool selected = _kind == kind;
            return ListTile(
              leading: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
              title: Text(kind.label),
              subtitle: Text(kind.subtitle),
              onTap: () {
                setState(() {
                  _kind = kind;
                });
              },
            );
          }),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _exporting ? null : _exportExcel,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_exporting ? '匯出中…' : '下載 Excel'),
          ),
        ],
      ),
    );
  }
}
