import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/pages/campaigns/shop_campaign_editor_page.dart';

const members = [
  {
    'id': 'normal',
    'name': '正常客戶',
    'phone': '0911000001',
    'reachable': true,
    'restricted': false,
    'accountReachable': true,
  },
  {
    'id': 'blocked',
    'name': '受限客戶',
    'phone': '0911000002',
    'reachable': false,
    'restricted': true,
    'accountReachable': true,
  },
];
Future<void> fill(WidgetTester tester) async {
  final title = find.widgetWithText(TextFormField, '通知標題 *');
  await tester.scrollUntilVisible(
    title,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.enterText(title, '會員服務事項說明');
  final body = find.widgetWithText(TextFormField, '通知內容 *');
  await tester.ensureVisible(body);
  await tester.pumpAndSettle();
  await tester.enterText(body, '請聯繫本店確認相關服務事項。');
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'personal defaults to explicit recipients and blocks ordinary contact to restricted member at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var previews = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: ShopCampaignEditorPage(
              shopId: 's',
              canSend: true,
              initialPurpose: 'personal',
              api: (action, data) async {
                if (action == 'members') {
                  return {'accountNotices': true, 'members': members};
                }
                if (action == 'preview') previews++;
                return {};
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final audience = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>).first,
        );
        expect(audience.initialValue, 'selected');
        final restricted = find.widgetWithText(CheckboxListTile, '受限客戶');
        await tester.scrollUntilVisible(
          restricted,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(restricted).onChanged, isNull);
        await fill(tester);
        await tester.tap(find.text('預覽並發送'));
        await tester.pumpAndSettle();
        expect(previews, 0);
        expect(find.text('請至少勾選一位會員。'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'account notices select restricted recipient, preview name and send only after confirmation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var sends = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ShopCampaignEditorPage(
            shopId: 's',
            canSend: true,
            initialPurpose: 'member_account',
            api: (action, data) async {
              if (action == 'members') {
                return {'accountNotices': true, 'members': members};
              }
              if (action == 'preview') {
                final draft = data['draft'] as Map;
                expect(draft['purpose'], 'member_account');
                expect(draft['category'], 'shop_notice');
                expect(draft['audience'], 'selected');
                expect(draft['memberIds'], ['blocked']);
                expect(draft['channel'], 'push');
                return {
                  'campaign': {'version': 1},
                  'preview': {
                    'count': 1,
                    'excluded': 0,
                    'revision': 'r',
                    'recipients': [
                      {'name': '受限客戶', 'restricted': true},
                    ],
                    'restrictedCount': 1,
                  },
                };
              }
              if (action == 'send') {
                sends++;
                return {};
              }
              throw StateError(action);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final audience = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).first,
      );
      expect(audience.initialValue, 'selected');
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('全店會員'), findsNothing);
      expect(find.text('常客（VIP 標籤）'), findsNothing);
      await tester.tap(find.text('指定會員／個別客戶').last);
      await tester.pumpAndSettle();
      final restricted = find.widgetWithText(CheckboxListTile, '受限客戶');
      await tester.scrollUntilVisible(
        restricted,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(restricted).onChanged, isNotNull);
      await tester.tap(restricted);
      await tester.pumpAndSettle();
      final template = find.text('套用告知範本 ▾');
      await tester.scrollUntilVisible(
        template,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(template);
      await tester.pumpAndSettle();
      await tester.tap(find.text('服務限制告知範本'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('預覽並發送'));
      await tester.pumpAndSettle();
      expect(find.textContaining('• 受限客戶'), findsOneWidget);
      expect(sends, 0);
      await tester.tap(find.text('確認發送給 1 位'));
      await tester.pumpAndSettle();
      expect(sends, 1);
    },
  );
  testWidgets(
    'legacy backend cannot send account detail without privacy support',
    (tester) async {
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ShopCampaignEditorPage(
            shopId: 's',
            canSend: true,
            initialPurpose: 'member_account',
            api: (action, data) async {
              if (action == 'members') return {'members': members};
              writes++;
              return {};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.text('預覽並發送'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.textContaining('目前不會送出'), findsOneWidget);
    },
  );
}
