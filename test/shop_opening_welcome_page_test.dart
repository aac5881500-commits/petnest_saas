// 檔案名稱：test/shop_opening_welcome_page_test.dart
// 功能說明：正式圖片、響應式排版及既有開店導航的行為測試。
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/features/auth/pages/shop_opening_welcome_page.dart';
import 'package:petnest_saas/features/platform/pages/create_shop_page.dart';

const _start = ValueKey('welcome-start');
const _back = ValueKey('welcome-back');
const _headline = '一起開啟\n你的寵物旅宿事業';

class _RouteObserver extends NavigatorObserver {
  int formPushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) formPushes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWelcome(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    String code = 'KEEP-ME',
    Widget? illustration,
    NavigatorObserver? observer,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: PetNestAppTheme.build(),
        navigatorObservers: [?observer],
        home: ShopOpeningWelcomePage(
          activationCode: code,
          heroIllustration: illustration,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('正式 WebP 資產可讀取及解碼', (tester) async {
    for (final name in ['desktop', 'mobile']) {
      final data = await rootBundle.load(
        'assets/images/shop_onboarding/welcome_$name.webp',
      );
      expect(data.lengthInBytes, greaterThan(10000));
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThanOrEqualTo(1000));
        if (name == 'desktop') {
          expect(frame.image.width, greaterThan(frame.image.height));
        } else {
          expect(frame.image.height, greaterThan(frame.image.width));
        }
        frame.image.dispose();
        codec.dispose();
      });
    }
  });

  testWidgets('歡迎頁不需 Firebase、不再要求輸入激活碼', (tester) async {
    await pumpWelcome(tester);
    expect(find.text(_headline), findsOneWidget);
    expect(find.text('簡單設定・快速開店・專屬你的品牌'), findsOneWidget);
    expect(find.text('1. 激活碼驗證完成'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [
    320.0,
    390.0,
    430.0,
    768.0,
    900.0,
    1280.0,
    1440.0,
    1920.0,
  ]) {
    testWidgets('$width 寬度無溢出且主按鈕可操作', (tester) async {
      await pumpWelcome(tester, size: Size(width, 844));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(_start));
      await tester.pumpAndSettle();
      expect(find.byKey(_start).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('手機直排／桌機橫排，使用對應本機照片', (tester) async {
    for (final width in [390.0, 1440.0]) {
      await pumpWelcome(tester, size: Size(width, 1000));
      final first = tester.getRect(find.text('1. 激活碼驗證完成'));
      final second = tester.getRect(find.text('2. 完善店家資料'));
      final photo = tester.widget<Image>(
        find.byKey(const ValueKey('welcome-photo')),
      );
      final desktop = width >= 900;
      expect(
        (photo.image as AssetImage).assetName,
        endsWith(desktop ? 'welcome_desktop.webp' : 'welcome_mobile.webp'),
      );
      if (desktop) {
        expect(second.left, greaterThan(first.right));
        expect(second.top, closeTo(first.top, 1));
        expect(find.text('專為寵物旅宿設計'), findsOneWidget);
      } else {
        expect(second.top, greaterThan(first.bottom));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('窄手機與桌機 2 倍文字仍可捲動操作', (tester) async {
    for (final size in [const Size(320, 640), const Size(1440, 900)]) {
      await pumpWelcome(tester, size: size, textScale: 2);
      expect(find.byKey(const ValueKey('vertical-steps')), findsOneWidget);
      await tester.ensureVisible(find.byKey(_start));
      await tester.pumpAndSettle();
      expect(find.byKey(_start).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('SafeArea 避開手機頂部與底部系統區域', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.resetPadding);
    await pumpWelcome(tester);
    expect(tester.getRect(find.byKey(_back)).top, greaterThanOrEqualTo(44));
    await tester.ensureVisible(find.byKey(_start));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(_start)).bottom,
      lessThanOrEqualTo(844 - 34),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('保留既有可注入主視覺的介面', (tester) async {
    await pumpWelcome(
      tester,
      illustration: const ColoredBox(
        key: ValueKey('custom-hero'),
        color: Colors.amber,
      ),
    );
    expect(find.byKey(const ValueKey('custom-hero')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('減少動態效果時立即顯示主視覺', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const ShopOpeningWelcomePage(activationCode: 'KEEP-ME'),
        ),
      ),
    );
    final fade = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(ShopOpeningWelcomePage),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  Future<void> openFromPrevious(
    WidgetTester tester, {
    String code = 'KEEP-ME',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PetNestAppTheme.build(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('驗證成功頁'),
              onPressed: () async {
                final result = await Navigator.of(context).push<ShopCreateExit>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ShopOpeningWelcomePage(activationCode: code),
                  ),
                );
                if (context.mounted && result != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('結果：${result.name}')));
                }
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('驗證成功頁'));
    await tester.pumpAndSettle();
  }

  testWidgets('返回回到上一頁，不建立店家', (tester) async {
    await openFromPrevious(tester);
    await tester.tap(find.byKey(_back));
    await tester.pumpAndSettle();
    expect(find.text('驗證成功頁'), findsOneWidget);
    expect(find.byType(CreateShopPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('激活碼傳入原建立頁，連點不重複開啟，返回後可繼續', (tester) async {
    final observer = _RouteObserver();
    await pumpWelcome(tester, code: '  KEEP-ME  ', observer: observer);
    await tester.ensureVisible(find.byKey(_start));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_start));
    await tester.tap(find.byKey(_start), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(observer.formPushes, 1);
    final form = tester.widget<CreateShopPage>(find.byType(CreateShopPage));
    expect(form.activationCode, 'KEEP-ME');
    expect(find.text('你的旅社叫什麼名字？'), findsOneWidget);
    expect(find.text('創店激活碼'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('create-shop-back')));
    await tester.pumpAndSettle();
    expect(find.text(_headline), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(_start)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final result in ShopCreateExit.values) {
    testWidgets('建立結果 ${result.name} 會回傳前一步', (tester) async {
      await openFromPrevious(tester);
      await tester.ensureVisible(find.byKey(_start));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_start));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(CreateShopPage))).pop(result);
      await tester.pumpAndSettle();
      expect(find.byType(ShopOpeningWelcomePage), findsNothing);
      expect(find.text('結果：${result.name}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('空激活碼返回要求重新驗證', (tester) async {
    await openFromPrevious(tester, code: '  ');
    await tester.ensureVisible(find.byKey(_start));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_start));
    await tester.pumpAndSettle();
    expect(find.byType(CreateShopPage), findsNothing);
    expect(find.text('結果：recheckActivation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
