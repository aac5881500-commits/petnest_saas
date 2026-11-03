// 功能：重現關於我們文字編輯、收合及分頁切換生命週期，不接正式資料。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';

void main() {
  testWidgets('編輯理念標題、說明及封面副標題，切換收合不破壞欄位', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ShopAboutManagePage(
          shopId: 'local',
          shopStream: Stream<Map<String, dynamic>?>.value(const {
            'name': '測試店',
            'aboutTitle': '關於我們',
            'homeAppearance': {
              'aboutPage': {
                'principles': [
                  {'id': 'p1', 'title': '貓咪優先', 'text': '安心照護'},
                  {'id': 'p2', 'title': '自然舒適', 'text': '自然'},
                ],
              },
            },
          }),
          saveAbout: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('理念與團隊'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ExpansionTile, '貓咪優先'));
    await tester.pumpAndSettle();
    final title = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '標題（選填）',
    );
    await tester.ensureVisible(title.first);
    await tester.enterText(title.first, '修改理念標題');
    await tester.pumpAndSettle();
    final note = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '簡短說明',
    );
    await tester.ensureVisible(note.first);
    await tester.enterText(note.first, '自己的說明內容');
    await tester.pumpAndSettle();
    await tester.tap(find.text('封面與介紹'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('about-cover-subtitle-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('about-cover-subtitle-field')),
      '修改自己的副標題',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('理念與團隊'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(title.first).controller!.text, '修改理念標題');
    await tester.ensureVisible(
      find.byKey(const PageStorageKey<String>('about-item-principles-p1')),
    );
    await tester.tap(
      find.byKey(const PageStorageKey<String>('about-item-principles-p1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const PageStorageKey<String>('about-item-principles-p1')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(title.first);
    await tester.enterText(title.first, '再次修改');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
