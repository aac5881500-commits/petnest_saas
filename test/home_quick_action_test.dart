import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_quick_action_setting.dart';
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

  testWidgets('owner can reorder and the cart switch waits for the store', (
    WidgetTester tester,
  ) async {
    HomeQuickActionSetting setting = const HomeQuickActionSetting();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: HomeQuickActionSettingsPanel(
                  setting: setting,
                  theme: HomeThemeModel.modernDefault,
                  storeEnabled: false,
                  chatEnabled: true,
                  onChanged: (HomeQuickActionSetting value) {
                    setState(() => setting = value);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    final List<Switch> switches = tester
        .widgetList<Switch>(find.byType(Switch))
        .toList();
    expect(switches[1].onChanged, isNull);
    expect(switches[2].onChanged, isNull);
    expect(switches[3].onChanged, isNotNull);

    await tester.tap(find.byTooltip('下移').first);
    await tester.pump();
    expect(setting.knownItems.first.id, HomeQuickActionIds.cart);
    expect(
      setting.knownItems.map((HomeQuickActionItem item) => item.id),
      contains(HomeQuickActionIds.notifications),
    );
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
