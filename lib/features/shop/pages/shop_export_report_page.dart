// lib/features/shop/pages/shop_export_report_page.dart
// 📥 匯出營運報表
// 功能：電腦 Web 下載 Excel 營運報表，手機端只提示使用電腦下載

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/report_downloader_stub.dart'
    if (dart.library.html) 'package:petnest_saas/core/services/report_downloader_web.dart';
import 'package:petnest_saas/core/services/shop_report_export_service.dart';

class ShopExportReportPage extends StatefulWidget {
  const ShopExportReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopExportReportPage> createState() => _ShopExportReportPageState();
}

class _ShopExportReportPageState extends State<ShopExportReportPage> {
  bool _exporting = false;

  bool get _isDesktopWeb {
    if (!kIsWeb) return false;

    final width = MediaQuery.of(context).size.width;
    return width >= 900;
  }

  Future<void> _exportExcel() async {
    if (!_isDesktopWeb) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請使用電腦版後台下載 Excel 報表')));
      return;
    }

    setState(() {
      _exporting = true;
    });

    try {
      final bytes = await ShopReportExportService.instance.buildExcel(
        shopId: widget.shopId,
      );

      final fileName =
          'PetNest_營運報表_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}.xlsx';

      await downloadExcelFile(bytes: bytes, fileName: fileName);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Excel 報表已開始下載')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    } finally {
      if (!mounted) return;

      setState(() {
        _exporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWeb = _isDesktopWeb;

    return Scaffold(
      appBar: AppBar(title: const Text('匯出營運報表')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Excel 營運報表',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            '將匯出日期統計、營收統計、房型統計與加購統計。',
            style: TextStyle(color: Colors.grey.shade600),
          ),

          const SizedBox(height: 16),

          if (!isDesktopWeb)
            Card(
              color: Colors.orange.shade50,
              child: const ListTile(
                leading: Icon(Icons.desktop_windows),
                title: Text('請使用電腦版下載'),
                subtitle: Text('Excel 報表下載功能目前只提供電腦版後台使用。'),
              ),
            ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('PetNest 營運報表.xlsx'),
              subtitle: const Text('包含日期、營收、房型與加購統計'),
              trailing: _exporting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              enabled: isDesktopWeb && !_exporting,
              onTap: isDesktopWeb && !_exporting ? _exportExcel : null,
            ),
          ),
        ],
      ),
    );
  }
}
