import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_shop_info_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_info_settings_panel.dart';

ModernShopFooter footer(HomeShopInfoSetting setting) => ModernShopFooter(
  shopId: '',
  shopName: '貓咪旅店很長的店家名稱',
  shop: const {
    'phone': '02-12345678',
    'city': '台北市',
    'district': '大安區',
    'address': '長地址街道巷弄與樓層資訊',
    'businessHours': '週一至週日 10:00–19:00，採預約制',
    'description': '給貓咪一個安心的小窩',
    'licenseNumber': '測試字號',
    'taxId': '87654321',
    'showTaxId': false,
    'lineUrl': 'https://line.me/example',
  },
  primaryColor: Colors.orange,
  darkTextColor: Colors.black87,
  secondaryTextColor: Colors.black54,
  cardColor: Colors.white,
  borderColor: Colors.black12,
  isPreview: true,
  setting: setting,
);

void main() {
  test(
    'legacy placement follows original navigation and explicit modes are independent',
    () {
      final legacy = HomeShopInfoSetting.fromMap(null);
      expect(legacy.resolvedMode(false), 'pull');
      expect(legacy.resolvedMode(true), 'scrollCollapsed');
      for (final mode in HomeShopInfoSetting.modes.keys.where(
        (m) => m != 'auto',
      )) {
        final s = legacy.copyWith(mode: mode);
        expect(s.resolvedMode(false), s.resolvedMode(true));
        expect(s.isFixed(false), ['pull', 'compact'].contains(mode));
      }
      expect(legacy.copyWith(enabled: false).isFixed(false), isFalse);
    },
  );

  test(
    'appearance roundtrip retains order and handles malformed data safely',
    () {
      final selected = const HomeShopInfoSetting().copyWith(
        mode: 'scroll',
        imageSource: 'none',
        layout: 'plain',
        preset: 'boutique',
        followTheme: false,
        fields: ['address', 'hours'],
        showActions: false,
        radius: 8,
      );
      final restored = HomeShopInfoSetting.fromShop({
        'homeAppearance': {
          'modern': {'shopInfo': selected.toMap()},
        },
      });
      expect(restored.toMap(), selected.toMap());
      final bad = HomeShopInfoSetting.fromMap({
        'mode': 'unknown',
        'layout': 'unknown',
        'imageUrl': 'javascript:alert(1)',
        'radius': 900,
        'fields': ['phone', 'unknown', 'phone'],
      });
      expect(bad.mode, 'auto');
      expect(bad.imageUrl, isEmpty);
      expect(bad.radius, 32);
      expect(bad.fields, ['phone']);
      expect(
        HomeShopInfoSetting.fromMap({'fields': <String>[]}).fields,
        isEmpty,
      );
    },
  );

  testWidgets(
    'all ten presets fit narrow large text and preserve tax visibility',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final p in shopInfoPresets) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  ModernShopInfoPanel(
                    alwaysExpanded: true,
                    footer: footer(
                      HomeShopInfoSetting(
                        preset: p.id,
                        followTheme: false,
                        layout: p.layout,
                        imageSource: 'none',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('貓咪旅店很長的店家名稱'), findsOneWidget, reason: p.id);
        expect(find.textContaining('統一編號'), findsNothing, reason: p.id);
        expect(tester.takeException(), isNull, reason: p.id);
      }
    },
  );

  testWidgets(
    'fixed dock sits above either navigation without duplicating the scroll footer',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final bottomNav in [false, true]) {
        for (final mode in ['pull', 'compact', 'scroll', 'scrollCollapsed']) {
          final s = HomeShopInfoSetting(mode: mode);
          final f = footer(s);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  bottomNavigationBar: buildShopInfoBottomArea(
                    context: context,
                    footer: f,
                    useBottomBar: bottomNav,
                    navigationBar: bottomNav
                        ? const SizedBox(height: 64, child: Text('測試底部選單'))
                        : null,
                  ),
                  body: ListView(
                    children: [
                      const SizedBox(height: 50),
                      if (!s.isFixed(bottomNav))
                        ModernShopInfoPanel(
                          footer: f,
                          alwaysExpanded: mode == 'scroll',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byType(ModernShopInfoPanel),
            s.isFixed(bottomNav) ? findsNothing : findsOneWidget,
          );
          if (bottomNav && s.isFixed(bottomNav)) {
            expect(
              tester.getBottomLeft(find.byType(ListView)).dy,
              lessThanOrEqualTo(
                tester
                    .getTopLeft(
                      find
                          .text(mode == 'compact' ? '貓咪旅店很長的店家名稱' : '店家資訊')
                          .first,
                    )
                    .dy,
              ),
            );
          }
          if (mode == 'pull') {
            await tester.fling(find.text('店家資訊'), const Offset(0, -160), 600);
            await tester.pumpAndSettle();
            expect(find.text('關閉店家資訊'), findsNothing);
            expect(find.byTooltip('關閉店家資訊'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'hidden fields and actions are omitted and field order is respected',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ModernShopInfoPanel(
                  alwaysExpanded: true,
                  footer: footer(
                    const HomeShopInfoSetting(
                      imageSource: 'none',
                      showName: false,
                      showIntro: false,
                      showActions: false,
                      fields: ['address', 'hours'],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('貓咪旅店很長的店家名稱'), findsNothing);
      expect(find.text('撥打電話'), findsNothing);
      expect(find.text('聯絡電話'), findsNothing);
      expect(
        tester.getTopLeft(find.text('地址')).dy,
        lessThan(tester.getTopLeft(find.text('營業時間')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings change placement and imagery without changing each other',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var s = const HomeShopInfoSetting();
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: ShopInfoSettingsPanel(
                setting: s,
                onChanged: (v) => setState(() => s = v),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('固定底部・精簡資訊列'));
      await tester.pumpAndSettle();
      expect(s.mode, 'compact');
      await tester.scrollUntilVisible(
        find.text('A2 日系森林'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A2 日系森林'));
      await tester.pumpAndSettle();
      expect(s.preset, 'forest');
      expect(s.mode, 'compact');
      await tester.scrollUntilVisible(
        find.text('不放圖片'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('不放圖片'));
      await tester.pumpAndSettle();
      expect(s.imageSource, 'none');
      expect(s.mode, 'compact');
      expect(tester.takeException(), isNull);
    },
  );
}
