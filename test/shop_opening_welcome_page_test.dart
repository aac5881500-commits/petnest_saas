import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/features/auth/pages/shop_opening_welcome_page.dart';
import 'package:petnest_saas/features/platform/pages/create_shop_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWelcome(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    Widget? heroIllustration,
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
        home: ShopOpeningWelcomePage(
          activationCode: 'KEEP-ME',
          heroIllustration: heroIllustration,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('歡迎畫面顯示開通文案，且不需要 Firebase', (WidgetTester tester) async {
    await pumpWelcome(tester);
    expect(find.text('PetNest 開店小幫手'), findsOneWidget);
    expect(find.text('準備開始'), findsOneWidget);
    expect(find.text('歡迎加入 PetNest！'), findsOneWidget);
    expect(find.text('一起打造貓咪們的第二個家 🐾'), findsOneWidget);
    expect(find.textContaining('從今天開始，讓我們陪你一步步建立專屬旅社。'), findsOneWidget);
    expect(find.text('「喵～準備好打造我們的新家了嗎？」'), findsOneWidget);
    expect(find.text('一步一步帶你完成'), findsOneWidget);
    expect(find.text('不用擔心做錯'), findsOneWidget);
    expect(find.text('其他設定之後再完成'), findsOneWidget);
    expect(find.text('開始打造我的旅社 →'), findsOneWidget);
    expect(find.text('先返回'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320、390、430 寬度不溢出', (WidgetTester tester) async {
    for (final double width in <double>[320, 390, 430]) {
      await pumpWelcome(tester, size: Size(width, 700));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('360 寬度與較大文字不溢出，提示直向排列', (WidgetTester tester) async {
    await pumpWelcome(tester, size: const Size(360, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    final Rect first = tester.getRect(find.text('一步一步帶你完成'));
    final Rect second = tester.getRect(find.text('不用擔心做錯'));
    expect(second.top, greaterThan(first.bottom - 4));
  });

  testWidgets('桌機寬度置中，三個提示橫向排列', (WidgetTester tester) async {
    await pumpWelcome(tester, size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    final Rect first = tester.getRect(find.text('一步一步帶你完成'));
    final Rect second = tester.getRect(find.text('不用擔心做錯'));
    final Rect page = tester.getRect(find.byType(ShopOpeningWelcomePage));
    expect((first.center.dx - page.center.dx).abs(), lessThan(420));
    expect(second.left, greaterThan(first.right));
    expect(second.top, closeTo(first.top, 2));
  });

  testWidgets('主視覺可換成日後的插畫', (WidgetTester tester) async {
    await pumpWelcome(
      tester,
      heroIllustration: const SizedBox(
        width: 120,
        height: 80,
        child: Text('未來插畫'),
      ),
    );
    expect(find.text('未來插畫'), findsOneWidget);
  });

  testWidgets('先返回回到上一頁', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PetNestAppTheme.build(),
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ShopOpeningWelcomePage(
                        activationCode: 'KEEP-ME',
                      ),
                    ),
                  );
                },
                child: const Text('驗證頁'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('驗證頁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('歡迎加入 PetNest！'), findsOneWidget);

    await tester.ensureVisible(find.text('先返回'));
    await tester.pump();
    await tester.tap(find.text('先返回'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('驗證頁'), findsOneWidget);
    expect(find.text('店家名稱'), findsNothing);
  });

  testWidgets('開始打造進入建立店家表單且不再顯示激活碼欄位', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: PetNestAppTheme.build(),
        home: const ShopOpeningWelcomePage(activationCode: 'KEEP-ME'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text('開始打造我的旅社 →'));
    await tester.pumpAndSettle();

    expect(find.text('建立店家'), findsWidgets);
    expect(find.text('店家名稱'), findsOneWidget);
    expect(find.text('創店激活碼'), findsNothing);
    expect(find.text('縣市'), findsOneWidget);
    expect(find.text('區域'), findsOneWidget);
    final CreateShopPage form = tester.widget<CreateShopPage>(
      find.byType(CreateShopPage),
    );
    expect(form.activationCode, 'KEEP-ME');

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('歡迎加入 PetNest！'), findsOneWidget);
  });
}
