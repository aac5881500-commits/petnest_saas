// 檔案名稱：lib/core/web/web_update_client_stub.dart
// 功能說明：非網頁平台不檢查版本，也不重新載入。

import 'web_build_info.dart';

abstract class WebUpdateClient {
  Future<WebBuildInfo?> fetchRemote();

  Future<void> applyUpdate();
}

WebUpdateClient createWebUpdateClient() => const _UnavailableWebUpdateClient();

class _UnavailableWebUpdateClient implements WebUpdateClient {
  const _UnavailableWebUpdateClient();

  @override
  Future<void> applyUpdate() async {}

  @override
  Future<WebBuildInfo?> fetchRemote() async => null;
}
