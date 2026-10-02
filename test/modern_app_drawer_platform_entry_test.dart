import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_app_drawer.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_embedded_scope.dart';
import 'package:petnest_saas/models/home/modern_drawer_setting_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('桌機與手機預覽選單可返回平台，且不會留在預覽畫布', (tester) async {
    await _openAndLeave(tester, const Size(1400, 900));
    await _openAndLeave(tester, const Size(390, 800));
  });
}

Future<void> _openAndLeave(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      initialRoute: '/',
      routes: <String, WidgetBuilder>{
        '/': (_) => const _DashboardShell(),
        '/home': (_) => const Scaffold(body: Text('平台首頁')),
      },
    ),
  );

  await tester.pump();

  await tester.tap(find.text('開啟選單'));
  await tester.pumpAndSettle();

  expect(tester.takeException(), isNull);
  expect(find.text('返回平台'), findsOneWidget);
  expect(find.text('返回店家後台'), findsNothing);
  expect(find.text('返回後台'), findsNothing);
  expect(find.text('回後台'), findsNothing);
  expect(find.text('店家後台'), findsOneWidget);

  await tester.tap(find.text('返回平台'));
  await tester.pumpAndSettle();

  expect(tester.takeException(), isNull);
  expect(find.text('平台首頁'), findsOneWidget);
  expect(find.text('店家後台'), findsNothing);
  expect(find.text('開啟選單'), findsNothing);
}

class _DashboardShell extends StatelessWidget {
  const _DashboardShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const Text('店家後台'),
          Expanded(
            child: ShopDashboardEmbeddedScope(
              child: Navigator(
                pages: <Page<void>>[
                  MaterialPage<void>(
                    child: Scaffold(
                      drawer: ModernAppDrawer(
                        shopId: 'shop-1',
                        shop: const <String, dynamic>{'name': '測試店'},
                        theme: HomeThemeModel(
                          backgroundColorValue: 0xFFFFFFFF,
                          cardColorValue: 0xFFFFFFFF,
                          cardBorderColorValue: 0xFFEEEEEE,
                          primaryColorValue: 0xFFFF8A00,
                          textColorValue: 0xFF333333,
                          drawerSetting: ModernDrawerSettingModel(
                            showLatestBooking: false,
                            showMemberCenter: false,
                            showShopMenus: false,
                            showFooter: false,
                          ),
                        ),
                      ),
                      body: Builder(
                        builder: (BuildContext context) {
                          return TextButton(
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            child: const Text('開啟選單'),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                onDidRemovePage: (Page<Object?> page) {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
