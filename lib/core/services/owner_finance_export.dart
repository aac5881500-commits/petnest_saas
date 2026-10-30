import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';

class OwnerFinanceExport {
  static Uint8List build({
    required String month,
    required List<Map<String, dynamic>> entries,
    ShopReportBundle? report,
  }) {
    final excel = Excel.createExcel();
    void row(String sheet, List<Object> values) => excel[sheet].appendRow(
      values
          .map((v) => v is int ? IntCellValue(v) : TextCellValue(v.toString()))
          .toList(),
    );
    row('月報說明', ['月份', month]);
    row('月報說明', ['資料範圍', '完整月份私人收支，不受畫面開關與明細篩選影響。包含員工薪資，請妥善保管。']);
    row('月報說明', ['統計口徑', '訂單按建立日、淨實收按付款日且已反映退款；結餘非會計淨利。']);
    row('月報說明', ['系統資料', report == null ? '讀取失敗，未提供系統收入與結餘，不當作零元。' : '已載入']);
    int total(String kind) => entries
        .where((e) => e['kind'] == kind)
        .fold<int>(0, (v, e) => v + (e['amount'] as num).toInt());
    final salary = total('salary'),
        cost = total('expense'),
        income = total('income');
    row('月報摘要', ['項目', '新台幣']);
    row('月報摘要', ['員工薪資', salary]);
    row('月報摘要', ['其他支出', cost]);
    row('月報摘要', ['其他收入', income]);
    if (report != null) {
      final k = report.revenueKpi;
      row('月報摘要', ['訂單金額', k.orderAmount]);
      row('月報摘要', ['系統淨實收', k.paidAmount]);
      row('月報摘要', ['退款', k.refundAmount]);
      row('月報摘要', ['未收款', k.unpaidAmount]);
      row('月報摘要', ['收支結餘', k.paidAmount + income - salary - cost]);
      row('每日營收', ['日期', '訂單數', '訂單金額', '淨實收', '退款', '未收款']);
      for (final r in report.revenueByDay) {
        row('每日營收', [
          r.label,
          r.orderCount,
          r.orderAmount,
          r.paidAmount,
          r.refundAmount,
          r.unpaidAmount,
        ]);
      }
    }
    row('私人收支明細', ['月份', '類別', '姓名／項目', '金額（新台幣）', '備註']);
    for (final e in entries) {
      row('私人收支明細', [
        month,
        switch (e['kind']) {
          'salary' => '員工薪資',
          'income' => '其他收入',
          _ => '營運支出',
        },
        e['name'] as String,
        (e['amount'] as num).toInt(),
        e['note'] as String? ?? '',
      ]);
    }
    excel.delete('Sheet1');
    for (final sheet in excel.tables.values) {
      sheet.setColumnWidth(0, 24);
      sheet.setColumnWidth(1, 28);
      if (sheet.rows.isNotEmpty) {
        for (final cell in sheet.rows.first) {
          if (cell != null) {
            cell.cellStyle = CellStyle(
              bold: true,
              fontColorHex: ExcelColor.white,
              backgroundColorHex: ExcelColor.fromHexString('#26375B'),
            );
          }
        }
      }
    }
    return Uint8List.fromList(excel.encode()!);
  }
}
