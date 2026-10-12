import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_quick_action_setting.dart';
import 'package:petnest_saas/core/models/home_shortcut_gate.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_quick_action_bar.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_quick_action_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_editor_overlay.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing settings keep the bell and follow feature gates', () {
    final HomeQuickActionSetting setting = HomeQuickActionSetting.fromMap(null);
    expect(
      setting
          .visibleItems(storeEnabled: false, chatEnabled: false)
          .map((HomeQuickActionItem item) => item.id),
      <String>[HomeQuickActionIds.notifications],
    );
    expect(
      setting
          .visibleItems(storeEnabled: true, chatEnabled: true)
          .map((HomeQuickActionItem item) => item.id),
      <String>[
        HomeQuickActionIds.notifications,
        HomeQuickActionIds.cart,
        HomeQuickActionIds.chat,
      ],
    );
    expect(setting.showBadges, isTrue);
    expect(setting.placement, HomeQuickActionSetting.placementEnd);
  });

  test('the bell stays on and unknown actions are kept', () {
    final HomeQuickActionSetting setting = HomeQuickActionSetting.fromMap(
      <String, dynamic>{
        'placement': 'somewhere',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'futureDesk', 'enabled': true},
          <String, dynamic>{
            'id': HomeQuickActionIds.notifications,
            'enabled': false,
          },
          <String, dynamic>{'id': HomeQuickActionIds.cart, 'enabled': false},
          <String, dynamic>{'id': HomeQuickActionIds.chat, 'enabled': true},
        ],
      },
    );
    expect(setting.placement, HomeQuickActionSetting.placementEnd);
    expect(
      setting.items
          .firstWhere(
            (HomeQuickActionItem item) =>
                item.id == HomeQuickActionIds.notifications,
          )
          .enabled,
      isTrue,
    );
    expect(setting.toggle(HomeQuickActionIds.notifications, false), setting);
    expect(
      setting
          .visibleItems(storeEnabled: true, chatEnabled: false)
          .map((HomeQuickActionItem item) => item.id),
      <String>[HomeQuickActionIds.notifications],
    );
    expect(
      setting
          .visibleItems(storeEnabled: true, chatEnabled: true)
          .map((HomeQuickActionItem item) => item.id),
      <String>[HomeQuickActionIds.notifications, HomeQuickActionIds.chat],
    );
    final List<dynamic> saved = setting.toMap()['items'] as List<dynamic>;
    expect(
      saved.any(
        (dynamic item) =>
            item is Map &&
            item['id'] == 'futureDesk' &&
            item['enabled'] == true,
      ),
      isTrue,
    );
  });

  test('order can move the bell without removing it', () {
    final HomeQuickActionSetting moved = const HomeQuickActionSetting()
        .moveKnown(0, 1);
    expect(
      moved.knownItems.map((HomeQuickActionItem item) => item.id),
      <String>[
        HomeQuickActionIds.cart,
        HomeQuickActionIds.notifications,
        HomeQuickActionIds.chat,
      ],
    );
    expect(
      moved.visibleItems(storeEnabled: false, chatEnabled: false).single.id,
      HomeQuickActionIds.notifications,
    );
  });

  test('badge label and cart quantity use the cart lines', () {
    expect(homeQuickActionBadgeLabel(0), isNull);
    expect(homeQuickActionBadgeLabel(8), '8');
    expect(homeQuickActionBadgeLabel(99), '99');
    expect(homeQuickActionBadgeLabel(100), '99+');
    expect(homeQuickActionCartQuantity(<int>[2, 0, -1, 3]), 5);
  });

  testWidgets('bar shows the bell, hides an empty badge, and caps 99+', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _barApp(
        width: 280,
        setting: const HomeQuickActionSetting(),
        buttons: const <HomeQuickActionButton>[
          HomeQuickActionButton(
            id: HomeQuickActionIds.notifications,
            icon: Icons.notifications_none_rounded,
            label: '通知',
            badgeCount: 120,
          ),
          HomeQuickActionButton(
            id: HomeQuickActionIds.cart,
            icon: Icons.shopping_cart_outlined,
            label: '購物車',
            badgeCount: 0,
          ),
        ],
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('home-quick-action-notifications')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('home-quick-action-cart')),
      findsOneWidget,
    );
    expect(find.text('99+'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-quick-action-badge-cart')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning badges off does not remove the button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _barApp(
        width: 280,
        setting: const HomeQuickActionSetting(showBadges: false),
        buttons: const <HomeQuickActionButton>[
          HomeQuickActionButton(
            id: HomeQuickActionIds.notifications,
            icon: Icons.notifications_none_rounded,
            label: '通知',
            badgeCount: 4,
          ),
        ],
      ),
    );
    expect(find.byTooltip('通知'), findsOneWidget);
    expect(find.text('4'), findsNothing);
  });

  testWidgets('a narrow header keeps the bell and opens the rest', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _barApp(
        width: 100,
        setting: const HomeQuickActionSetting(),
        buttons: const <HomeQuickActionButton>[
          HomeQuickActionButton(
            id: HomeQuickActionIds.notifications,
            icon: Icons.notifications_none_rounded,
            label: '通知',
            badgeCount: 1,
          ),
          HomeQuickActionButton(
            id: HomeQuickActionIds.cart,
            icon: Icons.shopping_cart_outlined,
            label: '購物車',
            badgeCount: 2,
          ),
          HomeQuickActionButton(
            id: HomeQuickActionIds.chat,
            icon: Icons.chat_bubble_outline_rounded,
            label: '訊息',
            badgeCount: 0,
          ),
        ],
      ),
    );
    expect(find.byTooltip('通知'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-quick-action-overflow')),
      findsOneWidget,
    );
    expect(find.byTooltip('購物車'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actions sit beside the name and do not cover the menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: StoreBrandTopBar(
                style: const StoreBrandStyle(),
                shopName: '寵物旅館',
                subtitle: '溫暖的家',
                logoUrl: '',
                theme: HomeThemeModel.modernDefault,
                backgroundColor: Colors.white,
                leading: const Icon(Icons.menu, key: Key('shop-menu')),
                actions: const HomeQuickActionBar(
                  setting: HomeQuickActionSetting(),
                  theme: HomeThemeModel.modernDefault,
                  buttons: <HomeQuickActionButton>[
                    HomeQuickActionButton(
                      id: HomeQuickActionIds.notifications,
                      icon: Icons.notifications_none_rounded,
                      label: '通知',
                      badgeCount: 0,
                    ),
                    HomeQuickActionButton(
                      id: HomeQuickActionIds.cart,
                      icon: Icons.shopping_cart_outlined,
                      label: '購物車',
                      badgeCount: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final Rect menu = tester.getRect(find.byKey(const Key('shop-menu')));
    final Rect bell = tester.getRect(
      find.byKey(const ValueKey<String>('home-quick-action-notifications')),
    );
    final Rect cart = tester.getRect(
      find.byKey(const ValueKey<String>('home-quick-action-cart')),
    );
    final Rect name = tester.getRect(find.text('寵物旅館'));
    expect(menu.right, lessThanOrEqualTo(bell.left));
    expect(name.right, lessThanOrEqualTo(bell.left));
    final Rect header = tester.getRect(find.byType(StoreBrandTopBar));
    expect(bell.right, lessThanOrEqualTo(cart.left));
    expect(menu.left, greaterThanOrEqualTo(header.left));
    expect(cart.right, lessThanOrEqualTo(header.right));
    expect(tester.takeException(), isNull);
  });

  test('stored slots stay put when a feature is unavailable', () {
    final HomeQuickActionSetting setting = HomeQuickActionSetting.fromMap(
      <String, dynamic>{
        'slots': <String>[HomeQuickActionIds.cart, HomeQuickActionIds.chat],
      },
    );
    final HomeShortcutGate blocked = HomeShortcutGate(
      storeEnabled: false,
      chatProvisioned: false,
      phoneReady: false,
      lineReady: false,
      facebookReady: false,
      instagramReady: false,
      announcementsEnabled: true,
      faqEnabled: true,
      memberCenterEnabled: true,
      showShopMenus: true,
      paidPlan: true,
      floatingEnabled: true,
      floatingType: HomeQuickActionIds.chat,
    );
    expect(setting.slotOne, HomeQuickActionIds.cart);
    expect(setting.slotTwo, HomeQuickActionIds.chat);
    expect(blocked.visibleIds(setting), <String>[
      HomeQuickActionIds.notifications,
    ]);
    final HomeShortcutGate open = HomeShortcutGate(
      storeEnabled: true,
      chatProvisioned: true,
      phoneReady: true,
      lineReady: false,
      facebookReady: false,
      instagramReady: false,
      announcementsEnabled: true,
      faqEnabled: true,
      memberCenterEnabled: true,
      showShopMenus: true,
      paidPlan: true,
      floatingEnabled: false,
      floatingType: HomeQuickActionIds.phone,
    );
    expect(open.visibleIds(setting), <String>[
      HomeQuickActionIds.notifications,
      HomeQuickActionIds.cart,
      HomeQuickActionIds.chat,
    ]);
    expect(
      open.selectionReason(HomeQuickActionIds.phone, otherSlot: ''),
      isNull,
    );
    expect(open.copyWith().blockReason(HomeQuickActionIds.line), '請先填寫 LINE');
    final HomeQuickActionSetting phone = setting.assignSlot(
      1,
      HomeQuickActionIds.phone,
    );
    expect(phone.slotOne, HomeQuickActionIds.cart);
    expect(phone.slotTwo, HomeQuickActionIds.phone);
    expect(
      open.selectionReason(HomeQuickActionIds.cart, otherSlot: phone.slotOne),
      '已用於另一個快捷鍵',
    );
  });

  testWidgets('unavailable shortcut keeps its saved choice and explains why', (
    WidgetTester tester,
  ) async {
    HomeQuickActionSetting setting = const HomeQuickActionSetting();
    const HomeShortcutGate gate = HomeShortcutGate(
      storeEnabled: false,
      chatProvisioned: true,
      phoneReady: false,
      lineReady: true,
      facebookReady: false,
      instagramReady: false,
      announcementsEnabled: true,
      faqEnabled: true,
      memberCenterEnabled: true,
      showShopMenus: true,
      paidPlan: true,
      floatingEnabled: true,
      floatingType: HomeQuickActionIds.chat,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeQuickActionSettingsPanel(
            setting: setting,
            gate: gate,
            onChanged: (HomeQuickActionSetting value) => setting = value,
          ),
        ),
      ),
    );
    expect(find.text('請先啟用商城'), findsOneWidget);
    expect(find.text('已由懸浮按鈕使用'), findsOneWidget);
    expect(find.text('通知鈴鐺（固定顯示）'), findsOneWidget);
    expect(setting.slotOne, HomeQuickActionIds.cart);
    expect(setting.slotTwo, HomeQuickActionIds.chat);
  });

  testWidgets('role cards fit a phone column and keep disabled values', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final TextEditingController label = TextEditingController(text: '聯絡店家');
    addTearDown(label.dispose);
    const HomeShortcutGate gate = HomeShortcutGate(
      storeEnabled: false,
      chatProvisioned: false,
      phoneReady: true,
      lineReady: false,
      facebookReady: true,
      instagramReady: false,
      announcementsEnabled: false,
      faqEnabled: false,
      memberCenterEnabled: false,
      showShopMenus: false,
      paidPlan: false,
      floatingEnabled: false,
      floatingType: HomeQuickActionIds.facebook,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              FrontendRoleActionsPanel(
                floatingEnabled: false,
                floatingType: HomeQuickActionIds.facebook,
                floatingSize: 'large',
                labelController: label,
                quickActions: const HomeQuickActionSetting(),
                gate: gate,
                onFloatingEnabled: (_) {},
                onFloatingType: (_) {},
                onFloatingSize: (_) {},
                onQuickActions: (_) {},
                onLabelChanged: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('前台快捷按鈕'), findsOneWidget);
    expect(find.text('右上角快捷鍵'), findsOneWidget);
    expect(find.text('懸浮聯絡按鈕'), findsOneWidget);
    expect(find.text('快捷鍵一'), findsOneWidget);
    expect(find.text('快捷鍵二'), findsOneWidget);
    expect(find.text('通知鈴鐺（固定顯示）'), findsOneWidget);
    expect(find.text('請先啟用商城'), findsOneWidget);
    expect(find.text('店家聊天尚未開通'), findsOneWidget);
    final Finder menus = find.byType(DropdownButtonFormField<String>);
    expect(menus, findsWidgets);
    expect(
      tester.getTopLeft(menus.at(1)).dy,
      greaterThan(tester.getTopLeft(menus.at(0)).dy + 20),
    );
    expect(find.text('小'), findsOneWidget);
    expect(find.text('中'), findsOneWidget);
    expect(find.text('大'), findsOneWidget);
    expect(find.text('聯絡店家'), findsOneWidget);
    expect(find.text('可直接在左側前台預覽拖曳位置。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shortcut menus sit side by side on a desktop settings column', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final TextEditingController label = TextEditingController();
    addTearDown(label.dispose);
    const HomeShortcutGate gate = HomeShortcutGate(
      storeEnabled: true,
      chatProvisioned: true,
      phoneReady: true,
      lineReady: true,
      facebookReady: true,
      instagramReady: true,
      announcementsEnabled: true,
      faqEnabled: true,
      memberCenterEnabled: true,
      showShopMenus: true,
      paidPlan: true,
      floatingEnabled: true,
      floatingType: HomeQuickActionIds.chat,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 960,
              height: 900,
              child: ListView(
                children: <Widget>[
                  FrontendRoleActionsPanel(
                    floatingEnabled: true,
                    floatingType: HomeQuickActionIds.chat,
                    floatingSize: 'medium',
                    labelController: label,
                    quickActions: const HomeQuickActionSetting(
                      slotOne: HomeQuickActionIds.cart,
                      slotTwo: HomeQuickActionIds.faq,
                    ),
                    gate: gate,
                    onFloatingEnabled: (_) {},
                    onFloatingType: (_) {},
                    onFloatingSize: (_) {},
                    onQuickActions: (_) {},
                    onLabelChanged: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final Finder menus = find.byType(DropdownButtonFormField<String>);
    expect(menus, findsWidgets);
    final Offset first = tester.getTopLeft(menus.at(0));
    final Offset second = tester.getTopLeft(menus.at(1));
    expect((second.dy - first.dy).abs(), lessThan(8));
    expect(second.dx, greaterThan(first.dx + 80));
    await tester.tap(menus.at(0));
    await tester.pumpAndSettle();
    expect(find.text('PetNest 店家聊天（已由懸浮按鈕使用）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _barApp({
  required double width,
  required HomeQuickActionSetting setting,
  required List<HomeQuickActionButton> buttons,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: HomeQuickActionBar(
            setting: setting,
            theme: HomeThemeModel.modernDefault,
            buttons: buttons,
          ),
        ),
      ),
    ),
  );
}
