import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/owner_report_workspace.dart';
import 'package:petnest_saas/core/services/owner_finance_export.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/features/shop/pages/shop_owner_report_page.dart';

class _Empty implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReportRange month(int m) => ReportRange(
  type: ReportRangeType.custom,
  startDate: DateTime(2026, m),
  endDate: DateTime(2026, m + 1).subtract(const Duration(milliseconds: 1)),
);
void main() {
  setUpAll(() async {
    const font = String.fromEnvironment('OWNER_CAPTURE_FONT');
    if (font.isNotEmpty) {
      final loader = FontLoader('OwnerReview');
      loader.addFont(
        Future.value(ByteData.sublistView(await File(font).readAsBytes())),
      );
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'enabled modules control source choices, reserved modules never query unrelated data',
    () {
      expect(OwnerReportWorkspace.sources({'cat_hotel', 'grooming'}, 'all'), {
        'stay',
        'daycare',
      });
      expect(OwnerReportWorkspace.sources({'store'}, 'all'), {'store'});
      expect(OwnerReportWorkspace.sources({'cat_hotel', 'store'}, 'store'), {
        'store',
      });
      expect(OwnerReportWorkspace.sources({'grooming'}, 'grooming'), isEmpty);
      expect(OwnerReportWorkspace.available({'cat_hotel'}).map((s) => s.id), [
        'stay',
        'daycare',
      ]);
    },
  );
  test(
    'multi-month example totals equal each business sum without duplicate receipts',
    () {
      for (final m in [9, 10, 11]) {
        final reports = OwnerReportDemo.reports(month(m), {
          'stay',
          'daycare',
          'store',
        });
        final total = reports['all']!.revenueKpi;
        for (final amount in [
          (
            total.orderAmount,
            reports.values
                .skip(1)
                .fold<int>(0, (v, r) => v + r.revenueKpi.orderAmount),
          ),
          (
            total.paidAmount,
            reports.values
                .skip(1)
                .fold<int>(0, (v, r) => v + r.revenueKpi.paidAmount),
          ),
          (
            total.refundAmount,
            reports.values
                .skip(1)
                .fold<int>(0, (v, r) => v + r.revenueKpi.refundAmount),
          ),
        ]) {
          expect(amount.$1, amount.$2);
        }
        expect(total.paidAmount, greaterThan(0));
        expect(reports['daycare']!.revenueKpi.storeRevenue, 0);
        expect(reports['store']!.revenueKpi.stayRevenue, 0);
        expect(
          OwnerReportDemo.ledger(
            DateTime(2026, m),
          ).every((e) => e.reference == null),
          isTrue,
        );
      }
      expect(
        OwnerReportDemo.reports(month(9), {
          'stay',
        })['all']!.revenueKpi.orderAmount,
        isNot(
          OwnerReportDemo.reports(month(10), {
            'stay',
          })['all']!.revenueKpi.orderAmount,
        ),
      );
    },
  );
  test(
    'demo and selected business exports are labeled and omit unallocated profit',
    () {
      final report = OwnerReportDemo.reports(month(10), {'store'})['all']!;
      final excel = Excel.decodeBytes(
        OwnerFinanceExport.build(
          month: '2026-10',
          entries: OwnerReportDemo.ledger(
            DateTime(2026, 10),
          ).map((e) => e.data()).toList(),
          report: report,
          isDemo: true,
          sourceLabel: '商城商品',
          includeBalance: false,
        ),
      );
      final info = excel.tables['月報說明']!.rows
          .map((r) => r.map((c) => c?.value.toString()).join(' '))
          .join('\n');
      expect(info, contains('示範虛構資料'));
      expect(info, contains('商城商品'));
      expect(
        excel.tables['月報摘要']!.rows.any(
          (r) => r.first?.value.toString() == '收支結餘',
        ),
        isFalse,
      );
    },
  );
  test(
    'current receipts for older bookings stay in the correct business without recounting old orders',
    () {
      final report = OwnerReportWorkspace.build(
        range: month(10),
        sources: {'stay', 'daycare'},
        bookings: [
          {
            'id': 'older',
            'bookingKind': 'daycare',
            'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
            'startDate': Timestamp.fromDate(DateTime(2025, 1, 1)),
            'status': 'completed',
            'totalPrice': 5000,
          },
        ],
        payments: [
          {
            'bookingId': 'older',
            'sourceType': 'booking',
            'status': 'paid',
            'amount': 5000,
            'createdAt': Timestamp.fromDate(DateTime(2026, 10, 5)),
            'paidAt': Timestamp.fromDate(DateTime(2026, 10, 5)),
          },
        ],
      );
      expect(report['all']!.revenueKpi.paidAmount, 5000);
      expect(report['daycare']!.revenueKpi.paidAmount, 5000);
      expect(report['stay']!.revenueKpi.paidAmount, 0);
      expect(report['all']!.revenueKpi.orderAmount, 0);
    },
  );
  testWidgets(
    'demo can save sample salary with zero production loaders and no Firebase initialization',
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ShopOwnerReportPage(
            shopId: 'isolated-demo',
            initialDemo: true,
            moduleLoader: () async {
              loads++;
              return {'cat_hotel'};
            },
            ledgerLoader: (_) {
              loads++;
              return Stream.value(_Empty());
            },
            workspaceLoader: (range, sources) async {
              loads++;
              return OwnerReportDemo.reports(range, sources);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 0);
      expect(find.textContaining('示範模式：全部為虛構資料'), findsOneWidget);
      await tester.tap(find.text('薪資管理'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增員工薪資'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '示範新增員工');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.scrollUntilVisible(
        find.text('示範新增員工'),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('示範新增員工'), findsOneWidget);
      expect(loads, 0);
      await tester.tap(find.text('正式資料'));
      await tester.pumpAndSettle();
      expect(loads, 3);
      expect(find.textContaining('示範新增員工'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'source selection isolates revenue, does not reconnect private ledger, and reserved source shows no zero metrics',
    (tester) async {
      final queries = <Set<String>>[];
      var ledgerLoads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ShopOwnerReportPage(
            shopId: 'scope-test',
            moduleLoader: () async => {'cat_hotel', 'store', 'grooming'},
            ledgerLoader: (_) {
              ledgerLoads++;
              return Stream.value(_Empty());
            },
            workspaceLoader: (range, sources) async {
              queries.add(sources);
              return OwnerReportDemo.reports(range, sources);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> select(String name) async {
        await tester.tap(
          find.byWidgetPredicate((w) => w is DropdownButtonFormField<String>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
      }

      await select('商城商品');
      expect(queries.last, {'store'});
      expect(ledgerLoads, 1);
      expect(find.text('收支結餘'), findsNothing);
      expect(find.text('總淨收入（淨實收＋其他收入）'), findsNothing);
      final count = queries.length;
      await select('寵物美容（統計準備中）');
      expect(queries.length, count);
      await tester.scrollUntilVisible(
        find.text('此服務項目尚無可用的統計來源'),
        160,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('此服務項目尚無可用的統計來源'), findsOneWidget);
      expect(find.text('系統訂單金額'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [390.0, 1440.0]) {
    testWidgets('demo source controls and grouped settings fit $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: ThemeData(
              fontFamily: 'OwnerReview',
              colorSchemeSeed: const Color(0xff5368bd),
              scaffoldBackgroundColor: const Color(0xfff5f6fb),
              cardTheme: const CardThemeData(color: Colors.white, elevation: 0),
            ),
            home: const ShopOwnerReportPage(
              shopId: 'demo-layout',
              initialDemo: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('示範資料'), findsOneWidget);
      expect(tester.takeException(), isNull);
      const dir = String.fromEnvironment('OWNER_CAPTURE_DIR');
      Future<void> capture(String suffix) async {
        if (dir.isEmpty) return;
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$dir/owner-module-demo-${width.toInt()}-$suffix.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }

      await capture('overview');
      await tester.tap(find.byTooltip('自訂顯示區塊'));
      await tester.pumpAndSettle();
      expect(find.text('資料來源・依已開啟模板'), findsOneWidget);
      await tester.tap(find.text('含統計準備中項目'));
      await tester.pumpAndSettle();
      expect(find.text('寵物美容・統計準備中'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('settings');
    });
  }
}
