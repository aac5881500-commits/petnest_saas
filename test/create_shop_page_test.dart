// 檔案名稱：test/create_shop_page_test.dart
// 功能說明：建立旅社頁的排版、欄位連動與既有驗證，不呼叫 Firebase。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/platform/pages/create_shop_page.dart';
import 'package:petnest_saas/features/platform/widgets/create_shop_opening_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    String code = 'KEEP-ME',
    Widget? home,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: home ?? CreateShopPage(activationCode: code)),
    );
    await tester.pump();
  }

  Future<void> scrollToSubmit(WidgetTester tester) async {
    final scrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-shop-submit')),
      300,
      scrollable: scrollable,
    );
  }

  testWidgets('各寬度不溢出，桌機才出現雙欄', (tester) async {
    const sizes = <Size>[
      Size(320, 700),
      Size(375, 812),
      Size(390, 844),
      Size(430, 932),
      Size(768, 1024),
      Size(1024, 768),
      Size(1440, 900),
      Size(1920, 1080),
    ];
    for (final size in sizes) {
      await pumpPage(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('幫你的旅社取個名字吧！'), findsWidgets);
      await scrollToSubmit(tester);
      expect(find.text('建立我的旅社 →'), findsOneWidget);
      final desktop = size.width >= 1024;
      expect(
        find.text('幫你的旅社\n取個名字吧'),
        desktop ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('有效激活碼只顯示完成提示，不顯示完整激活碼', (tester) async {
    await pumpPage(tester, size: const Size(390, 844), code: 'SECRET-CODE');
    final scrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('激活碼已驗證完成'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('激活碼已驗證完成'), findsOneWidget);
    expect(find.text('SECRET-CODE'), findsNothing);
    expect(find.text('不需要再次輸入，建立後即可開始設定旅社。'), findsOneWidget);
  });

  testWidgets('沒有激活碼時不假裝驗證成功', (tester) async {
    await pumpPage(tester, size: const Size(390, 844), code: '   ');
    expect(find.text('激活碼已驗證完成'), findsNothing);
    expect(find.byKey(const ValueKey('create-shop-code-ready')), findsNothing);
  });

  testWidgets('店名、縣市與區域連動，並保留必填提示', (tester) async {
    await pumpPage(tester, size: const Size(390, 844));
    final district = tester.widget<DropdownButtonFormField<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.key == const ValueKey('create-shop-district-'),
      ),
    );
    expect(district.onChanged, isNull);

    await scrollToSubmit(tester);
    await tester.tap(find.byKey(const ValueKey('create-shop-submit')));
    await tester.pump();
    expect(find.text('請輸入店名'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('create-shop-name')),
      '喵星人貓咪旅館',
    );
    await scrollToSubmit(tester);
    await tester.tap(find.byKey(const ValueKey('create-shop-submit')));
    await tester.pump();
    expect(find.text('請選擇城市'), findsOneWidget);

    final scrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('create-shop-city')),
      200,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey('create-shop-city')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('台北市').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.key == const ValueKey('create-shop-district-台北市'),
      ),
      200,
      scrollable: scrollable,
    );
    final enabled = tester.widget<DropdownButtonFormField<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.key == const ValueKey('create-shop-district-台北市'),
      ),
    );
    expect(enabled.onChanged, isNotNull);

    await scrollToSubmit(tester);
    await tester.tap(find.byKey(const ValueKey('create-shop-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('請選擇區域'), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.key == const ValueKey('create-shop-district-台北市'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('大安區').last);
    await tester.pumpAndSettle();
    expect(find.text('大安區'), findsWidgets);
  });

  testWidgets('返回上一頁', (tester) async {
    await pumpPage(
      tester,
      size: const Size(390, 844),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const CreateShopPage(activationCode: 'KEEP-ME'),
                ),
              );
            },
            child: const Text('前往建立'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('前往建立'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-shop-back')));
    await tester.pumpAndSettle();
    expect(find.text('前往建立'), findsOneWidget);
    expect(find.byType(CreateShopPage), findsNothing);
  });

  testWidgets('提交中停用按鈕，避免重複建立', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final name = TextEditingController();
    addTearDown(name.dispose);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateShopOpeningView(
          nameController: name,
          city: '',
          district: '',
          cities: const ['台北市'],
          districts: const [],
          onCityChanged: (_) {},
          onDistrictChanged: (_) {},
          loading: true,
          activationReady: true,
          onSubmit: () => taps++,
          onBack: () {},
        ),
      ),
    );
    expect(find.text('建立中...'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('create-shop-submit')),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('create-shop-submit')));
    await tester.pump();
    expect(taps, 0);
  });
}
