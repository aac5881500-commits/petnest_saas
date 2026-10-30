import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_owner_report_page.dart';

class EmptyLedger implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'denied private ledger keeps system revenue and hides unknown totals',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ledger = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      addTearDown(ledger.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ShopOwnerReportPage(
            shopId: 'test-shop',
            reportLoader: (range) async => ShopReportService.instance
                .buildSelectedData(range: range, sources: {}),
            ledgerLoader: (_) => ledger.stream,
          ),
        ),
      );
      ledger.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(find.text('系統訂單金額'), findsOneWidget);
      expect(find.textContaining('私人收支存取遭拒'), findsOneWidget);
      expect(find.text('員工薪資合計'), findsNothing);
      expect(find.text('收支結餘'), findsNothing);
      expect(find.textContaining('尚無手動紀錄'), findsNothing);
      await tester.tap(find.text('薪資管理'));
      await tester.pumpAndSettle();
      expect(find.text('新增員工薪資'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find
            .ancestor(
              of: find.text('新增員工薪資'),
              matching: find.byWidgetPredicate(
                (widget) => widget is FilledButton,
              ),
            )
            .first,
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'retry reconnects ledger and restores private accounting after success',
    (tester) async {
      var attempts = 0;
      final denied = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      final allowed = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      addTearDown(denied.close);
      addTearDown(allowed.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ShopOwnerReportPage(
            shopId: 'test-shop',
            reportLoader: (range) async => ShopReportService.instance
                .buildSelectedData(range: range, sources: {}),
            ledgerLoader: (_) =>
                ++attempts == 1 ? denied.stream : allowed.stream,
          ),
        ),
      );
      denied.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新讀取收支'));
      await tester.pump();
      expect(attempts, 2);
      allowed.add(EmptyLedger());
      await tester.pumpAndSettle();
      expect(find.textContaining('私人收支存取遭拒'), findsNothing);
      expect(find.text('員工薪資合計'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('收支結餘'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('收支結餘'), findsOneWidget);
      await tester.tap(find.text('薪資管理'));
      await tester.pumpAndSettle();
      expect(find.text('新增員工薪資'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find
            .ancestor(
              of: find.text('新增員工薪資'),
              matching: find.byWidgetPredicate(
                (widget) => widget is FilledButton,
              ),
            )
            .first,
      );
      expect(button.onPressed, isNotNull);
    },
  );
}
