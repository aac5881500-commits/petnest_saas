// lib/core/services/shop_report_export_service.dart
// 📥 店家營運報表匯出服務
// 功能：產生 Excel 檔案，包含日期、營收、房型、加購統計

import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';

class ShopReportExportService {
  ShopReportExportService._();

  static final ShopReportExportService instance = ShopReportExportService._();

  Future<Uint8List> buildExcel({required String shopId}) async {
    final excel = Excel.createExcel();

    final dailyReports = await ShopReportService.instance.getDailyReports(
      shopId: shopId,
      startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
      endDate: DateTime.now(),
    );

    final revenueReports = await ShopReportService.instance
        .getMonthlyRevenueReports(shopId: shopId);

    final roomReports = await ShopReportService.instance.getRoomTypeReports(
      shopId: shopId,
    );

    final addonReports = await ShopReportService.instance.getAddonReports(
      shopId: shopId,
    );

    _buildDailySheet(excel, dailyReports);
    _buildRevenueSheet(excel, revenueReports);
    _buildRoomTypeSheet(excel, roomReports);
    _buildAddonSheet(excel, addonReports);

    excel.delete('Sheet1');

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  void _buildDailySheet(Excel excel, List<DailyShopReport> reports) {
    final sheet = excel['日期統計'];

    sheet.appendRow([
      TextCellValue('日期'),
      TextCellValue('訂單數'),
      TextCellValue('取消數'),
      TextCellValue('營收'),
    ]);

    for (final item in reports) {
      sheet.appendRow([
        TextCellValue('${item.date.year}/${item.date.month}/${item.date.day}'),
        IntCellValue(item.orderCount),
        IntCellValue(item.cancelCount),
        IntCellValue(item.revenue),
      ]);
    }
  }

  void _buildRevenueSheet(Excel excel, List<MonthlyRevenueReport> reports) {
    final sheet = excel['營收統計'];

    sheet.appendRow([
      TextCellValue('月份'),
      TextCellValue('訂單數'),
      TextCellValue('取消數'),
      TextCellValue('營收'),
      TextCellValue('平均客單價'),
    ]);

    for (final item in reports) {
      sheet.appendRow([
        TextCellValue(item.month),
        IntCellValue(item.orderCount),
        IntCellValue(item.cancelCount),
        IntCellValue(item.revenue),
        IntCellValue(item.averageOrderValue),
      ]);
    }
  }

  void _buildRoomTypeSheet(Excel excel, List<RoomTypeReport> reports) {
    final sheet = excel['房型統計'];

    sheet.appendRow([
      TextCellValue('房型'),
      TextCellValue('訂單數'),
      TextCellValue('有效訂單'),
      TextCellValue('取消數'),
      TextCellValue('營收'),
    ]);

    for (final item in reports) {
      sheet.appendRow([
        TextCellValue(item.roomTypeName),
        IntCellValue(item.orderCount),
        IntCellValue(item.validOrderCount),
        IntCellValue(item.cancelCount),
        IntCellValue(item.revenue),
      ]);
    }
  }

  void _buildAddonSheet(Excel excel, List<AddonReport> reports) {
    final sheet = excel['加購統計'];

    sheet.appendRow([
      TextCellValue('服務名稱'),
      TextCellValue('類型'),
      TextCellValue('銷售次數'),
      TextCellValue('營收'),
    ]);

    for (final item in reports) {
      sheet.appendRow([
        TextCellValue(item.name),
        TextCellValue(item.type),
        IntCellValue(item.saleCount),
        IntCellValue(item.revenue),
      ]);
    }
  }
}
