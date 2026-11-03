import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/platform_billing_service.dart';
import 'package:petnest_saas/core/services/inspection_owner_context.dart';
import 'package:petnest_saas/features/shop/pages/platform_billing_page.dart';

class BillingStore implements PlatformBillingStore {
  final requests = <Map<String, dynamic>>[];
  int refreshes = 0, cancels = 0;
  bool cancelFails = false;
  Map<String, dynamic> data = {
    'enabled': true,
    'environment': 'production',
    'canCheckout': true,
    'canCancel': true,
    'termsVersion': 'platform_subscription_v1',
    'priceVersion': 'version',
    'paidUntilDate': '',
    'quotes': [
      for (final plan in ['basic', 'pro'])
        for (final cycle in ['month', 'year'])
          {
            'plan': plan,
            'cycle': cycle,
            'amountMinor': plan == 'pro' ? 199900 : 99900,
            'recurringExecutionLimit': cycle == 'year' ? 2 : 12,
            'canStartRecurring': true,
            'serviceStart': '2026-11-02',
            'serviceEnd': '2026-12-01',
          },
    ],
    'subscription': null,
    'receipts': <dynamic>[],
  };
  @override
  Future<Map<String, dynamic>> load(String shopId) async => Map.from(data);
  @override
  Future<Map<String, dynamic>> refresh(String shopId) async {
    refreshes++;
    return Map.from(data);
  }

  @override
  Future<Map<String, dynamic>> checkout(Map<String, dynamic> request) async {
    requests.add(request);
    data['subscription'] = {
      'id': 'PB123456789012345678',
      'state': 'pending',
      'plan': request['plan'],
      'cycle': request['cycle'],
      'recurring': request['recurring'],
      'amountMinor': 99900,
      'executionLimit': 12,
      'priceVersion': 'version',
    };
    return {
      'order': data['subscription'],
      'checkoutUrl': 'https://example.invalid/checkout#token',
    };
  }

  @override
  Future<Map<String, dynamic>> cancel(String shopId) async {
    cancels++;
    data['subscription'] = {
      ...(data['subscription'] as Map),
      'state': cancelFails ? 'cancel_pending' : 'cancelled',
    };
    if (cancelFails) throw const PlatformBillingException('綠界尚未確認終止');
    return Map.from(data);
  }
}

Future<void> open(WidgetTester tester, BillingStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PlatformBillingPage(shopId: 's1', store: store),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(InspectionOwnerContext.clear);
  testWidgets(
    'default is one-off, no card fields, and payment requires explicit consent',
    (tester) async {
      final store = BillingStore();
      await open(tester, store);
      expect(find.byType(TextField), findsNothing);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('確認方案，準備付款'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is FilledButton,
                ),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('確認方案，準備付款'));
      await tester.tap(find.text('確認方案，準備付款'));
      await tester.pumpAndSettle();
      expect(store.requests, hasLength(1));
      expect(store.requests.single['recurring'], isFalse);
      expect(store.requests.single.keys, isNot(contains('amountMinor')));
      expect(find.text('前往綠界安全付款'), findsOneWidget);
    },
  );
  testWidgets('changing recurring choice clears prior consent', (tester) async {
    final store = BillingStore();
    await open(tester, store);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(find.textContaining('共12期'), findsWidgets);
  });
  testWidgets('unexpired trial does not permit early recurring payment', (
    tester,
  ) async {
    final store = BillingStore();
    for (final quote in store.data['quotes'] as List) {
      quote['canStartRecurring'] = false;
      quote['serviceStart'] = '2027-01-01';
    }
    await open(tester, store);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.textContaining('請於2027-01-01'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    expect(store.requests, isEmpty);
  });
  testWidgets(
    'disabled test environment clearly cannot charge or grant production entitlement',
    (tester) async {
      final store = BillingStore();
      store.data['enabled'] = false;
      store.data['environment'] = 'test';
      await open(tester, store);
      expect(find.textContaining('不收實款、不延長正式'), findsOneWidget);
      expect(find.textContaining('準備中'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('確認方案，準備付款'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is FilledButton,
                ),
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'inspection only reads, without checkout, cancel, or gateway refresh',
    (tester) async {
      InspectionOwnerContext.active = true;
      final store = BillingStore();
      await open(tester, store);
      await tester.tap(find.byTooltip('重新查詢付款狀態'));
      await tester.pumpAndSettle();
      expect(store.refreshes, 0);
      expect(store.requests, isEmpty);
      expect(find.textContaining('唯讀查核'), findsOneWidget);
    },
  );
  testWidgets(
    'cancel timeout stays pending instead of falsely showing stopped',
    (tester) async {
      final store = BillingStore();
      store.cancelFails = true;
      store.data['subscription'] = {
        'state': 'active',
        'plan': 'basic',
        'cycle': 'month',
        'recurring': true,
        'amountMinor': 99900,
        'executionLimit': 12,
        'settledCount': 1,
      };
      await open(tester, store);
      await tester.ensureVisible(find.text('停止自動續訂'));
      await tester.tap(find.text('停止自動續訂'));
      await tester.pumpAndSettle();
      expect(find.textContaining('不會自動退款'), findsOneWidget);
      await tester.tap(find.text('確認停止續訂'));
      await tester.pumpAndSettle();
      expect(store.cancels, 1);
      expect(find.textContaining('正在確認取消'), findsOneWidget);
      expect(find.text('已停止自動續訂'), findsNothing);
    },
  );
  testWidgets('320px phone with doubled text remains usable and scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = BillingStore();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: PlatformBillingPage(shopId: 's1', store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('最近平台收款紀錄'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
