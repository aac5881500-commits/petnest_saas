// 檔案名稱：test/shop_chat_layout_test.dart
// 功能說明：全頁聊天與桌機三格 Dock 寬度、開啟／關閉規則。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_multi_dock_controller.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_app_bar_button.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_desktop_workspace.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_entry.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_inbox_drawer.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_layout.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_member_snapshot.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_multi_dock.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_recent_orders.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

ShopChatThreadModel _thread(String id) {
  return ShopChatThreadModel(
    id: id,
    shopId: 'shop-1',
    customerUid: id,
    customerName: '會員$id',
  );
}

void main() {
  tearDown(() {
    ShopChatEntry.debugFullScreenInboxBuilder = null;
  });

  test('>=1280 才開三格 Dock，總寬約 650、左欄 160、右欄不壓窄', () {
    expect(ShopChatLayout.useFullScreenChat(500), isTrue);
    expect(ShopChatLayout.useFullScreenChat(1023), isTrue);
    expect(ShopChatLayout.useFullScreenChat(1024), isTrue);
    expect(ShopChatLayout.useFullScreenChat(1279), isTrue);
    expect(ShopChatLayout.useFullScreenChat(1280), isFalse);
    expect(ShopChatLayout.inboxColumnWidth, inInclusiveRange(155, 165));
    expect(ShopChatLayout.dockWidthFor(1400), lessThanOrEqualTo(670));
    expect(ShopChatLayout.dockWidthFor(1400), greaterThanOrEqualTo(630));
    expect(
      ShopChatLayout.dockWidthFor(1400) - ShopChatLayout.inboxColumnWidth - 1,
      greaterThanOrEqualTo(445),
    );
    expect(
      ShopChatLayout.shouldShowDesktopDock(pageWidth: 1200, inboxOpen: true),
      isFalse,
    );
    expect(
      ShopChatLayout.shouldShowDesktopDock(pageWidth: 1400, inboxOpen: true),
      isTrue,
    );
  });

  test('可同時開 1～3 位，第 4 位拒絕且不覆蓋，關閉中間會往上補', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ShopChatMultiDockController controller =
        ShopChatMultiDockController();
    addTearDown(controller.dispose);
    await controller.attach(
      shopId: 'shop-1',
      uid: 'staff-1',
      listenInbox: false,
    );

    expect(
      controller.openDesktopSlot(_thread('a')).kind,
      ShopChatOpenKind.added,
    );
    expect(
      controller.openDesktopSlot(_thread('b')).kind,
      ShopChatOpenKind.added,
    );
    expect(
      controller.openDesktopSlot(_thread('c')).kind,
      ShopChatOpenKind.added,
    );
    expect(controller.slotIds, <String>['a', 'b', 'c']);
    expect(
      controller.openDesktopSlot(_thread('a')).kind,
      ShopChatOpenKind.focusedExisting,
    );
    expect(controller.slotIds.where((String id) => id == 'a').length, 1);
    expect(
      controller.openDesktopSlot(_thread('d')).kind,
      ShopChatOpenKind.rejectedFull,
    );
    expect(controller.slotIds, <String>['a', 'b', 'c']);
    controller.closeDesktopSlot('b');
    expect(controller.slotIds, <String>['a', 'c']);
  });

  test('會員資料空欄位隱藏，寵物最多列出 3 隻', () {
    expect(
      ShopChatMemberSnapshot.petNamesFromMember(<String, dynamic>{
        'pets': <Map<String, dynamic>>[
          <String, dynamic>{'name': '小米'},
          <String, dynamic>{'name': '橘子'},
          <String, dynamic>{'name': '牛奶'},
          <String, dynamic>{'name': '豆豆'},
        ],
      }),
      <String>['小米', '橘子', '牛奶', '豆豆'],
    );
    const ShopChatMemberSnapshot snap = ShopChatMemberSnapshot(
      name: '王小明',
      phone: '',
      email: '',
      photoUrl: '',
      vip: false,
      regular: false,
      blacklisted: true,
      emergencyName: '',
      emergencyPhone: '',
      petNames: <String>['小米', '橘子', '牛奶', '豆豆'],
      currentServiceLabel: '目前沒有服務中的訂單',
    );
    expect(snap.memberTag, '黑名單');
    expect(snap.petSummary, '4 隻・小米、橘子、牛奶 ＋1 隻');
  });

  test('最近訂單解析住宿／安親且最多 5 筆', () {
    final List<ShopChatRecentOrderItem> items =
        ShopChatRecentOrderItem.fromBookings(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'stay-1',
            'bookingKind': BookingKind.accommodation,
            'bookingCode': 'ST01',
            'status': 'checked_in',
            'roomName': 'A1',
            'petNames': <String>['小米'],
            'startDate': DateTime(2026, 9, 20),
            'endDate': DateTime(2026, 9, 22),
          },
          <String, dynamic>{
            'id': 'day-1',
            'bookingKind': BookingKind.daycare,
            'bookingCode': 'DY01',
            'status': 'checked_in',
            'pets': <Map<String, dynamic>>[
              <String, dynamic>{'name': '橘子'},
            ],
            'scheduledStartAt': DateTime(2026, 9, 21, 9),
            'scheduledEndAt': DateTime(2026, 9, 21, 18),
          },
        ]);
    expect(items.length, 2);
    expect(items.first.kindLabel, '住宿');
    expect(items.first.roomName, 'A1');
    expect(items.first.isDaycare, isFalse);
    expect(items.last.kindLabel, '安親');
    expect(items.last.isDaycare, isTrue);
    expect(items.last.petText, '橘子');
  });

  testWidgets('手機與平板點聊天開全螢幕，不建立三格 Dock', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ShopChatEntry.debugFullScreenInboxBuilder = (String shopId) {
      return Scaffold(
        appBar: AppBar(title: const Text('全部聊天')),
        body: Text('fullscreen-inbox-$shopId'),
      );
    };
    final ShopAdminWorkspaceController workspace = ShopAdminWorkspaceController(
      canUseChat: true,
    );
    addTearDown(workspace.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 900)),
          child: ShopAdminWorkspaceScope(
            controller: workspace,
            child: Scaffold(
              appBar: AppBar(
                actions: const <Widget>[ShopChatAppBarButton(shopId: 'shop-1')],
              ),
              body: const Text('dashboard-body'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ShopChatAppBarButton));
    await tester.pumpAndSettle();

    expect(find.text('fullscreen-inbox-shop-1'), findsOneWidget);
    expect(find.byType(ShopChatDesktopWorkspace), findsNothing);
    expect(find.byType(ShopChatInboxDrawer), findsNothing);
    expect(find.byType(ShopChatMultiDock), findsNothing);
    expect(workspace.inboxOpen, isFalse);
  });

  testWidgets('桌機 >=1280 點聊天開 Dock 旗標，不 push 全螢幕收件匣', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ShopChatEntry.debugFullScreenInboxBuilder = (String shopId) {
      return Text('fullscreen-inbox-$shopId');
    };
    final ShopAdminWorkspaceController workspace = ShopAdminWorkspaceController(
      canUseChat: true,
    );
    addTearDown(workspace.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1400, 900)),
          child: ShopAdminWorkspaceScope(
            controller: workspace,
            child: Scaffold(
              appBar: AppBar(
                actions: const <Widget>[ShopChatAppBarButton(shopId: 'shop-1')],
              ),
              body: const Text('dashboard-body'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ShopChatAppBarButton));
    await tester.pump();

    expect(find.text('fullscreen-inbox-shop-1'), findsNothing);
    expect(find.text('dashboard-body'), findsOneWidget);
    expect(workspace.inboxOpen, isTrue);
  });
}
