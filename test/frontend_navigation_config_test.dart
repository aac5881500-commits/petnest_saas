import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/navigation/shop_main_tab_route.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/frontend_navigation_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_bottom_navigation.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_menu_button.dart';

void main() {
  const FrontendNavShopState openShop = FrontendNavShopState(
    paidPlan: true,
    storeEnabled: true,
    chatEnabled: true,
    announcementsEnabled: true,
    faqEnabled: true,
    showMemberCenter: true,
    showShopMenus: true,
    loggedIn: true,
  );

  test('舊資料沒有 navigationStyle 時使用側邊選單', () {
    final FrontendNavigationConfig config = FrontendNavigationConfig.fromMap(
      <String, dynamic>{'headerSubtitle': 'hi'},
    );
    expect(config.style, FrontendNavigationConfig.styleDrawer);
    expect(config.drawerHiddenItemIds, isEmpty);
    expect(config.drawerItemOrder.first, 'home');
    expect(config.left1, 'booking');
    expect(config.right2, 'member');
  });

  test('首頁不能隱藏，未知 id 會被忽略', () {
    final FrontendNavigationConfig config = FrontendNavigationConfig.fromMap(
      <String, dynamic>{
        'drawerHiddenItemIds': <String>['home', 'missing', 'faq'],
        'drawerItemOrder': <String>['faq', 'nope', 'home', 'faq'],
      },
    );
    expect(config.drawerHiddenItemIds, <String>['faq']);
    expect(config.drawerItemOrder.first, 'faq');
    expect(config.drawerItemOrder.where((String id) => id == 'home').length, 1);
    expect(config.drawerItemOrder, contains('booking'));
  });

  test('拖曳排序不會遺失或重複項目', () {
    final List<String> next = FrontendNavigationConfig.reorder(
      <String>['home', 'booking', 'rooms'],
      0,
      3,
    );
    expect(next, <String>['booking', 'rooms', 'home']);
    expect(next.toSet().length, next.length);
  });

  test('底部選單中間固定首頁，重複與未啟用項目會改用可用功能', () {
    final FrontendNavigationConfig config = FrontendNavigationConfig.fromMap(
      <String, dynamic>{
        'navigationStyle': 'bottom',
        'bottomNavigationSlots': <String, dynamic>{
          'left1': 'store',
          'left2': 'store',
          'home': 'orders',
          'right1': 'missing',
          'right2': 'member',
        },
      },
    );
    final FrontendNavShopState shop = FrontendNavShopState(
      paidPlan: true,
      storeEnabled: false,
      chatEnabled: false,
      announcementsEnabled: true,
      faqEnabled: true,
      showMemberCenter: true,
      showShopMenus: true,
      loggedIn: true,
    );
    final List<FrontendNavigationItem?> slots = config.resolvedBottomSlots(
      shop,
    );
    expect(slots[2]?.id, 'home');
    final List<String> ids = <String>[
      for (final FrontendNavigationItem? item in slots)
        if (item != null) item.id,
    ];
    expect(ids.toSet().length, ids.length);
    expect(ids, isNot(contains('store')));
  });

  test('舊資料沒有外型與透明度時維持貼底實心', () {
    final FrontendNavigationConfig config = FrontendNavigationConfig.fromMap(
      <String, dynamic>{'navigationStyle': 'bottom'},
    );
    expect(config.bottomAppearance, FrontendNavigationConfig.appearanceAttached);
    expect(config.bottomSurface, FrontendNavigationConfig.surfaceOpaque);
    final FrontendNavigationConfig unknown = FrontendNavigationConfig.fromMap(
      <String, dynamic>{
        'bottomNavigationAppearance': 'glass',
        'bottomNavigationSurface': 'blur',
      },
    );
    expect(unknown.bottomAppearance, FrontendNavigationConfig.appearanceAttached);
    expect(unknown.bottomSurface, FrontendNavigationConfig.surfaceOpaque);
  });

  test('店主、主管、員工可進後台，一般會員不行', () {
    expect(shopMemberCanOpenAdmin('owner'), isTrue);
    expect(shopMemberCanOpenAdmin('manager'), isTrue);
    expect(shopMemberCanOpenAdmin('staff'), isTrue);
    expect(shopMemberCanOpenAdmin('customer'), isFalse);
    expect(shopMemberCanOpenAdmin(null), isFalse);
  });

  testWidgets('切換底部選單會立刻回傳新設定，首頁格不能點開', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    FrontendNavigationConfig current = FrontendNavigationConfig.defaults();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: FrontendNavigationPanel(
                  config: current,
                  shopState: openShop,
                  onChanged: (FrontendNavigationConfig value) {
                    setState(() => current = value);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('底部選單'));
    await tester.pump();
    expect(current.isBottom, isTrue);
    expect(find.text('首頁'), findsWidgets);
    await tester.tap(find.text('左側 1'));
    await tester.pumpAndSettle();
    expect(find.text('尚未啟用'), findsNothing);
    expect(find.text('已使用'), findsWidgets);
  });

  testWidgets('店家選單只對店主顯示回後台，主要分頁返回回到店家首頁', (
    tester,
  ) async {
    final List<FrontendNavigationItem?> slots =
        FrontendNavigationConfig.defaults().resolvedBottomSlots(openShop);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: ModernBottomNavigation(
            slots: slots,
            theme: HomeThemeModel.modernDefault,
            selectedId: 'home',
            appearance: FrontendNavigationConfig.appearanceFloatingPill,
            surface: FrontendNavigationConfig.surfaceTranslucent,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('回後台'), findsNothing);
    expect(find.text('首頁'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: ShopMenuButton(
                shopId: 'shop-1',
                userId: '',
                shopName: '毛孩旅店',
                logoUrl: '',
                theme: HomeThemeModel.modernDefault,
                surface: FrontendNavigationConfig.surfaceOpaque,
                bottomBarHeight: ModernBottomNavigation.slotHeight(
                  FrontendNavigationConfig.appearanceAttached,
                  0,
                ),
                visible: false,
                persistPosition: false,
                allowNavigation: false,
                onPlatform: () {},
                onAdmin: () {},
              ),
            );
          },
        ),
      ),
    );
    expect(find.byTooltip('店家選單'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: ShopMenuButton(
                shopId: 'shop-1',
                userId: 'staff-1',
                shopName: '毛孩旅店',
                logoUrl: '',
                theme: HomeThemeModel.modernDefault,
                surface: FrontendNavigationConfig.surfaceOpaque,
                bottomBarHeight: ModernBottomNavigation.slotHeight(
                  FrontendNavigationConfig.appearanceAttached,
                  0,
                ),
                visible: true,
                persistPosition: false,
                allowNavigation: true,
                onPlatform: () {},
                onAdmin: () {},
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byTooltip('店家選單'));
    await tester.pumpAndSettle();
    expect(find.text('回店家後台'), findsOneWidget);
    expect(find.text('返回平台'), findsOneWidget);
    expect(find.text('查看店家資訊'), findsNothing);
    expect(find.text('登出'), findsNothing);
    await tester.tap(find.text('返回平台'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      const MaterialApp(
        home: _ShopShell(),
      ),
    );
    await tester.tap(find.text('我的訂單'));
    await tester.pumpAndSettle();
    expect(find.text('訂單頁'), findsOneWidget);
    await tester.tap(find.text('訂單詳細'));
    await tester.pumpAndSettle();
    expect(find.text('詳細頁'), findsWidgets);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('訂單頁'), findsOneWidget);
    expect(find.text('平台首頁'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('店家首頁'), findsOneWidget);
    expect(find.text('平台首頁'), findsNothing);
  });
}

class _ShopShell extends StatelessWidget {
  const _ShopShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('店家首頁')),
      body: Center(
        child: TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: RouteSettings(
                  name: ShopMainTabRoute.nameFor('orders'),
                ),
                builder: (BuildContext routeContext) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('訂單頁')),
                    body: Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(routeContext).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('詳細頁')),
                                body: const Text('詳細頁'),
                              ),
                            ),
                          );
                        },
                        child: const Text('訂單詳細'),
                      ),
                    ),
                  );
                },
              ),
            );
          },
          child: const Text('我的訂單'),
        ),
      ),
    );
  }
}
