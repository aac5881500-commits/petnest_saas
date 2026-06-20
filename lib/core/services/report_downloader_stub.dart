// lib/core/services/report_downloader_stub.dart
// 📥 報表下載 Stub
// 功能：非 Web 平台不執行下載，避免 Android 編譯 dart:html 錯誤

import 'dart:typed_data';

Future<void> downloadExcelFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  throw UnsupportedError('Excel 報表下載目前只支援電腦版 Web');
}
