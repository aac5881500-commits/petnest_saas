import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/platform_account_display.dart';
import 'package:petnest_saas/features/platform/platform_account_display.dart';

void main() {
  test('最高管理員姓名與 Email 依 UID 對應，不使用其他帳號', () {
    final PlatformAccountDisplay self = PlatformAccountDisplay.resolve(
      platformName: '',
      platformDisplayName: '',
      authDisplayName: '最高管理員',
      profileName: '會員名稱',
      authEmail: 'root@example.com',
      platformEmail: '',
      profileEmail: 'profile@example.com',
      uid: 'root-uid',
    );
    expect(self.name, '最高管理員');
    expect(self.email, 'root@example.com');

    final PlatformAccountDisplay stored = PlatformAccountDisplay.resolve(
      platformName: '平台姓名',
      authDisplayName: 'Auth 姓名',
      authEmail: 'auth@example.com',
      platformEmail: 'platform@example.com',
      uid: 'root-uid',
    );
    expect(stored.name, '平台姓名');
    expect(stored.email, 'auth@example.com');

    final PlatformAccountDisplay blank = PlatformAccountDisplay.resolve(
      platformEmail: 'root-uid',
      authEmail: '',
      uid: 'root-uid',
    );
    expect(blank.name, isEmpty);
    expect(blank.email, isEmpty);
  });

  test('業務身分錯誤不把 internal 顯示成尚未指派', () {
    expect(
      PlatformAccountDisplay.describeSalesFailure(
        code: 'internal',
        message: 'internal',
      ),
      contains('getSalesIdentity'),
    );
    expect(
      PlatformAccountDisplay.describeSalesFailure(
        code: 'not-found',
        message: 'NOT_FOUND',
        notFound: true,
      ),
      contains('setSalesIdentity'),
    );
    expect(
      PlatformAccountDisplay.describeSalesFailure(
        code: 'permission-denied',
        message: 'internal',
        permissionDenied: true,
      ),
      '沒有查看或設定業務身分的權限。',
    );
    expect(
      PlatformAccountDisplay.describeSalesFailure(
        code: 'failed-precondition',
        message: '這個帳號的業務資料不一致，沒有自動合併或刪除',
      ),
      contains('不一致'),
    );
  });

  testWidgets('最高管理員唯讀資料在手機與桌機不溢出', (WidgetTester tester) async {
    Future<void> pump(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                PlatformLockedAccountFields(
              name: '',
              email: 'root@example.com',
              uid: '7FNrECQeqAca9Vu8lBBzTSdcJcg1',
              sales: const Card(
                child: Row(
                  children: [
                    Expanded(child: Text('兼任業務\n只增減業務資格，不改變平台角色。')),
                    Switch(value: false, onChanged: null),
                  ],
                ),
              ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('尚未設定'), findsOneWidget);
      expect(find.text('root@example.com'), findsOneWidget);
      expect(find.text('超級管理員'), findsOneWidget);
      expect(find.text('最高管理員角色受到保護，不能在此修改。'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    }

    await pump(const Size(360, 800));
    await pump(const Size(1280, 900));
    await tester.binding.setSurfaceSize(null);
  });
}
