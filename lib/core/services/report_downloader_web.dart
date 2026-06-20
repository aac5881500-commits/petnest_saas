// lib/core/services/report_downloader_web.dart
// 📥 Web 報表下載
// 功能：使用瀏覽器下載 Excel 檔案

import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadExcelFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  final blob = html.Blob([
    bytes,
  ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  html.Url.revokeObjectUrl(url);
}
