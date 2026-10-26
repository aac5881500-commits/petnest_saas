import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_owner_policy_page.dart';

void main() {
  testWidgets('手機與全螢幕集中閱讀、真實捲到底並勾選後才繼續', (tester) async {
    for (final width in [320.0, 390.0, 1280.0, 1920.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      var agrees = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PlatformShopOwnerPolicyPage(
            key: ValueKey(width),
            onAgree: () => agrees++,
            loadPolicy: () async => {
              'title': '創店主條款',
              'version': 3,
              'content': [
                for (var i = 1; i <= 12; i++)
                  '# 第 $i 條\n\n請確認本條款的內容。\n\n* 第一個事項\n* 第二個事項\n\n---',
              ].join('\n\n'),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reader = find.byKey(const Key('owner-policy-reader'));
      expect(tester.getSize(reader).width, lessThanOrEqualTo(960));
      if (width >= 1280) expect(tester.getTopLeft(reader).dx, greaterThan(100));
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final scroll = tester.widget<SingleChildScrollView>(reader).controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNotNull,
      );
      expect(agrees, 0);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同意並繼續'));
      await tester.pumpAndSettle();
      expect(agrees, 1);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets('短內容可同意，載入失敗可重試且不先放行', (tester) async {
    var fails = true;
    Future<Map<String, dynamic>?> load() async {
      if (fails) throw StateError('offline');
      return {'content': '短條款', 'version': 3};
    }

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformShopOwnerPolicyPage(onAgree: () {}, loadPolicy: load),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    fails = false;
    await tester.tap(find.text('重新載入'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNotNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
