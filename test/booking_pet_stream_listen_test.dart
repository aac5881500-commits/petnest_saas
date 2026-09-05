// 檔案名稱：test/booking_pet_stream_listen_test.dart
// 功能說明：確認寵物 Stream 不可被兩個 listener 重複訂閱，避免整頁建置失敗。

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('單次訂閱 Stream.value 被聽第二次會丟 StateError', () {
    final Stream<List<Map<String, dynamic>>> stream =
        Stream<List<Map<String, dynamic>>>.value(
          const <Map<String, dynamic>>[],
        );
    stream.listen((_) {});
    expect(() => stream.listen((_) {}), throwsA(isA<StateError>()));
  });

  test('broadcast 空列表 Stream 可被聽兩次', () {
    final Stream<List<Map<String, dynamic>>> stream =
        Stream<List<Map<String, dynamic>>>.value(
          const <Map<String, dynamic>>[],
        ).asBroadcastStream();
    stream.listen((_) {});
    stream.listen((_) {});
  });
}
