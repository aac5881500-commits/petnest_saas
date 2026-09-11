// 檔案名稱：test/chat_error_probe_test.dart
// 功能說明：全域錯誤 probe 不可再拋例外，且能讀出 Firebase／字串錯誤。

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';

void main() {
  test('dump 對 String、null、數字、FlutterErrorDetails 不拋例外', () {
    expect(
      () => ChatErrorProbe.dump('t', 'plain string', StackTrace.empty),
      returnsNormally,
    );
    expect(
      () => ChatErrorProbe.dump('t', null, null),
      returnsNormally,
    );
    expect(
      () => ChatErrorProbe.dump('t', 12, StackTrace.empty),
      returnsNormally,
    );
    expect(
      () => ChatErrorProbe.dump(
        't',
        FlutterErrorDetails(exception: 'inner string'),
        StackTrace.empty,
      ),
      returnsNormally,
    );
  });

  test('describe 顯示 FirebaseException plugin／code／message', () {
    final FirebaseException error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions',
    );
    expect(
      ChatErrorProbe.describe(error),
      contains('[cloud_firestore/permission-denied]'),
    );
    expect(
      ChatErrorProbe.describe(error),
      contains('Missing or insufficient permissions'),
    );
    expect(
      () => ChatErrorProbe.dump('t', error, StackTrace.empty),
      returnsNormally,
    );
  });

  test('describe 顯示 Functions 錯誤，不把 NoSuchMethod 蓋掉', () {
    final FirebaseFunctionsException error = FirebaseFunctionsException(
      code: 'permission-denied',
      message: '沒有執行此操作的權限',
    );
    expect(ChatErrorProbe.describe(error), contains('permission-denied'));
    expect(ChatErrorProbe.describe(error), contains('沒有執行此操作的權限'));
  });
}
