// 檔案名稱：lib/core/web/web_update_client_web.dart
// 功能說明：向 Hosting 讀取 petnest-build.json，並在使用者確認後更新 Flutter Service Worker。

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'web_build_info.dart';
import 'web_update_client_stub.dart';

export 'web_update_client_stub.dart' show WebUpdateClient;

WebUpdateClient createWebUpdateClient() => const _BrowserWebUpdateClient();

class _BrowserWebUpdateClient implements WebUpdateClient {
  const _BrowserWebUpdateClient();

  @override
  Future<WebBuildInfo?> fetchRemote() async {
    try {
      final JSAny? fetchFn = globalContext['fetch'];
      if (fetchFn == null || !fetchFn.isA<JSFunction>()) return null;
      final String url =
          '/petnest-build.json?petnest=${DateTime.now().millisecondsSinceEpoch}';
      final JSAny? init = <String, Object?>{'cache': 'no-store'}.jsify();
      final JSAny? promise = (fetchFn as JSFunction).callAsFunction(
        null,
        url.toJS,
        init,
      );
      if (promise == null || !promise.isA<JSPromise>()) return null;
      final JSAny? response = await (promise as JSPromise<JSAny?>).toDart;
      if (response == null || !response.isA<JSObject>()) return null;
      final JSObject http = response as JSObject;
      final JSAny? ok = http['ok'];
      if (ok.isA<JSBoolean>() && !(ok as JSBoolean).toDart) return null;
      final JSAny? textResult = http.callMethod('text'.toJS);
      if (textResult == null || !textResult.isA<JSPromise>()) return null;
      final JSAny? body = await (textResult as JSPromise<JSAny?>).toDart;
      if (body == null || !body.isA<JSString>()) return null;
      return parseWebBuildInfo((body as JSString).toDart);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> applyUpdate() async {
    try {
      await _activateFlutterServiceWorker();
    } catch (_) {}
    _reloadPage();
  }

  Future<void> _activateFlutterServiceWorker() async {
    final JSAny? navigator = globalContext['navigator'];
    if (navigator == null || !navigator.isA<JSObject>()) return;
    final JSAny? container = (navigator as JSObject)['serviceWorker'];
    if (container == null || !container.isA<JSObject>()) return;
    final JSAny? registrations = (container as JSObject).callMethod(
      'getRegistrations'.toJS,
    );
    if (registrations == null || !registrations.isA<JSPromise>()) return;
    final JSAny? list = await (registrations as JSPromise<JSAny?>).toDart;
    if (list == null || !list.isA<JSArray>()) return;
    for (final JSAny? item in (list as JSArray<JSAny?>).toDart) {
      if (item == null || !item.isA<JSObject>()) continue;
      final JSObject registration = item as JSObject;
      if (!_isFlutterServiceWorker(registration)) continue;
      try {
        final JSAny? updated = registration.callMethod('update'.toJS);
        if (updated != null && updated.isA<JSPromise>()) {
          await (updated as JSPromise<JSAny?>).toDart;
        }
      } catch (_) {}
      final JSObject? next =
          _asObject(registration['waiting']) ??
          _asObject(registration['installing']);
      if (next != null) {
        try {
          next.callMethod('postMessage'.toJS, 'skipWaiting'.toJS);
        } catch (_) {}
        await _waitUntilSettled(next);
      }
    }
  }

  bool _isFlutterServiceWorker(JSObject registration) {
    final String script = _scriptUrl(registration['active'])
        .isNotEmpty
        ? _scriptUrl(registration['active'])
        : (_scriptUrl(registration['waiting']).isNotEmpty
              ? _scriptUrl(registration['waiting'])
              : _scriptUrl(registration['installing']));
    return script.contains('flutter_service_worker.js');
  }

  String _scriptUrl(JSAny? worker) {
    final JSObject? object = _asObject(worker);
    if (object == null) return '';
    final JSAny? url = object['scriptURL'];
    if (url.isA<JSString>()) return (url as JSString).toDart;
    return '';
  }

  JSObject? _asObject(JSAny? value) {
    if (value != null && value.isA<JSObject>()) return value as JSObject;
    return null;
  }

  Future<void> _waitUntilSettled(JSObject worker) async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 4));
    while (DateTime.now().isBefore(deadline)) {
      final JSAny? state = worker['state'];
      final String name = state.isA<JSString>() ? (state as JSString).toDart : '';
      if (name == 'activated' || name == 'redundant') return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void _reloadPage() {
    final JSAny? location = globalContext['location'];
    if (location == null || !location.isA<JSObject>()) return;
    (location as JSObject).callMethod('reload'.toJS);
  }
}
