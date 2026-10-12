// 檔案名稱：lib/core/services/pwa_install_stub.dart
// 功能說明：Android、iOS 與桌面原生版沒有瀏覽器安裝提示。

import 'pwa_install_status.dart';

class PwaInstallBridge {
  static PwaInstallStatus read() => PwaInstallStatus.unavailable;

  static Future<String> promptInstall() async => 'unavailable';

  static void listen(void Function() onChange) {}
}
