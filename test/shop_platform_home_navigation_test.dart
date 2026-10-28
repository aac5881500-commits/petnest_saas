import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
import 'package:petnest_saas/features/shop/widgets/shop_platform_home_button.dart';

class _Shop extends StatefulWidget {
  const _Shop();
  @override
  State<_Shop> createState() => _ShopState();
}

class _ShopState extends State<_Shop> {
  final navigation = ShopDashboardNavigation();
  @override
  void dispose() {
    navigation.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (await navigation.confirmLeave() && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) => ShopDashboardNavigationScope(
    navigation: navigation,
    desktop: true,
    openEntry: (_) async {},
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('店家後台'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ShopDashboardContentNavigator(
              navigation: navigation,
              child: Center(
                child: FilledButton(
                  onPressed: () => navigation.switchTo(
                    id: 'edit',
                    page: (_) => const _Editor(),
                  ),
                  child: const Text('編輯項目'),
                ),
              ),
            ),
          ),
          ShopPlatformHomeButton(onPressed: leave),
        ],
      ),
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor();
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor>
    with ShopDashboardLeaveAware<_Editor> {
  @override
  bool get dashboardHasUnsavedChanges => true;
  @override
  bool get dashboardIsBusy => false;
  @override
  Widget build(BuildContext context) => dashboardGuard(
    Scaffold(
      appBar: AppBar(title: const Text('未儲存項目')),
      body: const Text('編輯中的內容'),
    ),
  );
}

Future<void> enterShop(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const Text('平台首頁'),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const _Shop()),
                ),
                child: const Text('進入店家'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('進入店家'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'explicit home button exits the shop without a misleading app-bar back arrow',
    (tester) async {
      await enterShop(tester);
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.text('回平台首頁'));
      await tester.pumpAndSettle();
      expect(find.text('平台首頁'), findsOneWidget);
      expect(find.text('店家後台'), findsNothing);
    },
  );
  testWidgets('platform home respects unfinished editor confirmation', (
    tester,
  ) async {
    await enterShop(tester);
    await tester.tap(find.text('編輯項目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回平台首頁'));
    await tester.pumpAndSettle();
    expect(find.text('尚未儲存'), findsOneWidget);
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(find.text('未儲存項目'), findsOneWidget);
    await tester.tap(find.text('回平台首頁'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄變更並離開'));
    await tester.pumpAndSettle();
    expect(find.text('平台首頁'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact home control names its destination', (tester) async {
    var activated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: ShopPlatformHomeButton(
              compact: true,
              onPressed: () => activated = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('回平台首頁'));
    expect(activated, isTrue);
  });
}
