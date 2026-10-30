import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/pages/campaigns/shop_campaign_center_page.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    CampaignApi api, {
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ShopCampaignCenterPage(shopId: 's', api: api),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> bootstrap({
    bool canSend = true,
    bool draft = true,
    List<Map<String, dynamic>> jobs = const [],
  }) => {
    'permissions': {'draft': draft, 'send': canSend, 'view': true},
    'campaigns': jobs,
  };
  for (final width in [320.0, 1100.0]) {
    testWidgets('center loads and fits at $width', (tester) async {
      await show(tester, (action, data) async => bootstrap(), width: width);
      expect(find.text('目前沒有推廣或通知'), findsOneWidget);
      await tester.tap(find.text('新增會員消息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('分眾推廣'));
      await tester.pumpAndSettle();
      expect(find.text('新增分眾推廣'), findsOneWidget);
      expect(find.text('預覽並發送'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('viewer has no create control and draft-only staff cannot send', (
    tester,
  ) async {
    await show(
      tester,
      (action, data) async => bootstrap(draft: false, canSend: false),
    );
    expect(find.text('新增會員消息'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await show(
      tester,
      (action, data) async =>
          action == 'members' ? {'members': []} : bootstrap(canSend: false),
    );
    await tester.tap(find.text('新增會員消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分眾推廣'));
    await tester.pumpAndSettle();
    expect(find.text('預覽並發送'), findsNothing);
    expect(find.text('儲存草稿'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancel preview never sends; confirm submits exactly once', (
    tester,
  ) async {
    var sends = 0;
    var version = 0;
    final actions = <String>[];
    await show(tester, (action, data) async {
      actions.add(action);
      if (action == 'bootstrap') return bootstrap();
      if (action == 'members') return {'members': []};
      if (action == 'preview') {
        return {
          'campaign': {'version': ++version},
          'preview': {'count': 2, 'excluded': 1, 'revision': 'rev'},
        };
      }
      if (action == 'send') {
        sends++;
        expect(data['revision'], 'rev');
        return {
          'campaign': {'status': 'queued'},
        };
      }
      throw StateError(action);
    }, width: 1100);
    await tester.tap(find.text('新增會員消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分眾推廣'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '會員活動');
    await tester.enterText(find.byType(TextFormField).at(1), '實際活動內容');
    await tester.tap(find.text('預覽並發送'));
    await tester.pumpAndSettle();
    expect(find.text('可通知 2 位會員'), findsOneWidget);
    expect(sends, 0);
    await tester.tap(find.text('返回調整'));
    await tester.pumpAndSettle();
    expect(sends, 0);
    await tester.tap(find.text('預覽並發送'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認發送給 2 位'));
    await tester.pumpAndSettle();
    expect(sends, 1);
    expect(actions.where((a) => a == 'preview').length, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('zero recipients disables confirmation', (tester) async {
    var sends = 0;
    await show(tester, (action, data) async {
      if (action == 'bootstrap') return bootstrap();
      if (action == 'members') return {'members': []};
      if (action == 'preview') {
        return {
          'campaign': {'version': 1},
          'preview': {'count': 0, 'excluded': 3, 'revision': 'x'},
        };
      }
      if (action == 'send') {
        sends++;
        return {};
      }
      return {};
    }, width: 1100);
    await tester.tap(find.text('新增會員消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分眾推廣'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '活動');
    await tester.enterText(find.byType(TextFormField).at(1), '說明');
    await tester.tap(find.text('預覽並發送'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '確認發送給 0 位'))
          .onPressed,
      isNull,
    );
    expect(sends, 0);
  });
  testWidgets('required fields prevent any save or preview request', (
    tester,
  ) async {
    var requests = 0;
    await show(tester, (action, data) async {
      if (action == 'bootstrap') return bootstrap();
      if (action == 'members') return {'members': []};
      requests++;
      return {};
    });
    await tester.tap(find.text('新增會員消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分眾推廣'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存草稿'));
    await tester.pumpAndSettle();
    expect(find.text('請輸入標題'), findsOneWidget);
    expect(requests, 0);
  });
  testWidgets('load failure provides retry instead of an empty history', (
    tester,
  ) async {
    await show(tester, (action, data) async => throw StateError('offline'));
    expect(find.text('重新載入'), findsOneWidget);
    expect(find.text('目前沒有推廣或通知'), findsNothing);
  });
}
