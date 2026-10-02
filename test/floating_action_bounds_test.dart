import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/floating_action_bounds.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_bottom_navigation.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_menu_button.dart';

void main() {
  const Size screen = Size(390, 800);
  const Size button = Size.square(48);

  FloatingActionBounds boundsFor(String appearance, {double safeBottom = 0}) {
    return FloatingActionBounds.resolve(
      size: screen,
      padding: EdgeInsets.only(bottom: safeBottom),
      headerHeight: 0,
      showBottomBar: true,
      bottomBarHeight: ModernBottomNavigation.slotHeight(appearance, safeBottom),
      buttonSize: button,
    );
  }

  test('三種底部導覽各自用實際高度計算上限', () {
    final FloatingActionBounds attached = boundsFor(
      FrontendNavigationConfig.appearanceAttached,
    );
    final FloatingActionBounds pill = boundsFor(
      FrontendNavigationConfig.appearanceFloatingPill,
    );
    final FloatingActionBounds minimal = boundsFor(
      FrontendNavigationConfig.appearanceFloatingMinimal,
    );
    expect(attached.maxY, 800 - 62 - 12 - 48);
    expect(pill.maxY, 800 - (64 + 12) - 12 - 48);
    expect(minimal.maxY, 800 - (54 + 12) - 12 - 48);
    expect(pill.maxY, isNot(attached.maxY));
    expect(minimal.maxY, isNot(attached.maxY));
  });

  test('沒有底部導覽時避開 SafeArea', () {
    final FloatingActionBounds bounds = FloatingActionBounds.resolve(
      size: screen,
      padding: const EdgeInsets.only(bottom: 34, top: 47),
      headerHeight: 0,
      showBottomBar: false,
      bottomBarHeight: 0,
      buttonSize: button,
    );
    expect(bounds.minY, 47 + 12);
    expect(bounds.maxY, 800 - 34 - 16 - 48);
    expect(bounds.minX, 12);
    expect(bounds.maxX, 390 - 48 - 12);
  });

  test('超出範圍會被夾回畫面內，已在邊緣的點放開後不位移', () {
    final FloatingActionBounds bounds = boundsFor(
      FrontendNavigationConfig.appearanceAttached,
      safeBottom: 20,
    );
    final Offset outside = bounds.clampPoint(const Offset(-80, 2000));
    expect(outside.dx, bounds.minX);
    expect(outside.dy, bounds.maxY);
    final Offset edge = Offset(bounds.minX, bounds.maxY);
    expect(bounds.clampPoint(edge), edge);
    expect(
      bounds.placeOnRelease(edge, button, preferLeft: true),
      edge,
    );
  });

  test('兩顆按鈕碰撞時分別留在左右並保持間距', () {
    final FloatingActionBounds bounds = boundsFor(
      FrontendNavigationConfig.appearanceFloatingPill,
    );
    final Offset menu = bounds.placeOnRelease(
      Offset(bounds.maxX, bounds.maxY),
      button,
      preferLeft: true,
      peer: Rect.fromLTWH(bounds.maxX, bounds.maxY, 52, 52),
    );
    final Offset contact = bounds.placeOnRelease(
      Offset(bounds.minX, bounds.maxY),
      const Size.square(52),
      preferLeft: false,
      peer: Rect.fromLTWH(menu.dx, menu.dy, 48, 48),
    );
    final Rect menuRect = Rect.fromLTWH(menu.dx, menu.dy, 48, 48);
    final Rect contactRect = Rect.fromLTWH(contact.dx, contact.dy, 52, 52);
    expect(menuRect.overlaps(contactRect.inflate(12)), isFalse);
    expect(menu.dx, bounds.minX);
    expect(contact.dx, bounds.maxX);
    expect(menu.dy, inInclusiveRange(bounds.minY, bounds.maxY));
    expect(contact.dy, inInclusiveRange(bounds.minY, bounds.maxY));
  });

  test('正規化座標在尺寸改變後仍落在新範圍內', () {
    final FloatingActionBounds wide = boundsFor(
      FrontendNavigationConfig.appearanceAttached,
    );
    final double nx = wide.normX(wide.maxX);
    final double ny = wide.normY(wide.minY);
    final FloatingActionBounds narrow = FloatingActionBounds.resolve(
      size: const Size(320, 640),
      padding: EdgeInsets.zero,
      headerHeight: 0,
      showBottomBar: true,
      bottomBarHeight: ModernBottomNavigation.slotHeight(
        FrontendNavigationConfig.appearanceFloatingMinimal,
        28,
      ),
      buttonSize: button,
    );
    final Offset again = Offset(narrow.denormX(nx), narrow.denormY(ny));
    expect(again.dx, inInclusiveRange(narrow.minX, narrow.maxX));
    expect(again.dy, inInclusiveRange(narrow.minY, narrow.maxY));
    expect(
      ShopMenuPositionStore.keyFor('shop-a', 'user-b'),
      'frontend_shop_menu_pos_shop-a_user-b',
    );
  });

  testWidgets('店家選單預設貼在底欄上方左側', (WidgetTester tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const double bar = 62;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopMenuButton(
            shopId: 'shop-1',
            userId: 'user-1',
            shopName: '測試店家',
            logoUrl: '',
            theme: HomeThemeModel.modernDefault,
            surface: FrontendNavigationConfig.surfaceOpaque,
            bottomBarHeight: bar,
            visible: true,
            persistPosition: false,
            allowNavigation: false,
            onPlatform: _noop,
            onAdmin: _noop,
          ),
        ),
      ),
    );
    final Rect rect = tester.getRect(find.byTooltip('店家選單'));
    expect(rect.left, 12);
    expect(rect.right, lessThanOrEqualTo(screen.width - 12));
    expect(rect.bottom, lessThanOrEqualTo(screen.height - bar - 12));
    expect(rect.top, greaterThanOrEqualTo(12));
  });

  testWidgets('拖曳時跟著手指，放開後垂直位置不跳動', (WidgetTester tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopMenuButton(
            shopId: 'shop-1',
            userId: 'user-1',
            shopName: '測試店家',
            logoUrl: '',
            theme: HomeThemeModel.modernDefault,
            surface: FrontendNavigationConfig.surfaceOpaque,
            bottomBarHeight: 62,
            visible: true,
            persistPosition: false,
            allowNavigation: false,
            onPlatform: _noop,
            onAdmin: _noop,
          ),
        ),
      ),
    );
    final Finder button = find.byTooltip('店家選單');
    final Rect start = tester.getRect(button);
    final TestGesture gesture = await tester.startGesture(start.center);
    await gesture.moveBy(const Offset(36, -80));
    await tester.pump();
    final Rect moved = tester.getRect(button);
    expect(moved.left, closeTo(start.left + 36, 0.5));
    expect(moved.top, closeTo(start.top - 80, 0.5));
    await gesture.up();
    await tester.pump();
    final Rect released = tester.getRect(button);
    expect(released.top, closeTo(moved.top, 0.5));
    expect(released.left, greaterThanOrEqualTo(12));
    expect(released.right, lessThanOrEqualTo(screen.width - 12));
    expect(released.bottom, lessThanOrEqualTo(screen.height - 62 - 12));
  });
}

void _noop() {}
