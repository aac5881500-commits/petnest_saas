import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/shop_content_order.dart';
import 'package:petnest_saas/features/shop/pages/shop_faq_page.dart';
import 'package:petnest_saas/features/shop/widgets/content/shop_content_editor_dialog.dart';

void main() {
  test('FAQ 刪除後新增採用最大排序值，舊同值排序可正確移動', () {
    expect(nextShopFaqSortOrder([1, 3]), 4);
    expect(nextShopFaqSortOrder([]), 1);
    expect(nextShopFaqSortOrder([1, '3']), 4);
    expect(
      compareShopFaqOrder(
        firstId: 'b',
        firstOrder: 3,
        secondId: 'a',
        secondOrder: 3,
      ),
      greaterThan(0),
    );
    expect(movedShopFaqRanks(['first', 'a', 'b'], 2, 1), {
      'first': 1,
      'b': 2,
      'a': 3,
    });
    expect(shopFaqSortOrder(double.nan), 999);
  });

  Future<void> openEditor(
    WidgetTester tester, {
    required Future<void> Function(ShopContentDraft) save,
    bool isFaq = true,
    String type = 'normal',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => ShopContentEditorDialog(
                  isFaq: isFaq,
                  isNew: true,
                  initial: ShopContentDraft(
                    title: '',
                    body: '',
                    isPublished: true,
                    type: type,
                  ),
                  onSave: save,
                ),
              ),
              child: const Text('開啟編輯'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟編輯'));
    await tester.pumpAndSettle();
  }

  testWidgets('儲存期間防重送並鎖住返回，失敗後保留草稿可重試', (tester) async {
    var calls = 0;
    final firstSave = Completer<void>();
    await openEditor(
      tester,
      save: (draft) async {
        calls++;
        expect(draft.title, '入住準備');
        expect(draft.body, '請帶慣用飼料');
        if (calls == 1) await firstSave.future;
      },
    );
    await tester.enterText(find.byType(TextFormField).at(0), '入住準備');
    await tester.enterText(find.byType(TextFormField).at(1), '請帶慣用飼料');
    await tester.tap(find.text('儲存'));
    await tester.pump();
    await tester.tap(find.text('儲存中…'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(ShopContentEditorDialog), findsOneWidget);
    firstSave.completeError(StateError('simulated write failure'));
    await tester.pumpAndSettle();
    expect(find.textContaining('儲存失敗，內容已保留'), findsOneWidget);
    expect(find.text('入住準備'), findsOneWidget);
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(ShopContentEditorDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空標題有提示，取消未存內容需確認', (tester) async {
    var calls = 0;
    await openEditor(tester, save: (_) async => calls++);
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(find.text('請填寫問題'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(find.byType(TextFormField).first, '尚未完成的問題');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('尚未儲存'), findsOneWidget);
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(find.text('尚未完成的問題'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄變更並離開'));
    await tester.pumpAndSettle();
    expect(find.byType(ShopContentEditorDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手機大字與未知公告類型能安全編輯', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    await openEditor(
      tester,
      isFaq: false,
      type: 'legacy-unknown',
      save: (_) async {},
    );
    expect(find.text('一般公告'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('前台 FAQ 讀取錯誤有重試，隱藏項目不會出現在列表', (tester) async {
    final shop = StreamController<Map<String, dynamic>?>.broadcast();
    final faqs = StreamController<List<Map<String, dynamic>>>.broadcast();
    addTearDown(shop.close);
    addTearDown(faqs.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ShopFaqPage(
          shopId: 'test-shop',
          shopStream: shop.stream,
          faqStream: faqs.stream,
        ),
      ),
    );
    shop.add({'showFaqSection': true});
    await tester.pump();
    faqs.addError(StateError('read failed'));
    await tester.pumpAndSettle();
    expect(find.text('常見問題暫時無法載入。'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
    faqs.add([
      {'id': 'a', 'question': '已上架問題', 'isPublished': true, 'sortOrder': 1},
      {'id': 'b', 'question': '未上架問題', 'isPublished': false, 'sortOrder': 2},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('已上架問題'), findsOneWidget);
    expect(find.text('未上架問題'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
