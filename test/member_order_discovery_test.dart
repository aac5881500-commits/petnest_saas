import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/member/widgets/member_order_overview.dart';

MemberOrderPreview order(String id, String code, {String status = 'pending'}) =>
    MemberOrderPreview(
      id: id,
      data: {
        'bookingCode': code,
        'shopId': 'shop-a',
        'shopName': '範例貓咪旅店',
        'userId': 'customer',
        'status': status,
        'bookingKind': 'accommodation',
        'startDate': '2026-11-12T00:00:00',
        'endDate': '2026-11-14T00:00:00',
        'pets': [
          {'name': '麻糬'},
        ],
        'totalPrice': 1600,
      },
    );
const theme = HomeThemeModel.modernDefault;
Widget app(Widget child) => MaterialApp(
  theme: ThemeData(fontFamily: 'OrderPreview'),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'OrderPreview',
    )..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('recent order and all-orders actions remain distinct', (t) async {
    var all = 0, recent = 0;
    await t.pumpWidget(
      app(
        MemberOrderOverview(
          theme: theme,
          view: order('doc-new', 'PN-NEW').view,
          onOpenOrders: () => all++,
          onOpenLatest: () => recent++,
        ),
      ),
    );
    expect(find.textContaining('PN-NEW'), findsOneWidget);
    expect(find.text('最近成立'), findsOneWidget);
    await t.tap(find.text('查看這筆訂單'));
    await t.pump();
    expect(recent, 1);
    expect(all, 0);
    await t.tap(find.text('全部訂單'));
    await t.pump();
    expect(all, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('empty, loading and failed reads keep order entry available', (
    t,
  ) async {
    var opened = 0;
    for (final state in ['empty', 'loading', 'failed']) {
      await t.pumpWidget(
        app(
          MemberOrderOverview(
            theme: theme,
            loading: state == 'loading',
            failed: state == 'failed',
            onOpenOrders: () => opened++,
          ),
        ),
      );
      expect(find.text('我的訂單'), findsOneWidget);
      await t.tap(find.text('查看我的訂單'));
      await t.pump();
      expect(find.text('查看這筆訂單'), findsNothing);
      expect(t.takeException(), isNull);
    }
    expect(opened, 3);
  });
  testWidgets('new snapshots replace the latest-order action target', (
    t,
  ) async {
    final stream = StreamController<MemberOrderPreview?>();
    addTearDown(stream.close);
    String? opened;
    await t.pumpWidget(
      app(
        MemberOrderOverviewHost(
          shopId: 'shop-a',
          userId: 'customer',
          theme: theme,
          ordersStream: stream.stream,
          onOpenOrders: () {},
          onOpenLatest: (p) => opened = p.id,
        ),
      ),
    );
    stream.add(order('doc-old', 'PN-OLD'));
    await t.pumpAndSettle();
    stream.add(order('doc-new', 'PN-NEW'));
    await t.pumpAndSettle();
    expect(find.textContaining('PN-OLD'), findsNothing);
    expect(find.textContaining('PN-NEW'), findsOneWidget);
    await t.tap(find.text('查看這筆訂單'));
    expect(opened, 'doc-new');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'switching shop or customer removes the previous preview while loading',
    (t) async {
      final a = StreamController<MemberOrderPreview?>(),
          b = StreamController<MemberOrderPreview?>();
      addTearDown(a.close);
      addTearDown(b.close);
      await t.pumpWidget(
        app(
          MemberOrderOverviewHost(
            shopId: 'shop-a',
            userId: 'customer-a',
            theme: theme,
            ordersStream: a.stream,
            onOpenOrders: () {},
          ),
        ),
      );
      a.add(order('a', 'PRIVATE-A'));
      await t.pumpAndSettle();
      expect(find.textContaining('PRIVATE-A'), findsOneWidget);
      await t.pumpWidget(
        app(
          MemberOrderOverviewHost(
            shopId: 'shop-b',
            userId: 'customer-b',
            theme: theme,
            ordersStream: b.stream,
            onOpenOrders: () {},
          ),
        ),
      );
      await t.pump();
      expect(find.textContaining('PRIVATE-A'), findsNothing);
      b.add(order('b', 'NEW-B'));
      await t.pumpAndSettle();
      expect(find.textContaining('NEW-B'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('home shortcut only occupies space when a recent order exists', (
    t,
  ) async {
    final stream = StreamController<MemberOrderPreview?>();
    addTearDown(stream.close);
    await t.pumpWidget(
      app(
        MemberOrderOverviewHost(
          shopId: 'shop-a',
          userId: 'customer',
          theme: theme,
          compact: true,
          hideWhenEmpty: true,
          ordersStream: stream.stream,
          onOpenOrders: () {},
        ),
      ),
    );
    stream.add(null);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-order-shortcut')), findsNothing);
    stream.add(order('recent', 'PN-RECENT'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-order-shortcut')), findsOneWidget);
    stream.addError(StateError('unavailable'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-order-shortcut')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('mobile order entry remains visible before a long pet list', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final capture = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'OrderPreview'),
          home: Scaffold(
            backgroundColor: theme.backgroundColor,
            appBar: AppBar(
              backgroundColor: theme.backgroundColor,
              title: const Text('會員中心'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(child: Icon(Icons.person_outline)),
                        SizedBox(width: 12),
                        Text(
                          '會員資料',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  MemberOrderOverview(
                    theme: theme,
                    view: order('new', 'PN-20261105').view,
                    onOpenOrders: () {},
                    onOpenLatest: () {},
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '我的資料',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('個人資料'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('常用地址'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('緊急聯絡人'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '我的寵物',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (var i = 0; i < 3; i++)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.pets),
                        title: Text('毛孩資料'),
                        subtitle: Text('點選管理寵物資料'),
                      ),
                    ),
                ],
              ),
            ),
            bottomNavigationBar: const SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('預約'),
                  Text('房型'),
                  Text('首頁'),
                  Text('我的訂單'),
                  Text('會員'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.getBottomRight(find.text('查看這筆訂單')).dy, lessThan(650));
    expect(t.takeException(), isNull);
    if (Platform.environment['ORDER_DISCOVERY_PREVIEW'] != null)
      await t.runAsync(() async {
        final img =
            await (capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${Platform.environment['ORDER_DISCOVERY_PREVIEW']}/member_orders_preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    await t.pumpWidget(const SizedBox());
  });
}
