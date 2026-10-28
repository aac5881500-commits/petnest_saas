import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:petnest_saas/features/shop/pages/shop_report_page.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(
        rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
      );
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  ShopReportBundle fixture(ReportRange range, Set<String> sources) =>
      ShopReportService.instance.buildSelectedData(
        range: range,
        sources: sources,
        bookings: [
          {
            'id': 'b',
            'userId': 'u',
            'status': 'confirmed',
            'bookingKind': 'stay',
            'nights': 2,
            'totalPrice': 1200,
            'roomTypeName': '日式房',
            'createdAt': range.startDate.add(const Duration(hours: 10)),
            'startDate': range.startDate.add(const Duration(days: 1)),
            'endDate': range.startDate.add(const Duration(days: 3)),
          },
        ],
        members: [
          {
            'id': 'u',
            'name': 'Ada',
            'phone': '00123',
            'tags': ['vip'],
          },
        ],
      );
  Future<void> show(
    WidgetTester tester, {
    double width = 1280,
    bool members = true,
    bool canView = true,
    ReportLoader? loader,
    Future<void> Function(Uint8List, String)? save,
  }) async {
    tester.view.physicalSize = Size(width, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansTC'),
        home: RepaintBoundary(
          child: ShopReportPage(
            shopId: 'shop',
            showTaskCenter: false,
            loadAccess: () async => {
              'uid': 'tester',
              'shopName': '測試旅店',
              'canView': canView,
              'canMembers': members,
              'canStore': true,
            },
            loadReport: loader ?? (r, s) async => fixture(r, s),
            saveFile: save ?? (_, __) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('shared workbench fits $width', (tester) async {
      await show(tester, width: width);
      expect(find.text('營運報表工作台'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(tester.takeException(), isNull);
      const capture = String.fromEnvironment('REPORT_CAPTURE_DIR');
      if (capture.isNotEmpty && width != 320) {
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile(Uri.file('$capture/report-${width.toInt()}.png')),
        );
      }
    });
  }
  testWidgets(
    'source changes wait for Apply and invalidate export until loaded',
    (tester) async {
      final requests = <Set<String>>[];
      await show(
        tester,
        loader: (r, s) async {
          requests.add(s);
          return fixture(r, s);
        },
      );
      expect(requests.length, 1);
      final chip = find.widgetWithText(FilterChip, '安親訂單');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(requests.length, 1);
      expect(find.byType(DataTable), findsNothing);
      await tester.tap(find.text('套用查詢'));
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests.last.contains('daycare'), isFalse);
      expect(find.byType(DataTable), findsOneWidget);
    },
  );
  testWidgets('column checkbox removes actual table and export column', (
    tester,
  ) async {
    Uint8List? bytes;
    await show(tester, save: (b, _) async => bytes = b);
    await tester.tap(find.text('欄位 8'));
    await tester.pumpAndSettle();
    final paid = find.widgetWithText(CheckboxListTile, '期間實收');
    await tester.ensureVisible(paid);
    await tester.tap(paid);
    await tester.pumpAndSettle();
    await tester.tap(find.text('套用欄位設定'));
    await tester.pumpAndSettle();
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.columns.length, 7);
    final export = find.text('匯出 Excel');
    await tester.ensureVisible(export);
    await tester.tap(export);
    await tester.pumpAndSettle();
    await tester.tap(find.text('下載 Excel'));
    await tester.pumpAndSettle();
    expect(bytes, isNotNull);
    final book = xlsx.Excel.decodeBytes(bytes!);
    expect(book['目前表格'].maxColumns, 7);
    expect(
      book['目前表格'].rows.first.map((c) => c?.value.toString()),
      isNot(contains('期間實收')),
    );
  });
  testWidgets('member templates cannot be selected without member permission', (
    tester,
  ) async {
    await show(tester, members: false);
    final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, '會員消費'));
    expect(tile.enabled, isFalse);
    expect(find.text('需要會員管理權限'), findsNWidgets(2));
  });
  testWidgets('permission denial never starts a query', (tester) async {
    var calls = 0;
    await show(
      tester,
      canView: false,
      loader: (r, s) async {
        calls++;
        return fixture(r, s);
      },
    );
    expect(calls, 0);
    expect(find.text('需要查看報表權限。'), findsOneWidget);
  });
  testWidgets('local template stores settings only and can be deleted', (
    tester,
  ) async {
    await show(tester, width: 390);
    await tester.tap(find.text('儲存個人模板'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '每日營運自訂',
    );
    await tester.tap(find.text('儲存模板'));
    await tester.pumpAndSettle();
    expect(find.text('每日營運自訂'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('report_views_v1_tester_shop')!;
    expect(raw, contains('每日營運自訂'));
    expect(raw, contains('columns'));
    expect(raw, isNot(contains('00123')));
    await tester.tap(find.byTooltip('刪除個人模板'));
    await tester.pumpAndSettle();
    expect(find.text('每日營運自訂'), findsNothing);
  });
  testWidgets('load error is not rendered as empty or zero data', (
    tester,
  ) async {
    await show(tester, loader: (r, s) async => throw StateError('offline'));
    expect(find.text('重新查詢'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });
}
