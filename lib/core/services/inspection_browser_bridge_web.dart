// Compare native browser peers, not dart:html cross-frame wrapper objects.
import 'dart:async';
import 'dart:js_interop';

@JS('window')
external _BrowserWindow get _window;
@JS('Object.is')
external bool _same(JSAny? a, JSAny? b);
extension type _BrowserWindow(JSObject _) implements JSObject {
  external _BrowserWindow? get opener;
  external bool get closed;
  external _BrowserWindow? open(String url, String name);
  external void close();
  external void postMessage(JSAny? data, String origin);
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}
extension type _Message(JSObject _) implements JSObject {
  external String get origin;
  external JSAny? get data;
  external JSObject? get source;
}

class InspectionBrowserMessage {
  InspectionBrowserMessage._(this.origin, this.data, this.source);
  final String origin;
  final Object? data;
  final JSObject? source;
}

Stream<InspectionBrowserMessage> inspectionBrowserMessages() {
  late StreamController<InspectionBrowserMessage> controller;
  final listener = ((_Message event) {
    controller.add(
      InspectionBrowserMessage._(
        event.origin,
        event.data.dartify(),
        event.source,
      ),
    );
  }).toJS;
  controller = StreamController<InspectionBrowserMessage>(
    onListen: () => _window.addEventListener('message', listener),
    onCancel: () => _window.removeEventListener('message', listener),
  );
  return controller.stream;
}

bool inspectionHasOpener() => _window.opener != null && !_window.opener!.closed;
bool inspectionFromOpener(InspectionBrowserMessage event) =>
    _window.opener != null && _same(event.source, _window.opener);
void inspectionPostToOpener(Map<String, dynamic> data, String origin) =>
    _window.opener?.postMessage(data.jsify(), origin);

class InspectionBrowserPeer {
  InspectionBrowserPeer._(this._raw);
  final _BrowserWindow _raw;
  static InspectionBrowserPeer open(String url, String name) {
    final raw = _window.open(url, name);
    if (raw == null) throw StateError('請允許平台開啟查核視窗後重試');
    return InspectionBrowserPeer._(raw);
  }

  static InspectionBrowserPeer current() => InspectionBrowserPeer._(_window);
  bool get closed => _raw.closed;
  bool matchesSource(InspectionBrowserMessage event) =>
      _same(event.source, _raw);
  void post(Map<String, dynamic> data, String origin) =>
      _raw.postMessage(data.jsify(), origin);
  void close() => _raw.close();
}
