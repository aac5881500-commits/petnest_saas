// 檔案名稱：test/shop_chat_quick_dock_test.dart
// 功能說明：驗證快捷六格去重、替換、單一展開聊天室與版面規則。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_quick_dock_controller.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_quick_card.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_quick_dock.dart';
import 'package:shared_preferences/shared_preferences.dart';

ShopChatThreadModel _thread({
  required String id,
  int unread = 0,
  String last = 'hello',
  DateTime? at,
  String type = 'text',
}) {
  return ShopChatThreadModel(
    id: id,
    shopId: 'shop-1',
    customerUid: id,
    customerName: '會員$id',
    lastMessage: last,
    lastMessageType: type,
    lastMessageAt: at ?? DateTime(2026, 1, 1, 12),
    shopUnreadCount: unread,
  );
}

class _LiveThreadProbe extends StatefulWidget {
  const _LiveThreadProbe({required this.threadId});

  static final Set<String> live = <String>{};

  final String threadId;

  @override
  State<_LiveThreadProbe> createState() => _LiveThreadProbeState();
}

class _LiveThreadProbeState extends State<_LiveThreadProbe> {
  @override
  void initState() {
    super.initState();
    _LiveThreadProbe.live.add(widget.threadId);
  }

  @override
  void dispose() {
    _LiveThreadProbe.live.remove(widget.threadId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('完整聊天室 ${widget.threadId}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShopChatQuickDockController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    controller = ShopChatQuickDockController();
    await controller.attach(
      shopId: 'shop-1',
      uid: 'staff-1',
      listenInbox: false,
    );
    _LiveThreadProbe.live.clear();
  });

  tearDown(() {
    controller.dispose();
  });

  test('最多只顯示六張快捷卡，同一 conversation 不會重複加入', () {
    for (int i = 1; i <= 8; i++) {
      controller.pin(_thread(id: '$i', unread: 0));
    }
    expect(controller.slotIds.length, 6);
    expect(
      controller.pin(_thread(id: '3')),
      ShopChatQuickPinResult.expandedExisting,
    );
    expect(controller.slotIds.where((String id) => id == '3').length, 1);
  });

  test('新訊息自動加入空位', () {
    controller.pin(_thread(id: 'a', unread: 0), expand: false);
    controller.ingestInbox(<ShopChatThreadModel>[
      _thread(id: 'a', unread: 0, last: '舊'),
      _thread(id: 'b', unread: 2, last: '新來的', at: DateTime(2026, 2, 1)),
    ]);
    expect(controller.slotIds, containsAll(<String>['a', 'b']));
    expect(controller.expandedThreadId, isNull);
  });

  test('六格滿時優先替換最久未使用且已讀的卡', () {
    for (int i = 1; i <= 6; i++) {
      controller.pin(_thread(id: '$i', unread: i == 1 ? 0 : 0), expand: false);
    }
    controller.lastUsedAt['1'] = DateTime(2020);
    controller.lastUsedAt['2'] = DateTime(2021);
    controller.lastOpenedAt['1'] = DateTime(2019);
    final ShopChatQuickPinResult result = controller.pin(
      _thread(id: '7', unread: 3, at: DateTime(2026, 9, 1)),
      expand: false,
    );
    expect(result, ShopChatQuickPinResult.replaced);
    expect(controller.slotIds, isNot(contains('1')));
    expect(controller.slotIds, contains('7'));
    expect(controller.slotIds.length, 6);
  });

  test('六格全部未讀時不會自動移除', () {
    for (int i = 1; i <= 6; i++) {
      controller.pin(_thread(id: '$i', unread: 1), expand: false);
    }
    final List<String> before = List<String>.from(controller.slotIds);
    controller.ingestInbox(<ShopChatThreadModel>[
      for (int i = 1; i <= 6; i++) _thread(id: '$i', unread: 1),
      _thread(id: '7', unread: 4, at: DateTime(2026, 9, 20)),
    ]);
    expect(controller.slotIds, before);
    expect(controller.overflowUnread, 1);
    expect(controller.expandedThreadId, isNull);
  });

  test('關閉快捷卡不刪除或封存對話', () {
    final ShopChatThreadModel thread = _thread(id: 'keep', unread: 2);
    controller.pin(thread, expand: true);
    controller.removeSlot('keep');
    expect(controller.slotIds, isEmpty);
    expect(thread.status, 'active');
    expect(thread.shopUnreadCount, 2);
    expect(controller.snapshots.containsKey('keep'), isFalse);
  });

  test('快捷卡存在不代表訊息已讀', () {
    controller.pin(_thread(id: 'u1', unread: 5), expand: false);
    expect(controller.snapshots['u1']!.shopUnreadCount, 5);
    controller.ingestInbox(<ShopChatThreadModel>[
      _thread(id: 'u1', unread: 5, last: '仍未讀'),
    ]);
    expect(controller.snapshots['u1']!.shopUnreadCount, 5);
  });

  test('點收件匣的舊對話會加入快捷區並展開，已存在則不重複', () {
    controller.pin(_thread(id: 'old', unread: 0), expand: false);
    final ShopChatQuickPinResult first = controller.pin(
      _thread(id: 'old', unread: 0),
      expand: true,
    );
    expect(first, ShopChatQuickPinResult.expandedExisting);
    expect(controller.slotIds.where((String id) => id == 'old').length, 1);
    expect(controller.expandedThreadId, 'old');

    final ShopChatQuickPinResult added = controller.pin(
      _thread(id: 'from-inbox', unread: 0),
      expand: true,
    );
    expect(added, ShopChatQuickPinResult.added);
    expect(controller.expandedThreadId, 'from-inbox');
  });

  test('寬桌機、中桌機、手機與前台嵌入的版面規則', () {
    expect(ShopChatDockPlacement.isMobile(390), isTrue);
    expect(
      ShopChatDockPlacement.useInlineDock(
        pageWidth: 390,
        frontendEmbedded: false,
      ),
      isFalse,
    );
    expect(
      ShopChatDockPlacement.useOverlayDock(
        pageWidth: 390,
        frontendEmbedded: false,
      ),
      isFalse,
    );
    expect(
      ShopChatDockPlacement.useOverlayDock(
        pageWidth: 1280,
        frontendEmbedded: false,
      ),
      isTrue,
    );
    expect(
      ShopChatDockPlacement.useInlineDock(
        pageWidth: 1280,
        frontendEmbedded: false,
      ),
      isFalse,
    );
    expect(
      ShopChatDockPlacement.useInlineDock(
        pageWidth: 1600,
        frontendEmbedded: false,
      ),
      isTrue,
    );
    expect(
      ShopChatDockPlacement.useInlineDock(
        pageWidth: 1600,
        frontendEmbedded: true,
      ),
      isFalse,
    );
    expect(
      ShopChatDockPlacement.useOverlayDock(
        pageWidth: 1600,
        frontendEmbedded: true,
      ),
      isTrue,
    );
  });

  testWidgets('點快捷卡只展開一個完整聊天室', (WidgetTester tester) async {
    controller.pin(_thread(id: 'a'), expand: false);
    controller.pin(_thread(id: 'b'), expand: false);
    await tester.pumpWidget(_dockApp(controller));
    await tester.pump();
    expect(find.text('完整聊天室 a'), findsNothing);
    await tester.tap(find.text('會員a'));
    await tester.pump();
    expect(find.text('完整聊天室 a'), findsOneWidget);
    expect(find.text('完整聊天室 b'), findsNothing);
    controller.expand('b');
    await tester.pump();
    expect(find.text('完整聊天室 b'), findsOneWidget);
    expect(find.text('完整聊天室 a'), findsNothing);
  });

  testWidgets('切換卡片後不會同時存在兩個完整 messages stream', (WidgetTester tester) async {
    controller.pin(_thread(id: 'a'), expand: true);
    controller.pin(_thread(id: 'b'), expand: false);
    await tester.pumpWidget(_dockApp(controller));
    await tester.pump();
    expect(_LiveThreadProbe.live, <String>{'a'});
    controller.expand('b');
    await tester.pump();
    expect(_LiveThreadProbe.live, <String>{'b'});
  });

  testWidgets('手機寬度不顯示六格（版面改走全頁，Dock 不進 Dashboard）', (
    WidgetTester tester,
  ) async {
    expect(ShopChatDockPlacement.isMobile(400), isTrue);
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(400, 800)),
        child: SizedBox.shrink(),
      ),
    );
    expect(
      ShopChatDockPlacement.useInlineDock(
        pageWidth: 400,
        frontendEmbedded: false,
      ),
      isFalse,
    );
  });

  testWidgets('快捷六格與未讀提示不產生 RenderFlex overflow', (WidgetTester tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        fail(details.exceptionAsString());
      }
      FlutterError.presentError(details);
    };
    for (int i = 1; i <= 6; i++) {
      controller.pin(
        _thread(id: '$i', unread: 1, last: '這是一段比較長的最新訊息摘要用來測試兩行省略'),
        expand: false,
      );
    }
    controller.overflowUnread = 3;
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_dockApp(controller, width: 400));
    await tester.pump();
    expect(find.byType(ShopChatQuickCard), findsNWidgets(6));
    expect(find.textContaining('另有'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _dockApp(ShopChatQuickDockController controller, {double width = 420}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: 800,
        child: ShopChatQuickDock(
          shopId: 'shop-1',
          controller: controller,
          onCloseDock: () {},
          threadBuilder: (BuildContext context, String threadId) {
            return _LiveThreadProbe(threadId: threadId);
          },
        ),
      ),
    ),
  );
}
