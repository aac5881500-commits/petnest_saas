import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/shop_sharing_service.dart';

void main() {
  test(
    'shared URLs use a customer-accessible production origin during local tests',
    () {
      final link = ShopSharingService.shareLink('abc');
      expect(Uri.parse(link).host, 'petnest-saas.web.app');
      expect(link, isNot(contains('localhost')));
    },
  );

  test(
    'missing or failing sharing backend gives an actionable Chinese message',
    () {
      for (final code in ['internal', 'not-found', 'unimplemented']) {
        final message = ShopSharingService.errorMessage(
          FirebaseFunctionsException(code: code, message: code),
        );
        expect(message, contains('後端服務已部署'));
        expect(message, isNot(code));
      }
    },
  );
  test('network, login and permission errors stay distinct', () {
    expect(
      ShopSharingService.errorMessage(
        FirebaseFunctionsException(code: 'unavailable', message: ''),
      ),
      contains('連線'),
    );
    expect(
      ShopSharingService.errorMessage(
        FirebaseFunctionsException(code: 'unauthenticated', message: ''),
      ),
      contains('重新登入'),
    );
    expect(
      ShopSharingService.errorMessage(
        FirebaseFunctionsException(code: 'permission-denied', message: ''),
      ),
      contains('權限'),
    );
  });
  test(
    'business validation messages remain useful without displaying raw codes',
    () {
      expect(
        ShopSharingService.errorMessage(
          FirebaseFunctionsException(
            code: 'already-exists',
            message: '這組搜尋碼已被使用，請換一組',
          ),
        ),
        '這組搜尋碼已被使用，請換一組',
      );
      expect(
        ShopSharingService.errorMessage(
          FirebaseFunctionsException(code: 'unknown', message: 'INTERNAL'),
        ),
        contains('請稍後重試'),
      );
    },
  );

  test(
    'custom search codes normalize and platform sequential codes are rejected',
    () {
      expect(ShopSharingService.parse(' cat_home_2026 '), 'CAT_HOME_2026');
      for (final value in [
        'SHOP0018',
        'shop123456789',
        'short',
        'cat home 2026',
        '',
      ]) {
        expect(ShopSharingService.parse(value), isNull);
      }
    },
  );
  test('QR URLs and raw tokens preserve case and accept the same payload', () {
    final token = List.filled(48, 'a').join();
    expect(ShopSharingService.parse(token), token);
    expect(ShopSharingService.parse('https://petnest.tw/s/$token'), token);
    expect(ShopSharingService.parse('https://petnest.tw/s/SHOP0018'), isNull);
    expect(ShopSharingService.parse('https://petnest.tw/other/$token'), isNull);
  });
}
