// 功能：房型外觀工作區共用既有資料流，晚加入的分頁也能取得最新值；離頁釋放來源。
import 'dart:async';

class RoomIntroDataStream<T> {
  RoomIntroDataStream(this.source);
  final Stream<T> source;
  final _events = StreamController<T>.broadcast();
  StreamSubscription<T>? _subscription;
  T? _latest;
  bool _hasValue = false;
  Object? _error;
  late final Stream<T> stream = Stream<T>.multi((listener) {
    if (_hasValue) listener.add(_latest as T);
    if (_error != null) listener.addError(_error!);
    final subscription = _events.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
    _subscription ??= source.listen(
      (value) {
        _latest = value;
        _hasValue = true;
        _error = null;
        _events.add(value);
      },
      onError: (Object error, StackTrace stack) {
        _error = error;
        _events.addError(error, stack);
      },
      onDone: _events.close,
    );
  }, isBroadcast: true);
  void dispose() {
    _subscription?.cancel();
    _events.close();
  }
}

/// 首筆資料需有明確結果；取得首筆後維持原本即時監聽，不對閒置資料流計時。
Stream<T> roomIntroInitialLoad<T>(
  Stream<T> source, {
  Duration timeout = const Duration(seconds: 20),
}) => Stream<T>.multi((listener) {
  var received = false;
  final timer = Timer(timeout, () {
    if (!received) listener.addError(TimeoutException('房型資料連線逾時，請檢查網路後重試。'));
  });
  final subscription = source.listen(
    (value) {
      received = true;
      timer.cancel();
      listener.add(value);
    },
    onError: (Object error, StackTrace stack) {
      received = true;
      timer.cancel();
      listener.addError(error, stack);
    },
    onDone: () {
      timer.cancel();
      listener.close();
    },
  );
  listener.onCancel = () {
    timer.cancel();
    return subscription.cancel();
  };
});
