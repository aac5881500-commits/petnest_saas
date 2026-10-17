import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/features/auth/pages/shop_activation_code_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('後端沒有回傳模板時，不把預設值當成已確認業態', () {
    final ShopActivationCheck ready = ShopActivationCheck.fromResponse(
      <String, dynamic>{
        'ok': true,
        'status': 'ready',
        'message': '激活碼可以用於開店',
        'salesRepId': 'rep-secret',
        'code': 'NEST7788',
      },
    );
    expect(ready.valid, isTrue);
    expect(ready.module, isNull);
    expect(ready.message.contains('NEST7788'), isFalse);

    final ShopActivationCheck cat = ShopActivationCheck.fromResponse(
      <String, dynamic>{
        'ok': true,
        'status': 'ready',
        'module': 'cat_hotel',
      },
    );
    expect(cat.module, 'cat_hotel');
    expect(shopActivationModuleLabel(cat.module), '貓咪旅館');
    expect(
      shopActivationModuleLabel('cat_boarding'),
      isEmpty,
    );

    final ShopActivationCheck used = ShopActivationCheck.fromResponse(
      <String, dynamic>{
        'ok': false,
        'status': 'exhausted',
        'message': '激活碼已用完',
      },
    );
    expect(used.valid, isFalse);
    expect(used.message, '激活碼已用完');
    expect(
      shopActivationCallableMessage('unavailable', 'FirebaseException'),
      '網路連線失敗，請稍後再試',
    );
    expect(
      shopActivationCallableMessage('resource-exhausted', 'raw'),
      '嘗試次數過多，請稍後再試',
    );
    expect(
      shopActivationCallableMessage('internal', 'INTERNAL'),
      '驗證服務暫時無法使用',
    );
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ShopActivationValidator? validate,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: PetNestAppTheme.build(),
        home: ShopActivationCodePage(validate: validate),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('空白激活碼不能送出，LINE 入口不可點', (WidgetTester tester) async {
    await pumpPage(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '驗證並繼續 →'),
    );
    expect(button.onPressed, isNull);
    final OutlinedButton line = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '聯絡官方 LINE（即將開放）'),
    );
    expect(line.onPressed, isNull);
    await tester.tap(find.text('聯絡官方 LINE（即將開放）'));
    await tester.pump();
    expect(find.text('開啟你的 PetNest 旅程'), findsOneWidget);
  });

  testWidgets('桌機寬度內容置中', (WidgetTester tester) async {
    await pumpPage(tester, size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    final Rect title = tester.getRect(find.text('開啟你的 PetNest 旅程'));
    final Rect page = tester.getRect(find.byType(ShopActivationCodePage));
    expect((title.center.dx - page.center.dx).abs(), lessThan(80));
  });

  testWidgets('錯誤激活碼停留在驗證頁並顯示中文', (WidgetTester tester) async {
    await pumpPage(
      tester,
      validate: (String code) async {
        return ShopActivationCheck(
          valid: false,
          message: code.isEmpty ? '空白' : '找不到此激活碼',
        );
      },
    );
    await tester.enterText(find.byType(TextField), 'NO-SUCH');
    await tester.pump();
    await tester.ensureVisible(find.text('驗證並繼續 →'));
    await tester.tap(find.text('驗證並繼續 →'));
    await tester.pumpAndSettle();
    expect(find.text('找不到此激活碼'), findsOneWidget);
    expect(find.text('歡迎加入 PetNest！'), findsNothing);
    expect(find.text('NO-SUCH'), findsOneWidget);
  });

  testWidgets('驗證成功後進入歡迎頁，改碼會取消前往', (WidgetTester tester) async {
    var calls = 0;
    await pumpPage(
      tester,
      validate: (String code) async {
        calls += 1;
        return ShopActivationCheck(
          valid: true,
          message: '激活碼可以用於開店',
          module: code == 'CAT-1' ? 'cat_hotel' : null,
        );
      },
    );
    await tester.enterText(find.byType(TextField), 'CAT-1');
    await tester.pump();
    await tester.ensureVisible(find.text('驗證並繼續 →'));
    await tester.tap(find.text('驗證並繼續 →'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'CAT-2');
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('歡迎加入 PetNest！'), findsNothing);
    expect(find.text('激活碼已變更，請重新驗證'), findsOneWidget);
    expect(calls, 1);

    await tester.enterText(find.byType(TextField), 'CAT-1');
    await tester.pump();
    await tester.ensureVisible(find.text('驗證並繼續 →'));
    await tester.tap(find.text('驗證並繼續 →'));
    await tester.pump();
    await tester.pump();
    expect(find.text('開通類型：貓咪旅館'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('歡迎加入 PetNest！'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('驗證中不能重複送出', (WidgetTester tester) async {
    var calls = 0;
    final Completer<ShopActivationCheck> gate = Completer<ShopActivationCheck>();
    await pumpPage(
      tester,
      validate: (String code) {
        calls += 1;
        return gate.future;
      },
    );
    await tester.enterText(find.byType(TextField), 'CAT-1');
    await tester.pump();
    await tester.ensureVisible(find.text('驗證並繼續 →'));
    await tester.tap(find.text('驗證並繼續 →'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    gate.complete(
      const ShopActivationCheck(valid: false, message: '激活碼已停用'),
    );
    await tester.pumpAndSettle();
    expect(find.text('激活碼已停用'), findsOneWidget);
  });
}
