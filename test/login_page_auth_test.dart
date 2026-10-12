import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('登入頁保留記住帳號，並可打開重設密碼卡片', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    expect(find.text('記住帳號'), findsOneWidget);
    expect(find.text('忘記密碼？'), findsOneWidget);
    expect(find.text('Apple 登入即將開放'), findsNothing);

    await tester.tap(find.text('忘記密碼？'));
    await tester.pumpAndSettle();

    expect(find.text('重設密碼'), findsOneWidget);
    expect(find.text('寄送重設密碼信'), findsOneWidget);
    expect(find.text('返回登入'), findsOneWidget);
    expect(find.textContaining('如果重設連結已過期或已使用'), findsOneWidget);

    await tester.tap(find.text('寄送重設密碼信'));
    await tester.pump();
    expect(find.text('請輸入電子郵件。'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bad-mail');
    await tester.tap(find.text('寄送重設密碼信'));
    await tester.pump();
    expect(find.text('電子郵件格式不正確，請重新確認。'), findsOneWidget);

    await tester.tap(find.text('返回登入'));
    await tester.pumpAndSettle();
    expect(find.text('歡迎回來'), findsOneWidget);
  });

  testWidgets('登入前空白檢查不顯示 Firebase 原文', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('登入'));
    await tester.pump();
    expect(find.text('請輸入電子郵件。'), findsOneWidget);
    expect(find.textContaining('firebase_auth'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'member@petnest.app');
    await tester.tap(find.text('登入'));
    await tester.pump();
    expect(find.text('請輸入密碼。'), findsOneWidget);
  });
}
