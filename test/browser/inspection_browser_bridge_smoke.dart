// Standalone real-browser smoke test; no Firebase credentials or production data.
import 'dart:js_interop';
import 'package:petnest_saas/core/services/inspection_browser_bridge.dart';

@JS('window')
external _TestWindow get _window;
extension type _TestWindow(JSObject _) implements JSObject {
  external _TestDocument get document;
  external _TestWindow open(String url, String name);
  external void postMessage(JSAny? data, String origin);
}
extension type _TestDocument(JSObject _) implements JSObject {
  external _TestBody get body;
  external void write(String html);
  external void close();
}
extension type _TestBody(JSObject _) implements JSObject {
  external set textContent(String value);
}
void require(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<InspectionBrowserMessage> message(String nonce) =>
    inspectionBrowserMessages()
        .firstWhere(
          (event) => event.data is Map && (event.data as Map)['nonce'] == nonce,
        )
        .timeout(const Duration(seconds: 8));
Future<void> main() async {
  final results = <String>[];
  InspectionBrowserPeer? child;
  try {
    require(!inspectionHasOpener(), 'missing opener must reject');
    inspectionPostToOpener({'type': 'inspection-error'}, Uri.base.origin);
    results.add('PASS：沒有平台來源時安全拒絕，錯誤回報不會卡住');
    final pendingSelf = message('self');
    _window.postMessage({'nonce': 'self'}.jsify(), Uri.base.origin);
    final self = await pendingSelf;
    require(
      InspectionBrowserPeer.current().matchesSource(self),
      'self identity mismatch',
    );
    require(!inspectionFromOpener(self), 'self must not become opener');
    results.add('PASS：原生來源比對與訊息反序列化');
    final pendingReady = message('child-ready');
    child = InspectionBrowserPeer.open(
      'about:blank',
      'inspection_bridge_smoke',
    );
    final rawChild = _window.open('', 'inspection_bridge_smoke');
    rawChild.document.write(
      "<!doctype html><title>查核連線測試</title><script>window.addEventListener('message',function(e){if(e.source!==opener||e.origin!==location.origin)return;opener.postMessage({nonce:e.data.nonce,type:'inspection-echo'},location.origin);});opener.postMessage({nonce:'child-ready'},location.origin);</script>",
    );
    rawChild.document.close();
    final ready = await pendingReady;
    require(child.matchesSource(ready), 'child identity mismatch');
    require(!child.matchesSource(self), 'other window source accepted');
    final pendingEcho = message('echo');
    child.post({'nonce': 'echo', 'type': 'inspection-grant'}, Uri.base.origin);
    final echo = await pendingEcho;
    require(
      child.matchesSource(echo) &&
          (echo.data as Map)['type'] == 'inspection-echo',
      'roundtrip failed',
    );
    results.add('PASS：父子視窗雙向傳訊、精確視窗來源、拒絕其他視窗');
    child.close();
    require(child.closed, 'close failed');
    results.add('PASS：關閉後可辨識視窗已結束');
    _window.document.body.textContent = "4 / 4 通過\n${results.join('\n')}";
  } catch (error) {
    child?.close();
    _window.document.body.textContent = "FAIL：$error\n${results.join('\n')}";
  }
}
