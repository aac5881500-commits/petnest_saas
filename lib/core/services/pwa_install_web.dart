// 檔案名稱：lib/core/services/pwa_install_web.dart
// 功能說明：讀取 index.html 保留的瀏覽器安裝提示，並在店主確認時開啟它。

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'pwa_install_status.dart';

class PwaInstallBridge {
  static PwaInstallStatus read() {
    final JSObject? api = _api();
    if (api == null) return PwaInstallStatus.unavailable;
    return PwaInstallStatus(
      standalone: _bool(api, 'isStandalone'),
      canPrompt: _bool(api, 'canPrompt'),
      rememberedInstalled: _bool(api, 'rememberedInstalled'),
      secureContext: _bool(api, 'isSecure'),
      browser: _string(api, 'browserName'),
    );
  }

  static Future<String> promptInstall() async {
    final JSAny? prompt = globalContext['petNestPwaPrompt'];
    if (prompt == null || !prompt.isA<JSFunction>()) return 'unavailable';
    try {
      final JSAny? promise = (prompt as JSFunction).callAsFunction();
      if (promise == null || !promise.isA<JSPromise>()) return 'unavailable';
      final JSAny? result = await (promise as JSPromise<JSAny?>).toDart;
      if (result != null && result.isA<JSString>()) {
        return (result as JSString).toDart;
      }
    } catch (_) {}
    return 'unavailable';
  }

  static void listen(void Function() onChange) {
    final JSAny? listen = globalContext['petNestPwaListen'];
    if (listen == null || !listen.isA<JSFunction>()) return;
    (listen as JSFunction).callAsFunction(null, (() => onChange()).toJS);
  }
}

JSObject? _api() {
  final JSAny? value = globalContext['petNestPwa'];
  if (value == null || !value.isA<JSObject>()) return null;
  return value as JSObject;
}

bool _bool(JSObject api, String name) {
  try {
    final JSAny? value = api.callMethod(name.toJS);
    if (value != null && value.isA<JSBoolean>()) {
      return (value as JSBoolean).toDart;
    }
  } catch (_) {}
  return false;
}

String _string(JSObject api, String name) {
  try {
    final JSAny? value = api.callMethod(name.toJS);
    if (value != null && value.isA<JSString>()) {
      return (value as JSString).toDart;
    }
  } catch (_) {}
  return 'other';
}
