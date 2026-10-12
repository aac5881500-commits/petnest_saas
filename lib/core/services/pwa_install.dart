// 檔案名稱：lib/core/services/pwa_install.dart
// 功能說明：網頁版讀取安裝狀態；其他平台使用空實作。

export 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart';
export 'pwa_install_status.dart';
