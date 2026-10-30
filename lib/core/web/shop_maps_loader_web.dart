import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:universal_html/html.dart' as html;

const _key = String.fromEnvironment('GOOGLE_MAPS_WEB_API_KEY');
bool get shopMapsConfigured =>
    _key.isNotEmpty &&
    const String.fromEnvironment('GOOGLE_MAPS_MAP_ID').isNotEmpty;
Future<void>? _pending;
@JS('google.maps.importLibrary')
external JSPromise<JSAny?> _importLibrary(JSString name);
Future<void> ensureShopMapsLoaded() =>
    _pending ??= _load().catchError((Object error) {
      _pending = null;
      throw error;
    });
Future<void> _load() async {
  if (!shopMapsConfigured) throw StateError('地圖尚未啟用');
  final google = globalContext.getProperty<JSAny?>('google'.toJS);
  final maps = google != null && google.isA<JSObject>()
      ? (google as JSObject).getProperty<JSAny?>('maps'.toJS)
      : null;
  final hasMaps =
      maps != null &&
      maps.isA<JSObject>() &&
      (maps as JSObject).hasProperty('importLibrary'.toJS).toDart;
  if (!hasMaps) {
    final ready = Completer<void>();
    globalContext.setProperty(
      'petnestMapsReady'.toJS,
      (() {
        if (!ready.isCompleted) ready.complete();
      }).toJS,
    );
    final script = html.ScriptElement()
      ..async = true
      ..src = Uri.https('maps.googleapis.com', '/maps/api/js', {
        'key': _key,
        'loading': 'async',
        'callback': 'petnestMapsReady',
        'libraries': 'marker',
        'language': 'zh-TW',
        'region': 'TW',
        'v': 'quarterly',
      }).toString();
    final error = script.onError.listen((_) {
      if (!ready.isCompleted) {
        ready.completeError(StateError('地圖載入失敗，請確認網路與地圖設定'));
      }
    });
    html.document.head!.append(script);
    try {
      await ready.future.timeout(const Duration(seconds: 20));
    } catch (_) {
      script.remove();
      rethrow;
    } finally {
      await error.cancel();
    }
  }
  await _importLibrary('maps'.toJS).toDart;
  await _importLibrary('marker'.toJS).toDart;
}
