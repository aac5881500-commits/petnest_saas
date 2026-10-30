import 'dart:ui' as ui;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/owner_finance_export.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_owner_report_page.dart';
import 'package:petnest_saas/features/shop/widgets/owner_finance_widgets.dart';

// A narrow Firestore document test double; no production subtype is introduced.
// ignore: subtype_of_sealed_class
class _Entry implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Entry(this.value);
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
  @override
  String get id => value['name'] as String;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ledger implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs =>
      _rows.map((e) => _Entry(e)).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _rows = <Map<String, dynamic>>[
  {'kind': 'salary', 'name': '小林', 'amount': 32000, 'note': '本薪 30000／獎金 2000'},
  {'kind': 'salary', 'name': '小陳', 'amount': 35000, 'note': '本月薪資'},
  {'kind': 'expense', 'name': '房租', 'amount': 18000, 'note': '十月份租金'},
  {'kind': 'expense', 'name': '水電', 'amount': 4200, 'note': ''},
  {'kind': 'income', 'name': '其他服務', 'amount': 6000, 'note': ''},
];
void main() {
  setUpAll(() async {
    const fontPath = String.fromEnvironment('OWNER_CAPTURE_FONT');
    if (fontPath.isNotEmpty) {
      final loader = FontLoader('OwnerReview');
      loader.addFont(
        Future.value(ByteData.sublistView(await File(fontPath).readAsBytes())),
      );
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('employee grouping merges same employee and keeps expense separate', () {
    final grouped = ownerGroupAmounts([
      ..._rows,
      {'kind': 'salary', 'name': '小林', 'amount': 2000},
    ], 'salary');
    expect(grouped, {'小陳': 35000, '小林': 34000});
    final bytes = OwnerFinanceExport.build(month: '2026-10', entries: _rows);
    final workbook = Excel.decodeBytes(bytes);
    expect(workbook.tables.keys, containsAll(['月報說明', '月報摘要', '私人收支明細']));
    expect(workbook.tables['私人收支明細']!.rows.length, 6);
    final summary = workbook.tables['月報摘要']!.rows;
    expect(summary[1][1]!.value, const IntCellValue(67000));
    expect(summary.any((r) => r.first?.value.toString() == '收支結餘'), isFalse);
  });
  testWidgets(
    'donut legend reveals selected segment without changing denominator',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OwnerDonut(
              title: '測試占比',
              caption: '點圖例',
              values: {'薪資': 750, '房租': 250},
            ),
          ),
        ),
      );
      expect(find.textContaining('75.0%'), findsOneWidget);
      await tester.tap(find.text('房租'));
      await tester.pump();
      expect(find.text('25.0%'), findsOneWidget);
      expect(find.text('NT\$ 250'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'comparison loads only selected previous month and follows month navigation',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'owner_report_panels_v1_test-shop': ['summary', 'comparison'],
      });
      final starts = <DateTime>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ShopOwnerReportPage(
            shopId: 'test-shop',
            ledgerLoader: (_) => Stream.value(_Ledger()),
            reportLoader: (range) async {
              starts.add(range.startDate);
              return ShopReportService.instance.buildSelectedData(
                range: range,
                sources: {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(starts.length, 1);
      await tester.tap(find.text('營運分析'));
      await tester.pumpAndSettle();
      expect(starts.length, 2);
      expect(starts[1], DateTime(starts[0].year, starts[0].month - 1));
      await tester.tap(find.byTooltip('下個月'));
      await tester.pumpAndSettle();
      expect(starts.length, 4);
      expect(starts.skip(2).toSet(), {
        starts[0],
        DateTime(starts[0].year, starts[0].month + 1),
      });
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'dashboard fits $width and panel switch preserves data subscription',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var ledgerLoads = 0;
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
              home: ShopOwnerReportPage(
                shopId: 'test-shop',
                ledgerLoader: (_) {
                  ledgerLoads++;
                  return Stream.value(_Ledger());
                },
                reportLoader: (range) async =>
                    ShopReportService.instance.buildSelectedData(
                      range: range,
                      sources: {'stay', 'store'},
                      bookings: [
                        {
                          'id': 'b1',
                          'createdAt': range.startDate,
                          'status': 'confirmed',
                          'roomAmount': 98000,
                          'totalAmount': 98000,
                          'paidAmount': 98000,
                          'nights': 24,
                          'petCount': 4,
                        },
                      ],
                      payments: [
                        {
                          'status': 'paid',
                          'amount': 98000,
                          'bookingId': 'b1',
                          'paidAt': range.startDate,
                        },
                      ],
                    ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('老闆經營儀表板'), findsOneWidget);
        expect(tester.takeException(), isNull);
        const dir = String.fromEnvironment('OWNER_CAPTURE_DIR');
        if (dir.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final ByteData? bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$dir/owner-tabs-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        if (dir.isNotEmpty && width < 600) {
          await tester.scrollUntilVisible(
            find.text('營收來源占比'),
            200,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$dir/owner-tabs-mobile-charts.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        await tester.tap(find.byTooltip('自訂顯示區塊'));
        await tester.pumpAndSettle();
        final toggle = find.widgetWithText(SwitchListTile, '收入／成本圓環圖');
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('完成'));
        await tester.pumpAndSettle();
        expect(ledgerLoads, 1);
        await tester.ensureVisible(find.text('完整月報'));
        await tester.tap(find.text('完整月報'));
        await tester.pumpAndSettle();
        expect(find.byType(OwnerDonut), findsNothing);
        await tester.ensureVisible(find.text('薪資管理'));
        await tester.tap(find.text('薪資管理'));
        await tester.pumpAndSettle();
        expect(find.text('新增員工薪資'), findsOneWidget);
        expect(find.textContaining('房租'), findsNothing);
        if (dir.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$dir/owner-tabs-salary-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }

        expect(ledgerLoads, 1);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('owner_report_panels_v1_test-shop'),
          isNot(contains('charts')),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
