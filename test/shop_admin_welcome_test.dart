// 檔案名稱：test/shop_admin_welcome_test.dart
// 功能說明：新店家首次歡迎的顯示條件與彈窗排版。不寫入 Firebase。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/shop_admin_welcome.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_welcome_dialog.dart';

void main() {
  final created = ShopAdminWelcome.introducedAt.add(const Duration(hours: 1));
  final older = ShopAdminWelcome.introducedAt.subtract(const Duration(days: 1));

  Map<String, dynamic> shop({
    required DateTime createdAt,
    String ownerUid = 'owner-1',
    String phone = '',
    String address = '',
  }) {
    return {
      'createdAt': createdAt,
      'ownerUid': ownerUid,
      'phone': phone,
      'address': address,
    };
  }

  test('既有店家與其他店家狀態不會觸發首次歡迎', () {
    expect(
      ShopAdminWelcome.shouldShow(
        shop: shop(createdAt: older),
        shopId: 'SHOP0001',
        uid: 'owner-1',
        role: 'owner',
        userLoaded: true,
        userData: const {},
      ),
      isFalse,
    );
    expect(
      ShopAdminWelcome.shouldShow(
        shop: const {'ownerUid': 'owner-1', 'phone': '', 'address': ''},
        shopId: 'SHOP0001',
        uid: 'owner-1',
        role: 'owner',
        userLoaded: true,
        userData: const {},
      ),
      isFalse,
    );
    expect(
      ShopAdminWelcome.shouldShow(
        shop: shop(createdAt: created, ownerUid: 'someone-else'),
        shopId: 'SHOP0002',
        uid: 'owner-1',
        role: 'owner',
        userLoaded: true,
        userData: const {},
      ),
      isFalse,
    );
    expect(
      ShopAdminWelcome.shouldShow(
        shop: shop(createdAt: created),
        shopId: 'SHOP0002',
        uid: 'owner-1',
        role: 'staff',
        userLoaded: true,
        userData: const {},
      ),
      isFalse,
    );
    expect(
      ShopAdminWelcome.shouldShow(
        shop: shop(createdAt: created),
        shopId: 'SHOP0002',
        uid: 'owner-1',
        role: 'owner',
        userLoaded: false,
        userData: null,
      ),
      isFalse,
    );
    expect(
      ShopAdminWelcome.shouldShow(
        shop: shop(createdAt: created),
        shopId: 'SHOP0002',
        uid: 'owner-1',
        role: 'owner',
        userLoaded: true,
        userData: const {
          'shopAdminWelcome': {
            'SHOP0001': {'status': 'later'},
          },
        },
      ),
      isTrue,
    );
    expect(
      ShopAdminWelcome.shouldShow(
        shop: shop(createdAt: created),
        shopId: 'SHOP0002',
        uid: 'owner-1',
        role: 'owner',
        userLoaded: true,
        userData: const {
          'shopAdminWelcome': {
            'SHOP0002': {'status': 'started'},
          },
        },
      ),
      isFalse,
    );
  });

  test('基本資料未完成才顯示提醒，完成後消失', () {
    expect(
      ShopAdminWelcome.shouldRemind(
        shop: shop(createdAt: created),
        profileComplete: false,
      ),
      isTrue,
    );
    expect(
      ShopAdminWelcome.shouldRemind(
        shop: shop(createdAt: created, phone: '02', address: '地址'),
        profileComplete: true,
      ),
      isFalse,
    );
    expect(
      ShopAdminWelcome.shouldRemind(
        shop: shop(createdAt: older),
        profileComplete: false,
      ),
      isFalse,
    );
  });

  testWidgets('歡迎彈窗在手機與桌機寬度不溢出', (tester) async {
    const sizes = <Size>[
      Size(320, 700),
      Size(375, 812),
      Size(390, 844),
      Size(430, 932),
      Size(1280, 800),
      Size(1440, 900),
      Size(1920, 1080),
    ];
    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var started = 0;
      var later = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ShopAdminWelcomeDialog(
            onStart: () => started++,
            onLater: () => later++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      final card = tester.getSize(
        find.byKey(const ValueKey('shop-admin-welcome')),
      );
      expect(card.width, lessThanOrEqualTo(size.width));
      expect(card.height, lessThan(size.height));
      if (size.width >= 900) {
        expect(card.height, lessThan(size.height * 0.85));
        expect(card.width, lessThanOrEqualTo(920));
      }
      expect(find.text('歡迎加入 PetNest！'), findsOneWidget);
      expect(find.text('你的貓咪旅社建立成功了！'), findsOneWidget);
      expect(find.text('建立旅社'), findsOneWidget);
      expect(find.text('完善基本資料'), findsOneWidget);
      expect(find.text('開始準備營運'), findsOneWidget);
      final scrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      if (scrollable.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('shop-admin-welcome-start')),
          200,
          scrollable: scrollable,
        );
      }
      expect(
        find.byKey(const ValueKey('shop-admin-welcome-start')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('shop-admin-welcome-later')));
      expect(later, 1);
      expect(started, 0);
    }
  });

  testWidgets('提醒卡可前往基本資料，完成前不會自行消失', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ShopAdminWelcomeReminder(onOpen: () => opened++)),
      ),
    );
    expect(find.text('再完成一點點，讓你的旅社準備好迎接毛孩！'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('shop-admin-welcome-reminder-open')),
    );
    expect(opened, 1);
  });

  testWidgets('提醒卡保留基本資料入口並移除重播，窄螢幕不溢出', (tester) async {
    for (final width in <double>[320, 390, 430, 1280, 1440]) {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: ShopAdminWelcomeReminder(onOpen: () => opened++),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('前往完善資料 →'), findsOneWidget);
      expect(find.text('重新觀看引導'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('shop-admin-welcome-reminder-open')),
      );
      expect(opened, 1);
    }
  });
}
