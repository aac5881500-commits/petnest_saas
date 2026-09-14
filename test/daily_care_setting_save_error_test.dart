// 檔案名稱：test/daily_care_setting_save_error_test.dart
// 功能說明：儲存錯誤轉成店主可讀中文，錯誤處理本身不可再拋例外

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';

class _ThrowingToStringError {
  String get code => 'permission-denied';
  String get message => 'Missing or insufficient permissions.';

  @override
  String toString() {
    throw StateError('toString must not be called unsafely');
  }
}

class _ThrowingEverythingError {
  String get code => throw StateError('code boom');
  String get message => throw StateError('message boom');

  @override
  String toString() {
    throw StateError('toString boom');
  }
}

void main() {
  test('permission-denied 顯示權限文案', () {
    final DailyCareSettingSaveException parsed =
        DailyCareSettingSaveException.fromError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Missing or insufficient permissions.',
          ),
        );
    expect(parsed.message, '沒有儲存每日照護設定的權限');
  });

  test('revision 衝突顯示重新載入', () {
    const DailyCareSettingSaveException parsed =
        DailyCareSettingSaveException(
          '設定已被其他人更新，請重新載入後再儲存',
          code: 'revision-conflict',
        );
    expect(
      DailyCareSettingSaveException.fromError(parsed).message,
      '設定已被其他人更新，請重新載入後再儲存',
    );
  });

  test('converted Future 不直接顯示給店主', () {
    final DailyCareSettingSaveException parsed =
        DailyCareSettingSaveException.fromError(
          Exception(
            'Error: Dart exception thrown from converted Future. Use the dart:js_util exception helper to extract it.',
          ),
        );
    expect(parsed.message.contains('converted Future'), isFalse);
    expect(parsed.message, '儲存失敗，請稍後再試');
  });

  test('toString 會拋例外時 fromError 仍回傳中文且不拋錯', () {
    expect(() {
      DailyCareSettingSaveException.fromError(_ThrowingToStringError());
    }, returnsNormally);
    final DailyCareSettingSaveException parsed =
        DailyCareSettingSaveException.fromError(_ThrowingToStringError());
    expect(parsed.message, '沒有儲存每日照護設定的權限');
    expect(parsed.message.contains('converted Future'), isFalse);
  });

  test('code/message/toString 全拋例外時仍有安全中文提示', () {
    final DailyCareSettingSaveException parsed =
        DailyCareSettingSaveException.fromError(_ThrowingEverythingError());
    expect(parsed.message, '儲存失敗，請稍後再試');
  });

  test('safeToString 失敗時回傳空字串', () {
    expect(DailyCareSaveErrorProbe.safeToString(_ThrowingEverythingError()), '');
    expect(DailyCareSaveErrorProbe.readCode(_ThrowingEverythingError()), '');
    expect(DailyCareSaveErrorProbe.readMessage(_ThrowingEverythingError()), '');
  });

  test('Firestore sanitize 轉成純 Map/List/數字', () {
    final Map<String, dynamic> clean = DailyCareSettingFirestoreValue
        .sanitizeMap(<String, dynamic>{
          'titleFontSize': 18.0,
          'enabled': true,
          'labels': <String>['上午場', '下午場'],
          'created': DateTime.utc(2026, 9, 16, 2),
          'nested': <String, dynamic>{'count': 2},
        });
    expect(clean['titleFontSize'], 18.0);
    expect(clean['enabled'], isTrue);
    expect(clean['labels'], <String>['上午場', '下午場']);
    expect(clean['created'], isA<Timestamp>());
    expect(clean['nested'], <String, dynamic>{'count': 2});
  });
}
