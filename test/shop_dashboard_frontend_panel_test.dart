// 檔案名稱：test/shop_dashboard_frontend_panel_test.dart
// 功能說明：驗證後台內嵌前台依可用寬度並排，放不下時不內嵌，也不把 500px canvas 縮小。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_multi_dock_controller.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_embedded_scope.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_layout.dart';
import 'package:petnest_saas/features/shop/widgets/shop_frontend_phone_preview.dart';
import 'package:petnest_saas/features/shop/widgets/shop_frontend_test_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('左側以 500px canvas 等比例縮小，不依左欄重排', () {
    expect(ShopFrontendTestPanel.liveFrontendSize.width, 500);
    expect(ShopFrontendPreviewFrame.phoneLogicalSize.width, 500);
    expect(ShopFrontendPhoneFrame.liveLogicalWidth, 500);
    expect(
      ShopFrontendPhoneFrame.scaleFor(
        availableWidth: 500,
        availableHeight: 844,
      ),
      1,
    );
    expect(
      ShopFrontendPhoneFrame.scaleFor(
        availableWidth: 250,
        availableHeight: 844,
      ),
      0.5,
    );
    expect(ShopFrontendPreviewFrame.canvasWidth, 500);
    expect(ShopFrontendPreviewFrame.inlineMaxWidth, 540);
    expect(ShopFrontendPreviewFrame.inlineMinOperableWidth, 516);
    final double wideSlot = ShopFrontendPreviewFrame.inlineWidthFor(1600);
    expect(
      wideSlot,
      lessThanOrEqualTo(ShopFrontendPreviewFrame.inlineMaxWidth),
    );
    expect(
      wideSlot,
      greaterThanOrEqualTo(ShopFrontendPreviewFrame.inlineMinOperableWidth),
    );
    final double fittedWidth =
        wideSlot - ShopFrontendPreviewFrame.inlineCanvasInset;
    expect(fittedWidth, greaterThanOrEqualTo(500));
    expect(
      ShopFrontendPhoneFrame.scaleFor(
        availableWidth: fittedWidth,
        availableHeight: 844,
      ),
      1,
    );
    final double minAvailable =
        ShopFrontendPreviewFrame.inlineMinOperableWidth +
        ShopFrontendPreviewFrame.inlineColumnGap +
        ShopFrontendPreviewFrame.backendMinOperableWidth;
    final double exactSlot = ShopFrontendPreviewFrame.inlineWidthFor(
      minAvailable,
    );
    expect(exactSlot, ShopFrontendPreviewFrame.inlineMinOperableWidth);
    expect(
      ShopFrontendPhoneFrame.scaleFor(
        availableWidth: exactSlot - ShopFrontendPreviewFrame.inlineCanvasInset,
        availableHeight: 844,
      ),
      1,
    );
  });

  test('寬度不足時不內嵌左側預覽', () {
    final double minAvailable =
        ShopFrontendPreviewFrame.inlineMinOperableWidth +
        ShopFrontendPreviewFrame.inlineColumnGap +
        ShopFrontendPreviewFrame.backendMinOperableWidth;
    expect(
      ShopFrontendPreviewFrame.canShowInlinePreview(minAvailable - 1),
      isFalse,
    );
    expect(ShopFrontendPreviewFrame.inlineWidthFor(minAvailable - 1), 0);
    expect(ShopFrontendPreviewFrame.canShowInlinePreview(1100), isFalse);
    expect(ShopFrontendPreviewFrame.canShowInlinePreview(minAvailable), isTrue);
  });

  test('有聊天 dock 時，扣掉欄寬後不足就停止 inline', () {
    const double pageWidth = 1600;
    final double dock = ShopChatLayout.dockWidthFor(pageWidth);
    expect(dock, greaterThan(600));
    final double available = pageWidth - dock;
    expect(ShopFrontendPreviewFrame.canShowInlinePreview(pageWidth), isTrue);
    expect(ShopFrontendPreviewFrame.canShowInlinePreview(available), isFalse);
    expect(ShopFrontendPreviewFrame.inlineWidthFor(available), 0);

    const double widePage = 2200;
    final double wideDock = ShopChatLayout.dockWidthFor(widePage);
    final double wideAvailable = widePage - wideDock;
    expect(
      ShopFrontendPreviewFrame.canShowInlinePreview(wideAvailable),
      isTrue,
    );
    final double slot = ShopFrontendPreviewFrame.inlineWidthFor(wideAvailable);
    expect(
      wideAvailable - slot - ShopFrontendPreviewFrame.inlineColumnGap,
      greaterThanOrEqualTo(ShopFrontendPreviewFrame.backendMinOperableWidth),
    );
    expect(
      ShopFrontendPhoneFrame.scaleFor(
        availableWidth: slot - ShopFrontendPreviewFrame.inlineCanvasInset,
        availableHeight: 844,
      ),
      1,
    );
  });

  test('左側使用正式前台根頁 ShopPublicPage', () {
    final Widget root = ShopFrontendTestPanel.liveRoot(
      shopId: 'shop-1',
      onClose: () {},
    );
    expect(root, isA<ShopPublicPage>());
  });

  testWidgets('左側沒有假狀態列、尺寸切換與預覽模式文字', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 1000,
            child: ShopFrontendTestPanel(
              shopId: 'shop-test',
              shopCode: 'demo',
              onClose: () {},
              previewBodyOverride: const _LiveFrontendStub(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('前台預覽'), findsOneWidget);
    expect(find.text('9:41'), findsNothing);
    expect(find.byIcon(Icons.wifi), findsNothing);
    expect(find.byIcon(Icons.battery_full), findsNothing);
    expect(find.textContaining('小手機'), findsNothing);
    expect(find.textContaining('標準手機'), findsNothing);
    expect(find.textContaining('後台預覽模式'), findsNothing);
    expect(find.textContaining('內容已完整顯示'), findsNothing);
    expect(find.textContaining('viewport=500x'), findsOneWidget);
    expect(find.byTooltip('放大'), findsNothing);
  });

  testWidgets('左欄變窄時仍用 500px 寬度排版', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 250,
            height: 700,
            child: ShopFrontendPhoneFrame(child: _CanvasWidthProbe()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('canvas=500'), findsOneWidget);
  });

  testWidgets('顯示展開控制且點預約不離開預覽框', (WidgetTester tester) async {
    bool expanded = false;
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: 480,
                height: 1000,
                child: ShopFrontendPreviewFrame(
                  shopId: 'shop-test',
                  shopCode: 'demo',
                  showExpand: true,
                  expanded: expanded,
                  onToggleExpand: () {
                    setState(() {
                      expanded = !expanded;
                    });
                  },
                  onClose: () {},
                  previewBodyOverride: const _LiveFrontendStub(),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('放大'), findsOneWidget);
    await tester.tap(find.byTooltip('放大'));
    await tester.pump();
    expect(find.byTooltip('縮小'), findsOneWidget);
    await tester.tap(find.text('住宿預約'));
    await tester.pumpAndSettle();
    expect(find.text('住宿預約流程'), findsOneWidget);
    expect(find.text('dashboard-shell'), findsNothing);
  });

  testWidgets('embeddedInShopDashboard 隱藏後台入口且可完整到達送出', (
    WidgetTester tester,
  ) async {
    int submits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 1000,
            child: ShopFrontendTestPanel(
              shopId: 'shop-test',
              shopCode: 'demo',
              onClose: () {},
              previewBodyOverride: _LiveFrontendStub(onSubmit: () => submits++),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('進入管理後台'), findsNothing);
    expect(find.text('回後台'), findsNothing);
    expect(
      ShopDashboardEmbeddedScope.blockMutations(
        tester.element(find.text('正式前台根頁')),
      ),
      isFalse,
    );

    await tester.tap(find.text('住宿預約'));
    await tester.pumpAndSettle();
    expect(find.text('住宿預約流程'), findsOneWidget);
    await tester.tap(find.text('送出訂單'));
    await tester.pump();
    expect(submits, 1);

    await tester.tap(find.byTooltip('返回上一頁'));
    await tester.pumpAndSettle();
    expect(find.text('dashboard-shell'), findsNothing);
    expect(find.text('正式前台根頁'), findsOneWidget);

    await tester.tap(find.text('安親預約'));
    await tester.pumpAndSettle();
    expect(find.text('安親預約流程'), findsOneWidget);
    await tester.tap(find.text('送出訂單'));
    await tester.pump();
    expect(submits, 2);
  });

  testWidgets('inline 預覽與後台內容並排且不覆蓋', (WidgetTester tester) async {
    const double pageWidth = 1600;
    const double height = 900;
    final double previewWidth = ShopFrontendPreviewFrame.inlineWidthFor(
      pageWidth,
    );
    expect(ShopFrontendPreviewFrame.canShowInlinePreview(pageWidth), isTrue);
    await tester.binding.setSurfaceSize(const Size(pageWidth, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _InlineSplitHarness(
            pageWidth: pageWidth,
            height: height,
            chatDockWidth: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    final Rect preview = tester.getRect(
      find.byKey(_InlineSplitHarness.previewKey),
    );
    final Rect backend = tester.getRect(
      find.byKey(_InlineSplitHarness.backendKey),
    );
    expect(find.byType(Row), findsOneWidget);
    expect(preview.right, lessThanOrEqualTo(backend.left));
    expect(preview.overlaps(backend), isFalse);
    expect(preview.width, previewWidth);
    expect(
      backend.width,
      greaterThanOrEqualTo(ShopFrontendPreviewFrame.backendMinOperableWidth),
    );
    expect(
      ShopFrontendPhoneFrame.scaleFor(
        availableWidth:
            preview.width - ShopFrontendPreviewFrame.inlineCanvasInset,
        availableHeight: 844,
      ),
      1,
    );
    expect(find.text('chat-dock'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is ColoredBox && widget.color == const Color(0x33000000),
      ),
      findsNothing,
    );

    const double dock = 650;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _InlineSplitHarness(
            pageWidth: pageWidth,
            height: height,
            chatDockWidth: dock,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(_InlineSplitHarness.previewKey), findsNothing);
    expect(find.text('dashboard-main'), findsOneWidget);
    expect(find.text('chat-dock'), findsOneWidget);
    final Rect narrowed = tester.getRect(
      find.byKey(_InlineSplitHarness.backendKey),
    );
    final Rect chat = tester.getRect(find.byKey(_InlineSplitHarness.chatKey));
    expect(narrowed.overlaps(chat), isFalse);
  });

  test('左側開關不會遺失聊天草稿，新訊息也不會清掉視窗', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ShopChatMultiDockController chat = ShopChatMultiDockController();
    await chat.attach(shopId: 's', uid: 'u', listenInbox: false);
    chat.openFromInbox(
      const ShopChatThreadModel(
        id: 'a',
        shopId: 's',
        customerUid: 'a',
        customerName: '會員A',
      ),
    );
    chat.inputOf('a').text = '草稿留下';
    chat.closeDock();
    chat.expandDock();
    expect(chat.inputOf('a').text, '草稿留下');
    chat.ingestInbox(const <ShopChatThreadModel>[
      ShopChatThreadModel(
        id: 'a',
        shopId: 's',
        customerUid: 'a',
        shopUnreadCount: 3,
      ),
      ShopChatThreadModel(
        id: 'b',
        shopId: 's',
        customerUid: 'b',
        shopUnreadCount: 1,
      ),
    ]);
    expect(chat.openIds, <String>['a']);
    expect(chat.inputOf('a').text, '草稿留下');
    chat.dispose();
  });

  testWidgets('窄視窗不產生 RenderFlex overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: ShopFrontendTestPanel(
              shopId: 'shop-test',
              shopCode: 'demo',
              onClose: () {},
              previewBodyOverride: const _LiveFrontendStub(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _CanvasWidthProbe extends StatelessWidget {
  const _CanvasWidthProbe();

  @override
  Widget build(BuildContext context) {
    return Text('canvas=${MediaQuery.sizeOf(context).width.round()}');
  }
}

class _LiveFrontendStub extends StatelessWidget {
  const _LiveFrontendStub({this.onSubmit});

  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool hideAdmin = ShopDashboardEmbeddedScope.isEmbeddedInShopDashboard(
      context,
    );
    return Column(
      children: <Widget>[
        Text('viewport=${size.width.toInt()}x${size.height.toInt()}'),
        const Text('正式前台根頁'),
        if (!hideAdmin) const Text('進入管理後台'),
        if (!hideAdmin) const Text('回後台'),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _FlowPage(title: '住宿預約流程', onSubmit: onSubmit),
              ),
            );
          },
          child: const Text('住宿預約'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _FlowPage(title: '安親預約流程', onSubmit: onSubmit),
              ),
            );
          },
          child: const Text('安親預約'),
        ),
      ],
    );
  }
}

class _FlowPage extends StatefulWidget {
  const _FlowPage({required this.title, this.onSubmit});

  final String title;
  final VoidCallback? onSubmit;

  @override
  State<_FlowPage> createState() => _FlowPageState();
}

class _FlowPageState extends State<_FlowPage> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: FilledButton(
          onPressed: _submitting
              ? null
              : () {
                  setState(() => _submitting = true);
                  widget.onSubmit?.call();
                },
          child: const Text('送出訂單'),
        ),
      ),
    );
  }
}

class _InlineSplitHarness extends StatelessWidget {
  const _InlineSplitHarness({
    required this.pageWidth,
    required this.height,
    required this.chatDockWidth,
  });

  static const Key previewKey = Key('inline-preview');
  static const Key backendKey = Key('inline-backend');
  static const Key chatKey = Key('inline-chat');

  final double pageWidth;
  final double height;
  final double chatDockWidth;

  @override
  Widget build(BuildContext context) {
    final double available = pageWidth - chatDockWidth < 0
        ? 0
        : pageWidth - chatDockWidth;
    final bool showPreview = ShopFrontendPreviewFrame.canShowInlinePreview(
      available,
    );
    final double previewWidth = ShopFrontendPreviewFrame.inlineWidthFor(
      available,
    );
    return SizedBox(
      width: pageWidth,
      height: height,
      child: Row(
        key: const Key('shop-dashboard-frontend-inline-split'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showPreview) ...<Widget>[
            SizedBox(
              key: previewKey,
              width: previewWidth,
              child: const ColoredBox(
                color: Colors.white,
                child: Text('live-frontend'),
              ),
            ),
            const SizedBox(width: ShopFrontendPreviewFrame.inlineColumnGap),
          ],
          const Expanded(
            child: ColoredBox(
              key: backendKey,
              color: Color(0xFFF7F8FC),
              child: Text('dashboard-main'),
            ),
          ),
          if (chatDockWidth > 0)
            SizedBox(
              key: chatKey,
              width: chatDockWidth,
              child: const ColoredBox(
                color: Colors.white,
                child: Text('chat-dock'),
              ),
            ),
        ],
      ),
    );
  }
}
