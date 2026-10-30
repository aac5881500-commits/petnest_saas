import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/platform/models/inspection_error_message.dart';

void main() {
  test('internal transport failure names the service that needs checking', () {
    final text = inspectionErrorMessage('internal', 'internal');
    expect(text, contains('inspectShop'));
    expect(text, contains('asia-east1'));
    expect(text, isNot('internal'));
  });
  test(
    'missing endpoint identifies deployment without a false sent status',
    () {
      final text = inspectionErrorMessage('not-found', 'NOT FOUND');
      expect(text, contains('尚未啟用'));
      expect(text, contains('部署'));
      expect(text, isNot(contains('已寄送')));
    },
  );
  test('keeps specific safe server delivery and rate limit messages', () {
    expect(
      inspectionErrorMessage('failed-precondition', '尚未設定查核驗證碼寄信服務。'),
      '尚未設定查核驗證碼寄信服務。',
    );
    expect(
      inspectionErrorMessage('resource-exhausted', '一小時內驗證碼申請次數已達上限。'),
      '一小時內驗證碼申請次數已達上限。',
    );
  });
  test('does not expose technical English errors to the user', () {
    expect(
      inspectionErrorMessage('unavailable', 'UNAVAILABLE'),
      contains('稍後再試'),
    );
    expect(
      inspectionErrorMessage('unknown', 'TypeError at server.js'),
      isNot(contains('TypeError')),
    );
  });
}
