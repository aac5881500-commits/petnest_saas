import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/platform/widgets/platform_inspection_workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final records = <Map<String, dynamic>>[
    {
      'path': 'shops/s1/members/customer-001',
      'data': {
        'name': '陳小姐',
        'userId': 'customer-001',
        'phone': '0912-345-678',
        'email': 'customer@example.test',
        'createdAt': '2026-10-29T01:30:00Z',
        'status': 'active',
        'tags': ['住宿會員', '曾有退款紀錄'],
      },
    },
    {
      'path': 'shops/s1/members/customer-002',
      'data': {
        'name': '林先生',
        'userId': 'customer-002',
        'phone': '0922-000-000',
        'createdAt': '2026-10-28T06:20:00Z',
        'status': 'active',
      },
    },
  ];
  Future<void> pump(
    WidgetTester tester,
    Size size, {
    bool unlocked = true,
    bool busy = false,
    double scale = 1,
    List<Map<String, dynamic>>? data,
    String? error,
    String currentPath = 'shops/s1/members',
    bool shopSelector = false,
    ValueChanged<String>? onOpenPath,
    ValueChanged<Map<String, dynamic>>? onCustomer,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final customer = TextEditingController();
    final search = TextEditingController();
    addTearDown(customer.dispose);
    addTearDown(search.dispose);
    await tester.runAsync(() async {
      await (FontLoader(
        'jfOpenHuninn',
      )..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'jfOpenHuninn',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315DC4)),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('capture'),
          child: Scaffold(
            appBar: AppBar(title: const Text('店家唯讀查核')),
            body: StatefulBuilder(
              builder: (context, update) => PlatformInspectionWorkspace(
                unlocked: unlocked,
                busy: busy,
                shopId: shopSelector ? null : 's1',
                shopName: 'PetNest 測試旅店',
                path: currentPath,
                error: error,
                records: data ?? records,
                collections: const [],
                customerController: customer,
                searchController: search,
                onSearch: (_) => update(() {}),
                onUnlock: () {},
                onAllShops: () {},
                onRefresh: () {},
                onOpenPath: onOpenPath ?? (_) {},
                onRecord: (_) {},
                onCustomer: onCustomer ?? (_) {},
                onExport: () {},
                onNext: () {},
                onBack: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    if (!busy) await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 768.0, 1080.0, 1440.0]) {
    testWidgets('read-only workspace fits width $width', (tester) async {
      await pump(tester, Size(width, 1100));
      expect(tester.takeException(), isNull);
      expect(find.text('查核分類'), findsOneWidget);
      for (final label in ['退款', '儲存', '刪除', '傳送']) {
        expect(find.text(label), findsNothing);
      }
      final output = const String.fromEnvironment('INSPECTION_PREVIEW_DIR');
      if (output.isNotEmpty && (width == 390 || width == 1440)) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File(
            '$output/inspection_${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets('large text on narrow phone remains scrollable', (tester) async {
    await pump(tester, const Size(320, 800), scale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'search filters current page and customer selection only invokes selection',
    (tester) async {
      Map<String, dynamic>? selected;
      await pump(
        tester,
        const Size(1440, 1400),
        onCustomer: (record) => selected = record,
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText?.startsWith('搜尋本頁') == true,
        ),
        '陳小姐',
      );
      await tester.pumpAndSettle();
      expect(find.text('林先生'), findsNothing);
      await tester.ensureVisible(find.text('選為彙整客戶').first);
      await tester.tap(find.text('選為彙整客戶').first);
      expect(selected?['path'], 'shops/s1/members/customer-001');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('locked workspace hides records', (tester) async {
    await pump(tester, const Size(390, 844), unlocked: false);
    expect(find.text('陳小姐'), findsNothing);
    expect(find.text('寄送驗證碼'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('loading and errors fit mobile', (tester) async {
    await pump(
      tester,
      const Size(320, 800),
      busy: true,
      data: [],
      error: '測試連線失敗，請稍後重試。',
    );
    expect(find.text('資料暫時無法讀取'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mobile customer summary reflects the selected identifier', (
    tester,
  ) async {
    await pump(tester, const Size(390, 1100));
    await tester.tap(find.text('客戶紀錄彙整'));
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == '客戶 UID／店內會員 ID',
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, 'customer-001');
    await tester.pumpAndSettle();
    expect(find.text('已選取：customer-001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shop selector is compact and keeps export workspace entry', (
    tester,
  ) async {
    await pump(
      tester,
      const Size(390, 1000),
      shopSelector: true,
      currentPath: '',
      data: [
        {
          'path': 'shops/s1',
          'data': {
            'name': '測試店家',
            'shopCode': 'SHOP0009',
            'city': '新竹縣',
            'district': '新埔鎮',
            'isPublic': true,
            'isOpen': true,
            'address': '測試完整地址',
            'phone': '0912345678',
            'activationCode': 'test-code',
            'paidUntil': '2027-01-23',
          },
        },
      ],
    );
    await tester.ensureVisible(find.text('資料查核與下載'));
    await tester.pumpAndSettle();
    expect(find.text('測試完整地址'), findsNothing);
    expect(find.text('0912345678'), findsNothing);
    expect(find.text('方案有效期限'), findsNothing);
    expect(find.text('資料查核與下載'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('timestamps display Taiwan time', () {
    expect(inspectionValue('2026-10-29T01:30:00Z'), '2026/10/29 09:30（台灣）');
    expect(inspectionValue(false), '否');
  });
}
