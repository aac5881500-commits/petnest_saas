import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/payment_model.dart';
import 'package:petnest_saas/features/payment/widgets/ecpay_payment_information.dart';

PaymentModel info(String method) => PaymentModel.fromMap(
  id: 'payment-fixture',
  data: {
    'shopId': 'shop-fixture',
    'sourceType': 'store_order',
    'sourceId': 'order-fixture',
    'paymentMethod': method,
    'amount': 180,
    'status': 'awaiting_payment',
    'atmBankCode': '812',
    'atmAccount': '1234567890123456789012345678901234567890',
    'cvsPaymentCode': 'CVS1234567890123456789012345678901234567890',
    'expireAt': DateTime(2026, 10, 25, 23, 59),
  },
);

void main() {
  testWidgets('320px ATM 資訊可換行與複製，付款期限清楚可見', (tester) async {
    await tester.runAsync(() async {
      await Future.wait([
        (FontLoader('NotoSansTC')..addFont(
              rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
            ))
            .load(),
        (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load(),
      ]);
    });
    final base = ThemeData(fontFamily: 'NotoSansTC');
    TextStyle font(TextStyle? style, double weight) =>
        (style ?? const TextStyle()).copyWith(
          fontFamily: 'NotoSansTC',
          fontVariations: [ui.FontVariation('wght', weight)],
        );
    final theme = base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyLarge: font(base.textTheme.bodyLarge, 400),
        bodyMedium: font(base.textTheme.bodyMedium, 400),
        titleLarge: font(base.textTheme.titleLarge, 700),
        titleMedium: font(base.textTheme.titleMedium, 500),
        labelLarge: font(base.textTheme.labelLarge, 500),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            appBar: AppBar(title: const Text('綠界線上付款')),
            body: EcpayPaymentInformation(payment: info('atm'), onRetry: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ATM 繳款資訊'), findsOneWidget);
    expect(find.text('應付金額：NT\$ 180'), findsOneWidget);
    expect(find.textContaining('付款期限：2026/10/25 23:59'), findsOneWidget);
    expect(find.byType(SelectableText), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    final preview = Platform.environment['PETNEST_PAYMENT_PREVIEW'];
    if (preview != null && preview.isNotEmpty) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await Directory(preview).create(recursive: true);
          await File(
            '$preview/store-payment-atm-320.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          rendered.dispose();
        }
      });
    }
    await tester.tap(find.text('複製繳款帳號'));
    await tester.pump();
    expect(copied, info('atm').atmVirtualAccount);
    expect(find.text('已複製繳款帳號'), findsOneWidget);
  });

  testWidgets('320px 超商長代碼可選取，不顯示 ATM 欄位', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EcpayPaymentInformation(
            payment: info('cvs_code'),
            onRetry: () {},
          ),
        ),
      ),
    );
    expect(find.text('超商繳費資訊'), findsOneWidget);
    expect(
      find.text(info('cvs_code').convenienceStorePaymentCode),
      findsOneWidget,
    );
    expect(find.text('銀行代碼'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('讀取失敗、缺失或未完成資料皆有重新讀取入口', (tester) async {
    var retries = 0;
    Future<void> display({PaymentModel? payment, String? error}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EcpayPaymentInformation(
                payment: payment,
                error: error,
                onRetry: () => retries++,
              ),
            ),
          ),
        );
    await display(error: '付款資料讀取失敗');
    expect(find.text('付款資料讀取失敗'), findsOneWidget);
    await tester.tap(find.text('重新讀取付款資訊'));
    expect(retries, 1);
    await display();
    expect(find.textContaining('目前沒有付款資訊'), findsOneWidget);
    await tester.tap(find.text('重新讀取付款資訊'));
    expect(retries, 2);
    await display(payment: info('credit_card'));
    expect(find.textContaining('付款資訊尚未完成更新'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
