// 檔案名稱：test/payment_available_methods_stream_test.dart
// 功能說明：可用付款方式串流的單元測試（Stream.multi 可以被 listen 兩次）

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stream.multi 可以被 listen 兩次', () async {
    final Stream<int> stream = Stream<int>.multi((
      MultiStreamController<int> listener,
    ) {
      listener.add(1);
      listener.onCancel = () async {};
    });

    final List<int> first = await stream.take(1).toList();
    final List<int> second = await stream.take(1).toList();
    expect(first, <int>[1]);
    expect(second, <int>[1]);
  });
}
