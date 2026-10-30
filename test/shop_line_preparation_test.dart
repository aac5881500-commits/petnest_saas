import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/pages/campaigns/shop_line_preparation_page.dart';

Map<String, dynamic> status({
  bool canEdit = true,
  int version = 0,
  Map<String, dynamic> config = const {},
}) => {
  'canEdit': canEdit,
  'version': version,
  'ready': false,
  'sendingEnabled': false,
  'billingActivated': false,
  'configuration': config,
};
Future<void> enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.scrollUntilVisible(
    field,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 900.0]) {
    testWidgets(
      'owner saves only public preparation data without enabling LINE at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var saves = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: ShopLinePreparationPage(
              shopId: 's',
              api: (action, data) async {
                if (action == 'linePreparation') return status();
                expect(action, 'saveLinePreparation');
                expect(data['version'], 0);
                final config = data['configuration'] as Map<String, dynamic>;
                expect(config.keys.toSet(), {
                  'displayName',
                  'officialAccountId',
                  'channelId',
                  'requestedUses',
                });
                expect(config['officialAccountId'], '@shop');
                saves++;
                return status(version: 1, config: config);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('尚未連線'), findsOneWidget);
        await enter(tester, '官方帳號顯示名稱', '貓咪旅店');
        await enter(tester, 'LINE 官方帳號 ID', '@shop');
        await enter(tester, 'Messaging API Channel ID（選填）', '1234567890');
        await tester.tap(find.text('儲存準備資料'));
        await tester.pumpAndSettle();
        expect(saves, 1);
        expect(find.textContaining('尚未開通發送。'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'staff readonly and offline service do not expose activation controls',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShopLinePreparationPage(
            shopId: 's',
            api: (action, data) async => status(canEdit: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('檢視模式'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find
                  .ancestor(
                    of: find.text('儲存準備資料'),
                    matching: find.byWidgetPredicate(
                      (widget) => widget is FilledButton,
                    ),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: ShopLinePreparationPage(
            shopId: 's',
            api: (action, data) async => throw StateError('not deployed'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('尚未部署新版通知服務'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find
                  .ancestor(
                    of: find.text('儲存準備資料'),
                    matching: find.byWidgetPredicate(
                      (widget) => widget is FilledButton,
                    ),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('failed save keeps input and allows retry', (tester) async {
    var tries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ShopLinePreparationPage(
          shopId: 's',
          api: (action, data) async {
            if (action == 'linePreparation') return status();
            tries++;
            throw StateError('offline');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enter(tester, '官方帳號顯示名稱', '保留這份準備資料');
    await tester.tap(find.text('儲存準備資料'));
    await tester.pumpAndSettle();
    expect(tries, 1);
    expect(find.textContaining('儲存失敗'), findsWidgets);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, '官方帳號顯示名稱'))
          .controller!
          .text,
      '保留這份準備資料',
    );
    expect(
      tester
          .widget<FilledButton>(
            find
                .ancestor(
                  of: find.text('儲存準備資料'),
                  matching: find.byWidgetPredicate(
                    (widget) => widget is FilledButton,
                  ),
                )
                .first,
          )
          .onPressed,
      isNotNull,
    );
  });
}
