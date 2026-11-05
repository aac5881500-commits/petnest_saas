import 'dart:io';
import 'dart:ui' as ui;
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/models/owner_cashflow_totals.dart';
import 'package:petnest_saas/core/services/owner_finance_export.dart';
import 'package:petnest_saas/core/services/owner_report_workspace.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/features/shop/pages/shop_owner_report_page.dart';
import 'package:petnest_saas/features/shop/widgets/owner_cashflow_card.dart';
import 'package:petnest_saas/features/shop/widgets/owner_finance_widgets.dart';

const entries = <Map<String, dynamic>>[
  {'kind': 'salary', 'name': '小林', 'amount': 60000, 'note': ''},
  {'kind': 'expense', 'name': '房租水電', 'amount': 20000, 'note': ''},
  {'kind': 'income', 'name': '其他收入', 'amount': 5000, 'note': ''},
];
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    const path = String.fromEnvironment('OWNER_CAPTURE_FONT');
    if (path.isNotEmpty) {
      final font = FontLoader('OwnerReview');
      font.addFont(
        Future.value(ByteData.sublistView(await File(path).readAsBytes())),
      );
      await font.load();
    }
  });
  test(
    'other income adds and salary plus operating cost are deducted exactly once, including a loss',
    () {
      final totals = OwnerCashflowTotals.fromEntries(100000, entries);
      expect(totals.totalIncome, 105000);
      expect(totals.totalExpense, 80000);
      expect(totals.balance, 25000);
      expect(OwnerCashflowTotals.fromEntries(10000, entries).balance, -65000);
      expect(OwnerCashflowTotals.fromEntries(0, []).balance, 0);
    },
  );
  test(
    'cashflow signs distinguish incoming and outgoing amounts without changing stored magnitudes',
    () {
      expect(ownerSignedMoney(5000, direction: 1), '+NT\$ 5,000');
      expect(ownerSignedMoney(20000, direction: -1), '-NT\$ 20,000');
      expect(ownerSignedMoney(-65000, forceSign: true), '-NT\$ 65,000');
      expect(entries[0]['amount'], 60000);
    },
  );
  test(
    'Excel uses signed numeric entries and its four-term calculation matches screen totals',
    () {
      final range = ReportRange(
        type: ReportRangeType.custom,
        startDate: DateTime(2026, 11),
        endDate: DateTime(2026, 12).subtract(const Duration(milliseconds: 1)),
      );
      final report = OwnerReportDemo.reports(range, {
        'stay',
        'daycare',
        'store',
      })['all']!;
      final totals = OwnerCashflowTotals.fromEntries(
        report.revenueKpi.paidAmount,
        entries,
      );
      final workbook = Excel.decodeBytes(
        OwnerFinanceExport.build(
          month: '2026-11',
          entries: entries,
          report: report,
          isDemo: true,
        ),
      );
      final rows = workbook.tables['收支計算']!.rows;
      final sum = rows
          .skip(1)
          .take(4)
          .fold<int>(0, (v, row) => v + (row[1]!.value as IntCellValue).value);
      expect(sum, totals.balance);
      expect(rows.last[1]!.value, IntCellValue(totals.balance));
      expect(
        workbook.tables['私人收支明細']!.rows[1][3]!.value,
        const IntCellValue(-60000),
      );
      expect(
        workbook.tables['私人收支明細']!.rows[3][3]!.value,
        const IntCellValue(5000),
      );
    },
  );
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'income page shows complete demo balance, signed costs, and easy presets at $width',
      (tester) async {
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
                cardTheme: const CardThemeData(
                  color: Colors.white,
                  elevation: 0,
                ),
              ),
              home: const ShopOwnerReportPage(
                shopId: 'cashflow-demo',
                initialDemo: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('收入支出'));
        await tester.pumpAndSettle();
        expect(find.byType(OwnerCashflowCard), findsOneWidget);
        expect(find.text('整店總收入'), findsOneWidget);
        expect(find.text('本月結餘'), findsOneWidget);
        final now = DateTime.now();
        final range = ReportRange(
          type: ReportRangeType.custom,
          startDate: DateTime(now.year, now.month),
          endDate: DateTime(
            now.year,
            now.month + 1,
          ).subtract(const Duration(milliseconds: 1)),
        );
        final report = OwnerReportDemo.reports(range, {
          'stay',
          'daycare',
          'store',
        })['all']!;
        final totals = OwnerCashflowTotals.fromEntries(
          report.revenueKpi.paidAmount,
          OwnerReportDemo.ledger(range.startDate).map((e) => e.data()).toList(),
        );
        expect(
          find.text(ownerSignedMoney(totals.totalIncome, direction: 1)),
          findsOneWidget,
        );
        expect(
          find.text(ownerSignedMoney(totals.totalExpense, direction: -1)),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
        const dir = String.fromEnvironment('OWNER_CAPTURE_DIR');
        if (dir.isNotEmpty) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$dir/owner-cashflow-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        await tester.tap(find.byTooltip('自訂顯示區塊'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('只看收支'));
        await tester.pumpAndSettle();
        expect(
          (await SharedPreferences.getInstance()).getStringList(
            'owner_report_panels_v1_cashflow-demo',
          ),
          containsAll(['summary', 'ledger']),
        );
        await tester.tap(find.text('含統計準備中項目'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('完成'));
        await tester.pumpAndSettle();
        expect(find.text('整店總收入'), findsNothing);
        expect(find.text('已知資料結餘（非完整）'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
