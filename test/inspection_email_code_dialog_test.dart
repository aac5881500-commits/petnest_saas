import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/platform/widgets/inspection_email_code_dialog.dart';

void main() {
  final delivery = <String, dynamic>{
    'challengeId': 'a' * 32,
    'maskedEmail': 'r***@example.test',
    'retryAfterSeconds': 60,
  };
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    Map<String, dynamic>? initial,
    Future<Map<String, dynamic>> Function()? resend,
    Future<String> Function(String, String)? verify,
    ValueChanged<String?>? result,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final token = await showDialog<String>(
                  context: context,
                  builder: (_) => InspectionEmailCodeDialog(
                    initialDelivery: initial ?? delivery,
                    onResend: resend ?? () async => delivery,
                    onVerify: verify ?? (_, _) async => 'session-token',
                  ),
                );
                result?.call(token);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('code is masked and Google login is absent', (tester) async {
    await open(tester);
    expect(find.text('驗證碼已寄至 r***@example.test。'), findsOneWidget);
    expect(find.textContaining('秒後可重新寄送'), findsOneWidget);
    expect(find.text('登入密碼'), findsNothing);
    expect(find.textContaining('Google'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });
  testWidgets('six-digit verification returns session and uses challenge', (
    tester,
  ) async {
    String? token;
    String? challenge;
    String? sentCode;
    await open(
      tester,
      verify: (id, code) async {
        challenge = id;
        sentCode = code;
        return 'verified-session';
      },
      result: (value) => token = value,
    );
    await tester.enterText(find.byType(TextField), 'ab1234567');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '123456',
    );
    await tester.tap(find.text('驗證並解鎖'));
    await tester.pumpAndSettle();
    expect(challenge, 'a' * 32);
    expect(sentCode, '123456');
    expect(token, 'verified-session');
    expect(find.byType(InspectionEmailCodeDialog), findsNothing);
  });
  testWidgets('expired code stays locked and resend replaces old challenge', (
    tester,
  ) async {
    var sends = 0;
    await open(
      tester,
      initial: {...delivery, 'retryAfterSeconds': 0},
      verify: (_, _) async => throw Exception('驗證碼已過期，請重新寄送。'),
      resend: () async {
        sends++;
        return {...delivery, 'challengeId': 'b' * 32};
      },
    );
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('驗證並解鎖'));
    await tester.pumpAndSettle();
    expect(find.text('驗證碼已過期，請重新寄送。'), findsOneWidget);
    await tester.ensureVisible(find.text('重新寄送驗證碼'));
    await tester.tap(find.text('重新寄送驗證碼'));
    await tester.pumpAndSettle();
    expect(sends, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.textContaining('秒後可重新寄送'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });
  testWidgets('phone enlarged text keeps verification accessible', (
    tester,
  ) async {
    await open(tester, size: const Size(320, 700), scale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
