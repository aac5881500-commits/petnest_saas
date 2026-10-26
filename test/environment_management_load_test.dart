import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_manage_page.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('環境介紹 $width 載入完成前禁止預覽與儲存，讀取失敗可重試', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final first = Completer<Map<String, dynamic>?>();
      final retry = Completer<Map<String, dynamic>?>();
      var reads = 0;
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: Size(width, 900)),
            child: child!,
          ),
          home: ShopEnvironmentManagePage(
            shopId: 'test',
            loadShop: () => ++reads == 1 ? first.future : retry.future,
            saveIntro: (_) async {
              writes++;
            },
          ),
        ),
      );
      final save = find
          .ancestor(
            of: find.text('儲存'),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          )
          .first;
      expect(tester.widget<ButtonStyleButton>(save).onPressed, isNull);
      final preview = find
          .ancestor(
            of: find.text(width >= 1100 ? '放大預覽' : '預覽'),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          )
          .first;
      expect(tester.widget<ButtonStyleButton>(preview).onPressed, isNull);
      first.completeError(StateError('connection unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('環境介紹讀取失敗'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(save).onPressed, isNull);
      expect(writes, 0);
      await tester.tap(find.text('重新載入'));
      await tester.pump();
      expect(reads, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      retry.completeError(StateError('permission denied'));
      await tester.pumpAndSettle();
      expect(find.text('環境介紹讀取失敗'), findsOneWidget);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('不存在的店家不會用預設環境內容建立文件', (tester) async {
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ShopEnvironmentManagePage(
          shopId: 'missing',
          loadShop: () async => null,
          saveIntro: (_) async {
            writes++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('環境介紹讀取失敗'), findsOneWidget);
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('讀取尚未完成就離開，完成後不操作已銷毀頁面', (tester) async {
    final pending = Completer<Map<String, dynamic>?>();
    await tester.pumpWidget(
      MaterialApp(
        home: ShopEnvironmentManagePage(
          shopId: 'test',
          loadShop: () => pending.future,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    pending.complete({'environmentIntro': <String, dynamic>{}});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
