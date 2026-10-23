import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/features/shop/widgets/shop_feature_tour.dart';
import 'package:petnest_saas/features/shop/pages/daily_care_setting_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_payment_setting_page.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';

class _KeptTourTestChild extends StatefulWidget {
  const _KeptTourTestChild({required this.child});
  final Widget child;
  @override
  State<_KeptTourTestChild> createState() => _KeptTourTestChildState();
}

class _KeptTourTestChildState extends State<_KeptTourTestChild>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _TourTestPanels extends StatelessWidget {
  const _TourTestPanels({required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Builder(
      builder: (context) => ShopTourPage(
        id: id,
        shopId: 's',
        onPoint: (point) async =>
            DefaultTabController.of(context).index = shopTourPanel(id, point),
        child: Scaffold(
          body: TabBarView(
            children: [
              for (var panel = 0; panel < 3; panel++)
                ListView(
                  children: [
                    const SizedBox(height: 550),
                    ShopTourAnchor(
                      ids: [
                        for (var p = 0; p < shopTourPanels[id]!.length; p++)
                          if (shopTourPanel(id, p) == panel) '$id.$p',
                      ],
                      child: Text('真內容 $id $panel'),
                    ),
                    const SizedBox(height: 700),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('舊進度保留語意，已完成頁不重跑，依新版重點數校正', () async {
    for (final entry in {
      'ShopAddonPage': 4,
      'ShopPolicyPage': 3,
      'DailyCareSettingPage': 4,
    }.entries) {
      SharedPreferences.setMockInitialValues({
        'shopFeatureTour:v1:u:s': jsonEncode({
          'current': entry.key,
          'point': 2,
          'understood': ['ShopDevicePage'],
          'completed': false,
        }),
      });
      final t = ShopFeatureTourController(uid: 'u', shopId: 's');
      await t.load();
      expect(t.point, entry.value);
      expect(t.understood, {'ShopDevicePage'});
      await t.persist();
      final copy = ShopFeatureTourController(uid: 'u', shopId: 's');
      await copy.load();
      expect(copy.point, entry.value);
      t.dispose();
      copy.dispose();
    }
    SharedPreferences.setMockInitialValues({
      'shopFeatureTour:v1:u:s': jsonEncode({
        'contentVersion': 2,
        'current': 'ShopPolicyPage',
        'point': 999,
        'completed': true,
      }),
    });
    final t = ShopFeatureTourController(uid: 'u', shopId: 's');
    await t.load();
    expect(t.point, 3);
    expect(t.completed, isTrue);
    expect(t.paused, isTrue);
    expect(shopTourTopics.map((t) => t.points.length), [
      3,
      4,
      4,
      5,
      7,
      4,
      4,
      4,
      5,
    ]);
    for (final topic in shopTourTopics) {
      expect(shopTourPanels[topic.id]!.length, topic.points.length);
    }
    t.dispose();
  });

  testWidgets('巢狀模組與隱藏重複 anchor：條款四點後回真選單，再進表單與回報', (tester) async {
    for (final width in [390.0, 1440.0]) {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(Size(width, 950));
      final t = ShopFeatureTourController(uid: 'u', shopId: 's');
      final nav = ShopDashboardNavigation(moduleId: 'catHotel');
      final hidden = GlobalKey();
      await t.load();
      t.configure({
        for (final id in [
          'ShopPolicyPage',
          'ShopCustomFormSettingsPage',
          'DailyCareSettingPage',
        ])
          id: true,
      });
      t.selectCat = () async => true;
      t.returnToMenu = () async {
        await nav.switchTo();
        return !nav.hasDetail;
      };
      TabController? modules;
      t.isPageVisible = (_) => modules?.index == 0;
      var mayLeave = false;
      Widget destination(String id) => ShopTourPage(
        id: id,
        shopId: 's',
        child: _TourTestPanels(id: id),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ShopFeatureTourHost(
            controller: t,
            child: DefaultTabController(
              length: 2,
              child: Builder(
                builder: (context) {
                  modules = DefaultTabController.of(context);
                  return TabBarView(
                    children: [
                      ShopDashboardContentNavigator(
                        navigation: nav,
                        child: Scaffold(
                          body: ListView(
                            children: [
                              for (final id in t.visible)
                                ShopTourAnchor(
                                  ids: ['entry:$id'],
                                  child: TextButton(
                                    onPressed: () => nav.switchTo(
                                      id: id,
                                      page: (_) => destination(id),
                                    ),
                                    child: Text('真入口 $id'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      _KeptTourTestChild(
                        child: ShopTourAnchor(
                          key: hidden,
                          ids: ['ShopPolicyPage.2', 'ShopPolicyPage.3'],
                          child: Text('表格統計的舊目標'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await t.start();
      await tester.pumpAndSettle();
      // Mount the neighboring module, then return; its kept-alive anchor must
      // never overwrite the target or pull the module horizontally.
      modules!.index = 1;
      await tester.pumpAndSettle();
      modules!.index = 0;
      await tester.pumpAndSettle();
      // Reproduce the old generic scroll primitive against a retained hidden
      // target: it is capable of moving the outer module, despite no tab tap.
      await Scrollable.ensureVisible(hidden.currentContext!);
      await tester.pumpAndSettle();
      expect(modules!.index, 1);
      modules!.index = 0;
      t.changed();
      await tester.pumpAndSettle();
      for (final id in t.visible) {
        await tester.tap(find.text('真入口 $id'));
        await tester.pumpAndSettle();
        expect(
          t.inPage,
          isTrue,
          reason:
              '$id / ${nav.selected} / module ${modules!.index} / ${t.current}',
        );
        final routeContext = tester.element(find.byType(_TourTestPanels));
        final route = ModalRoute.of(routeContext)!;
        Future<bool> guard() async => mayLeave;
        nav.bind(route, guard);
        for (var point = 0; point < t.pointCount; point++) {
          expect(modules!.index, 0);
          expect(find.text('目標尚未就緒或不在可見區域。可捲動定位，或暫停後重試本頁。'), findsNothing);
          if (point < t.pointCount - 1) {
            await t.next();
            await tester.pumpAndSettle();
          }
        }
        mayLeave = false;
        await t.next();
        await tester.pumpAndSettle();
        expect(t.understood.contains(id), isFalse);
        expect(nav.selected, id);
        mayLeave = true;
        await t.next();
        await tester.pumpAndSettle();
        nav.unbind(route, guard);
        expect(nav.hasDetail, isFalse);
        expect(modules!.index, 0);
        expect(t.understood.contains(id), isTrue);
      }
      expect(t.completed, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      t.dispose();
      nav.dispose();
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('錯頁可恢復同一重點，暫停後 guard 不得再切頁', (tester) async {
    final t = ShopFeatureTourController(uid: 'u', shopId: 's');
    final nav = ShopDashboardNavigation();
    await t.load();
    t.configure({'ShopPolicyPage': true});
    t.selectCat = () async => true;
    var visible = true;
    t.isPageVisible = (_) => visible;
    t.recoverPage = (_) async {
      visible = true;
      return true;
    };
    await tester.pumpWidget(
      MaterialApp(
        home: ShopFeatureTourHost(
          controller: t,
          child: ShopDashboardContentNavigator(
            navigation: nav,
            child: const Text('選單'),
          ),
        ),
      ),
    );
    await t.start();
    await nav.switchTo(
      id: 'ShopPolicyPage',
      page: (_) => const ShopTourPage(
        id: 'ShopPolicyPage',
        child: _TourTestPanels(id: 'ShopPolicyPage'),
      ),
    );
    await tester.pumpAndSettle();
    await t.next();
    await tester.pumpAndSettle();
    expect(t.point, 1);
    visible = false;
    t.changed();
    await tester.pumpAndSettle();
    expect(find.text('返回目前介紹頁／重新定位'), findsOneWidget);
    await tester.tap(find.text('返回目前介紹頁／重新定位'));
    await tester.pumpAndSettle();
    expect(t.point, 1);
    expect(t.understood, isEmpty);
    expect(find.text('目標尚未就緒或不在可見區域。可捲動定位，或暫停後重試本頁。'), findsNothing);
    final route = ModalRoute.of(tester.element(find.byType(_TourTestPanels)))!;
    final leave = Completer<bool>();
    Future<bool> guard() => leave.future;
    nav.bind(route, guard);
    final token = t.session;
    final switching = nav.switchTo(
      stillCurrent: () => t.active && token == t.session,
    );
    t.pause();
    leave.complete(true);
    await switching;
    await tester.pumpAndSettle();
    expect(nav.selected, 'ShopPolicyPage');
    expect(t.understood, isEmpty);
    nav.unbind(route, guard);
    await tester.pumpWidget(const SizedBox());
    t.dispose();
    nav.dispose();
  });

  testWidgets('暫停後忽略尚未完成的啟動與離開回呼', (tester) async {
    final t = ShopFeatureTourController(uid: 'u', shopId: 's');
    await t.load();
    t.configure({'ShopDevicePage': true});
    final qualification = Completer<bool>();
    var navigations = 0;
    t.canStart = () => qualification.future;
    t.selectCat = () async {
      navigations++;
      return true;
    };
    final starting = t.start();
    expect(t.busy, isTrue);
    t.pause();
    qualification.complete(true);
    await starting;
    expect(navigations, 0);
    expect(t.active, isFalse);
    expect(t.paused, isTrue);

    t.canStart = null;
    await t.start();
    t.point = t.pointCount - 1;
    final leaving = Completer<bool>();
    t.returnToMenu = () => leaving.future;
    await tester.pumpWidget(
      MaterialApp(
        home: ShopFeatureTourHost(
          controller: t,
          child: const ShopTourPage(
            id: 'ShopDevicePage',
            child: ShopTourAnchor(
              ids: ['ShopDevicePage.3'],
              child: Text('實際頁面的最後重點'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final finishing = t.next();
    expect(t.busy, isTrue);
    t.pause();
    leaving.complete(true);
    await finishing;
    expect(t.understood, isEmpty);
    expect(t.completed, isFalse);
    expect(t.current, 'ShopDevicePage');
    expect(t.point, 3);
    expect(t.paused, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    t.dispose();
  });

  testWidgets('收款七個重點切換正確三分頁，不點擊設定控制', (tester) async {
    final t = ShopFeatureTourController(uid: 'u', shopId: 'fixture');
    await t.load();
    t.configure({'ShopPaymentSettingPage': true});
    t.selectCat = () async => true;
    await t.start();
    await tester.pumpWidget(
      MaterialApp(
        home: ShopFeatureTourHost(
          controller: t,
          child: ShopPaymentSettingPage(
            shopId: 'fixture',
            showTaskCenterButton: false,
            tabPages: [
              for (var i = 0; i < 3; i++)
                ShopTourAnchor(
                  ids: [
                    for (var p = 0; p < 7; p++)
                      if (shopTourPanel('ShopPaymentSettingPage', p) == i)
                        'ShopPaymentSettingPage.$p',
                  ],
                  child: Center(child: Text('本機分頁 $i')),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var p = 0; p < t.pointCount; p++) {
      if (p > 0) {
        await t.next();
        await tester.pumpAndSettle();
      }
      final controller = DefaultTabController.of(
        tester.element(find.byType(ShopTourPage).first),
      );
      expect(controller.index, shopTourPanel('ShopPaymentSettingPage', p));
    }
    expect(t.understood, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    t.dispose();
  });

  testWidgets('每日照護五個重點切換真實三分頁，不儲存或啟用安親', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 950));
    final t = ShopFeatureTourController(uid: 'u', shopId: 'fixture');
    await t.load();
    t.configure({'DailyCareSettingPage': true});
    t.selectCat = () async => true;
    var writes = 0;
    await t.start();
    await tester.pumpWidget(
      MaterialApp(
        home: ShopFeatureTourHost(
          controller: t,
          child: DailyCareSettingPage(
            shopId: 'fixture',
            showTaskCenterButton: false,
            shopData: const {'daycareEnabled': false},
            initialSetting: const DailyCareSettingModel(enabled: false),
            initialDaycareSettings: DaycareSettingsModel.fromMap({
              'enabled': false,
            }),
            saveOverride:
                ({
                  required setting,
                  required expectedRevision,
                  required section,
                }) async {
                  writes++;
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var p = 0; p < t.pointCount; p++) {
      if (p > 0) {
        await t.next();
        await tester.pumpAndSettle();
      }
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack).first).index,
        shopTourPanel('DailyCareSettingPage', p),
      );
    }
    expect(writes, 0);
    expect(t.understood, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    t.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('九頁真入口與頁內閱讀、只讀遮罩、離開取消、手機桌機及本機接續', (tester) async {
    for (final width in [390.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      final t = ShopFeatureTourController(
        uid: 'owner',
        shopId: 'fixture-$width',
      );
      await t.load();
      t.configure({for (final topic in shopTourTopics) topic.id: true});
      final navigator = GlobalKey<NavigatorState>();
      var mayLeave = false, businessWrites = 0;
      final points = <String>[];
      t.selectCat = () async => true;
      t.returnToMenu = () async {
        if (!mayLeave) return false;
        navigator.currentState!.pop();
        return true;
      };
      await tester.pumpWidget(
        MaterialApp(
          home: ShopFeatureTourHost(
            controller: t,
            child: Navigator(
              key: navigator,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: ListView(
                    children: [
                      for (final topic in shopTourTopics)
                        ShopTourAnchor(
                          ids: ['entry:${topic.id}'],
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ShopTourPage(
                                  id: topic.id,
                                  onPoint: (point) async {
                                    points.add('${topic.id}.$point');
                                  },
                                  child: Scaffold(
                                    body: Align(
                                      alignment: Alignment.topCenter,
                                      child: ShopTourAnchor(
                                        ids: [
                                          for (
                                            var i = 0;
                                            i < topic.points.length;
                                            i++
                                          )
                                            '${topic.id}.$i',
                                        ],
                                        child: FilledButton(
                                          onPressed: () => businessWrites++,
                                          child: const Text('營運操作'),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            child: Text('入口 ${topic.name}'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.start();
      await tester.pumpAndSettle();
      await t.next(); // A menu impression alone cannot complete a page.
      expect(t.understood, isEmpty);
      for (final topic in shopTourTopics) {
        final entry = find.text('入口 ${topic.name}');
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(t.inPage, isTrue);
        await tester.tap(find.text('營運操作'), warnIfMissed: false);
        expect(businessWrites, 0);
        for (var p = 1; p < topic.points.length; p++) {
          await t.next();
          await tester.pumpAndSettle();
        }
        mayLeave = false;
        await tester.tap(find.text('了解，前往下一頁'));
        await tester.pumpAndSettle();
        expect(t.understood.contains(topic.id), isFalse);
        expect(t.current, topic.id);
        mayLeave = true;
        await tester.tap(find.text('了解，前往下一頁'));
        await tester.pumpAndSettle();
        expect(t.understood.contains(topic.id), isTrue);
      }
      expect(
        points.toSet().length,
        shopTourTopics.fold<int>(0, (n, t) => n + t.points.length),
      );
      expect(t.completed, isTrue);
      expect(find.text('後台功能導覽完成'), findsOneWidget);
      await tester.tap(find.text('開始使用後台'));
      await tester.pumpAndSettle();
      expect(find.text('後台功能導覽完成'), findsNothing);
      final restored = ShopFeatureTourController(
        uid: 'owner',
        shopId: 'fixture-$width',
      );
      await restored.load();
      expect(restored.understood.length, 9);
      expect(restored.paused, isTrue);
      final otherShop = ShopFeatureTourController(
        uid: 'owner',
        shopId: 'other',
      );
      await otherShop.load();
      expect(otherShop.understood, isEmpty);
      await t.start(restart: true);
      await tester.pumpAndSettle();
      expect(t.understood, isEmpty);
      await tester.tap(find.text('入口 ${shopTourTopics.first.name}'));
      await tester.pumpAndSettle();
      await t.next();
      await tester.pumpAndSettle();
      t.pause();
      await t.persist();
      await tester.pumpAndSettle();
      final pausedCopy = ShopFeatureTourController(
        uid: 'owner',
        shopId: 'fixture-$width',
      );
      await pausedCopy.load();
      expect(pausedCopy.current, shopTourTopics.first.id);
      expect(pausedCopy.point, 1);
      expect(pausedCopy.understood, isEmpty);
      expect(businessWrites, 0);
      pausedCopy.dispose();
      restored.dispose();
      otherShop.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      t.dispose();
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('權限名單、方案略過及未就緒資料不記為已了解', (tester) async {
    final t = ShopFeatureTourController(uid: 'u', shopId: 's');
    await t.load();
    t.configure({'ShopDevicePage': false, 'ShopCameraAccessPage': true});
    t.selectCat = () async => true;
    t.returnToMenu = () async => true;
    await t.start();
    expect(t.visible.length, 2);
    expect(t.participating.length, 1);
    expect(t.skipped['ShopAddonPage'], contains('權限'));
    expect(t.skipped['ShopDevicePage'], contains('方案'));
    await tester.pumpWidget(
      MaterialApp(
        home: ShopFeatureTourHost(
          controller: t,
          child: const ShopTourAnchor(
            ids: ['entry:ShopDevicePage'],
            child: Text('原有鎖定入口'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('了解限制，略過'));
    await tester.pumpAndSettle();
    expect(t.understood, isEmpty);
    expect(t.current, 'ShopCameraAccessPage');
    await tester.pumpWidget(
      MaterialApp(
        home: ShopFeatureTourHost(
          controller: t,
          child: const ShopTourPage(
            id: 'ShopCameraAccessPage',
            ready: false,
            error: 'offline',
            child: Text('讀取失敗'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await t.next();
    expect(t.point, 0);
    expect(t.understood, isEmpty);
    expect(find.text('資料讀取失敗，請暫停導覽後重試本頁。'), findsOneWidget);
    await tester.tap(find.text('暫停導覽'));
    await tester.pumpAndSettle();
    expect(t.paused, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    t.dispose();
  });
}
