import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:petnest_saas/core/models/report_table_spec.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';

class ReportExportTable {
  const ReportExportTable({
    required this.name,
    required this.spec,
    required this.rows,
  });
  final String name;
  final ReportTableSpec spec;
  final List<Map<String, Object?>> rows;
}

class ReportWorkbenchExport {
  static Uint8List build({
    required String shopName,
    required ReportRange range,
    required List<ReportExportTable> tables,
    required String query,
  }) {
    if (tables.isEmpty) throw ArgumentError('請選擇至少一張報表');
    final excel = Excel.createExcel();
    final info = excel['報表說明'];
    final metadata = <List<String>>[
      ['PetNest 營運報表', '內容'],
      ['店家', shopName],
      [
        '期間',
        '${ShopReportFormat.date.format(range.startDate)} ～ ${ShopReportFormat.date.format(range.endDate)}',
      ],
      ['產生時間', DateTime.now().toIso8601String()],
      ['查詢文字', query.isEmpty ? '未篩選' : query],
      ['幣別', '新台幣（TWD），金額保留數值欄位'],
      ['統計口徑', '訂單依建立日統計；有效訂單限已確認、入住中及已完成。收款依付款日期；待收款為既有訂單與付款資料的估計。'],
      ['會員口徑', '會員消費與首次／最近訂單限查詢期間，非歷年累積；近 30／90 天截至期間結束日。'],
      ['匯出範圍', '依所選資料來源、欄位及篩選條件，包含全部符合條件的資料，不限目前頁面。'],
    ];
    for (final row in metadata) {
      info.appendRow(row.map((v) => TextCellValue(v)).toList());
    }
    info.setColumnWidth(0, 22);
    info.setColumnWidth(1, 100);
    for (final table in tables) {
      final fields = table.spec.visibleFields;
      if (fields.isEmpty) continue;
      final cleanName = table.name.replaceAll(RegExp(r'[\\/*?:\[\]]'), '');
      final sheet =
          excel[cleanName.isEmpty
              ? '報表'
              : cleanName.substring(0, cleanName.length.clamp(0, 31))];
      info.appendRow([
        TextCellValue('${table.name} 資料來源'),
        TextCellValue(
          table.spec.sources
              .map((s) => ReportTableSpec.sourceNames[s] ?? s)
              .join('、'),
        ),
      ]);
      sheet.appendRow(fields.map((f) => TextCellValue(f.label)).toList());
      sheet.setRowHeight(0, 28);
      for (var c = 0; c < fields.length; c++) {
        sheet.setColumnWidth(
          c,
          fields[c].id == 'phone'
              ? 22
              : fields[c].isNumeric
              ? 20
              : 26,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
            .cellStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.white,
          backgroundColorHex: ExcelColor.fromHexString('#33466D'),
          fontSize: 11,
        );
      }
      for (var r = 0; r < table.rows.length; r++) {
        sheet.appendRow(
          fields.map((f) {
            final value = table.rows[r][f.id];
            if (value is int) return IntCellValue(value);
            if (value is num) return DoubleCellValue(value.toDouble());
            return TextCellValue(ReportDataset.display(value, f));
          }).toList(),
        );
        for (var c = 0; c < fields.length; c++) {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
              .cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(
              r.isEven ? '#F3F6FB' : '#FFFFFF',
            ),
            horizontalAlign: fields[c].isNumeric
                ? HorizontalAlign.Right
                : HorizontalAlign.Left,
            numberFormat: fields[c].isNumeric
                ? NumFormat.custom(formatCode: '#,##0;[Red]-#,##0')
                : NumFormat.standard_0,
          );
        }
      }
      sheet.appendRow(
        fields.asMap().entries.map((entry) {
          final f = entry.value;
          if (f.total) {
            final sum = table.rows.fold<num>(
              0,
              (sum, row) => sum + (row[f.id] is num ? row[f.id] as num : 0),
            );
            return IntCellValue(sum.toInt());
          }
          return TextCellValue(entry.key == 0 ? '篩選後合計' : '');
        }).toList(),
      );
      final footer = table.rows.length + 1;
      for (var c = 0; c < fields.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: footer))
            .cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#E5ECF8'),
        );
      }
    }
    excel.delete('Sheet1');
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Excel 產生失敗');
    return Uint8List.fromList(bytes);
  }
}
