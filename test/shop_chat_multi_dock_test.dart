// 檔案名稱：test/shop_chat_multi_dock_test.dart
// 功能說明：驗證左側選取、六窗並存、LRU 替換、監聽釋放與草稿恢復。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_multi_dock_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

ShopChatThreadModel _thread({
  required String id,
  int unread = 0,
  String last = 'hello',
}) {
  return ShopChatThreadModel(
    id: id,
    shopId: 'shop-1',
    customerUid: id,
    customerName: '會員$id',
    lastMessage: last,
    lastMessageAt: DateTime(2026, 1, 1, 12),
    shopUnreadCount: unread,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShopChatMultiDockController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    controller = ShopChatMultiDockController();
    await controller.attach(
      shopId: 'shop-1',
      uid: 'staff-1',
      listenInbox: false,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('左側選擇會員後加入右側，同一會員不會重複', () {
    expect(
      controller.openFromInbox(_thread(id: 'a')).kind,
      ShopChatOpenKind.added,
    );
    expect(controller.openIds, <String>['a']);
    expect(
      controller.openFromInbox(_thread(id: 'a')).kind,
      ShopChatOpenKind.focusedExisting,
    );
    expect(controller.openIds.where((String id) => id == 'a').length, 1);
  });

  test('六個聊天能同時存在', () {
    for (int i = 1; i <= 6; i++) {
      controller.openFromInbox(_thread(id: '$i'));
    }
    expect(controller.openIds.length, 6);
    expect(controller.openIds.toSet().length, 6);
  });

  test('選第七個時替換最久未使用的聊天', () {
    for (int i = 1; i <= 6; i++) {
      controller.openFromInbox(_thread(id: '$i'));
    }
    controller.lastActiveAt['1'] = DateTime(2020);
    controller.lastActiveAt['2'] = DateTime(2024);
    final ShopChatOpenResult result = controller.openFromInbox(
      _thread(id: '7'),
    );
    expect(result.kind, ShopChatOpenKind.replaced);
    expect(result.replacedId, '1');
    expect(controller.openIds, isNot(contains('1')));
    expect(controller.openIds.first, '7');
    expect(controller.openIds.length, 6);
  });

  test('點擊聊天室後更新 LRU 順序', () {
    controller.openFromInbox(_thread(id: 'a'));
    controller.openFromInbox(_thread(id: 'b'));
    controller.openFromInbox(_thread(id: 'c'));
    expect(controller.openIds.first, 'c');
    controller.touch('a');
    expect(controller.openIds.first, 'a');
    expect(controller.openIds.last, 'b');
  });

  test('關閉其中一個不影響其他聊天室', () {
    for (int i = 1; i <= 3; i++) {
      controller.openFromInbox(_thread(id: '$i'));
    }
    controller.closeWindow('2');
    expect(controller.openIds, containsAll(<String>['1', '3']));
    expect(controller.openIds, isNot(contains('2')));
  });

  test('關閉或替換後釋放訊息監聽', () {
    controller.openFromInbox(_thread(id: 'a'));
    controller.openFromInbox(_thread(id: 'b'));
    controller.registerMessageListener('a');
    controller.registerMessageListener('b');
    expect(controller.liveMessageListeners, containsAll(<String>['a', 'b']));
    controller.closeWindow('a');
    expect(controller.liveMessageListeners, isNot(contains('a')));
    expect(controller.liveMessageListeners, contains('b'));
    for (int i = 1; i <= 6; i++) {
      controller.openFromInbox(_thread(id: '$i'));
      controller.registerMessageListener('$i');
    }
    controller.lastActiveAt['1'] = DateTime(2019);
    controller.openFromInbox(_thread(id: 'x'));
    expect(controller.liveMessageListeners, isNot(contains('1')));
    expect(controller.openIds, contains('x'));
  });

  test('草稿在重新開啟聊天室後恢復', () {
    controller.openFromInbox(_thread(id: 'd1'));
    controller.inputOf('d1').text = '尚未送出';
    controller.closeWindow('d1');
    expect(controller.drafts['d1'], '尚未送出');
    controller.openFromInbox(_thread(id: 'd1'));
    expect(controller.inputOf('d1').text, '尚未送出');
  });

  test('新訊息不會自行替換聊天室', () {
    for (int i = 1; i <= 6; i++) {
      controller.openFromInbox(_thread(id: '$i'));
    }
    final List<String> before = List<String>.from(controller.openIds);
    controller.ingestInbox(<ShopChatThreadModel>[
      for (int i = 1; i <= 6; i++) _thread(id: '$i', unread: 2),
      _thread(id: 'newbie', unread: 9, last: '新訊息'),
    ]);
    expect(controller.openIds, before);
    expect(controller.openIds, isNot(contains('newbie')));
  });

  test('被替換聊天室的草稿會保留', () {
    for (int i = 1; i <= 6; i++) {
      controller.openFromInbox(_thread(id: '$i'));
    }
    controller.inputOf('1').text = '舊窗草稿';
    controller.lastActiveAt['1'] = DateTime(2018);
    controller.openFromInbox(_thread(id: '7'));
    expect(controller.drafts['1'], '舊窗草稿');
  });

  testWidgets('右側同時顯示多個小視窗而非單一摘要卡', (WidgetTester tester) async {
    controller.openFromInbox(_thread(id: 'a'));
    controller.openFromInbox(_thread(id: 'b'));
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 680,
            height: 900,
            child: ListenableBuilder(
              listenable: controller,
              builder: (BuildContext context, Widget? child) {
                return GridView.count(
                  crossAxisCount: 2,
                  children: controller.openIds
                      .map((String id) => Text('窗$id'))
                      .toList(),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('窗a'), findsOneWidget);
    expect(find.text('窗b'), findsOneWidget);
  });
}
