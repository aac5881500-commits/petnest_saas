// 檔案名稱：lib/core/services/report_downloader_stub.dart
// 功能說明：非 Web 平台不執行下載，避免 Android 編譯 dart:html 錯誤
// 📥 報表下載 Stub

import 'dart:typed_data';

Future<void> downloadExcelFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  throw UnsupportedError('Excel 報表下載目前只支援電腦版 Web');
}
