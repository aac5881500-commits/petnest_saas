import 'inspection_browser_bridge.dart';
import 'dart:async';
import 'dart:math';

_Preview? _current;
void closeInspectionOwnerWindow() {
  _current?.close();
  _current = null;
}

Future<void> openInspectionOwnerWindow({
  required Future<Map<String, dynamic>> Function(String) authorize,
  required Future<void> Function(String) onTouch,
  required void Function(Object) onFailure,
  required bool Function() isAlive,
}) {
  closeInspectionOwnerWindow();
  final random = Random.secure();
  final nonce = List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final url = Uri.base.replace(
    queryParameters: {'ownerInspection': nonce},
    fragment: '',
  );
  final child = InspectionBrowserPeer.open(url.toString(), 'inspection_$nonce');
  final preview = _Preview(
    child,
    nonce,
    authorize,
    onTouch,
    onFailure,
    isAlive,
  );
  _current = preview;
  return preview.ready.future;
}

class _Preview {
  _Preview(
    this.child,
    this.nonce,
    this.authorize,
    this.onTouch,
    this.onFailure,
    this.isAlive,
  ) {
    listener = inspectionBrowserMessages().listen(_message);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (child.closed == true) {
        close();
      } else if (!ready.isCompleted &&
          DateTime.now().difference(started).inSeconds > 90) {
        _fail(StateError('查核視窗連線逾時，請允許彈出視窗後重試'));
      }
    });
  }
  final InspectionBrowserPeer child;
  final String nonce;
  final Future<Map<String, dynamic>> Function(String) authorize;
  final Future<void> Function(String) onTouch;
  final void Function(Object) onFailure;
  final bool Function() isAlive;
  final ready = Completer<void>();
  final started = DateTime.now();
  late final StreamSubscription<InspectionBrowserMessage> listener;
  late final Timer timer;
  bool authorizing = false, touching = false, closed = false;
  Future<void> _message(InspectionBrowserMessage event) async {
    if (closed ||
        event.origin != Uri.base.origin ||
        !child.matchesSource(event) ||
        event.data is! Map) {
      return;
    }
    final data = Map<String, dynamic>.from(event.data as Map);
    if (data['nonce'] != nonce) return;
    try {
      if (data['type'] == 'inspection-ping') {
        if (!isAlive()) throw StateError('平台查核已鎖定');
        child.post({
          'type': 'inspection-alive',
          'nonce': nonce,
        }, Uri.base.origin);
        return;
      }
      if (data['type'] == 'inspection-error') {
        throw StateError('${data['message'] ?? '查核視窗無法啟動'}');
      }
      if (data['type'] == 'inspection-request' && !authorizing) {
        authorizing = true;
        try {
          final grant = await authorize(data['idToken'] as String);
          if (closed) return;
          child.post({
            'type': 'inspection-grant',
            'nonce': nonce,
            ...grant,
          }, Uri.base.origin);
        } finally {
          authorizing = false;
        }
      } else if (data['type'] == 'inspection-ready') {
        if (!ready.isCompleted) ready.complete();
      } else if (data['type'] == 'inspection-touch' && !touching) {
        touching = true;
        try {
          await onTouch('${data['route'] ?? ''}');
        } finally {
          touching = false;
        }
      }
    } catch (e, st) {
      if (!ready.isCompleted) {
        ready.completeError(e, st);
      } else {
        onFailure(e);
      }
      close();
    }
  }

  void _fail(Object error) {
    if (!ready.isCompleted) {
      ready.completeError(error);
    } else {
      onFailure(error);
    }
    close();
  }

  void close() {
    if (closed) return;
    closed = true;
    if (identical(_current, this)) _current = null;
    timer.cancel();
    listener.cancel();
    child.close();
    if (!ready.isCompleted) ready.completeError(StateError('查核視窗已關閉'));
  }
}
