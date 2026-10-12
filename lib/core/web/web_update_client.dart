// 檔案名稱：lib/core/web/web_update_client.dart
// 功能說明：網頁版讀取部署版本並重新載入；其他平台使用空實作。

export 'web_update_client_stub.dart'
    if (dart.library.js_interop) 'web_update_client_web.dart';
