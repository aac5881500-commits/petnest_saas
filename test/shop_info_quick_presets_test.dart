import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_shop_info_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';

ModernShopFooter footer(HomeShopInfoSetting s) => ModernShopFooter(
  shopId: 'owner-specific',
  shopName: '客戶自己設定的貓咪旅館',
  shop: const {
    'businessHours': '10:00–20:00',
    'city': '新竹縣',
    'district': '竹北市',
    'address': '客戶自己的長地址123號五樓',
    'phone': '0912345678',
    'description': '由客戶自行填寫的店家介紹',
    'showTaxId': false,
    'taxId': 'PRIVATE',
  },
  primaryColor: Colors.orange,
  darkTextColor: Colors.brown,
  secondaryTextColor: Colors.grey,
  cardColor: Colors.white,
  borderColor: Colors.orangeAccent,
  setting: s,
  isPreview: true,
);

void main() {
  test(
    'all ten recipes are complete and preserve owner content and display mode',
    () {
      expect(shopInfoPresets.length, 10);
      expect(shopInfoPresets.map((p) => p.id).toSet().length, 10);
      for (final preset in shopInfoPresets) {
        for (final mode in HomeShopInfoSetting.modes.keys) {
          final original = HomeShopInfoSetting(
            mode: mode,
            imageUrl: 'https://owner.example/photo.jpg',
            phoneLabel: '聯絡我們',
            sectionTitle: '來店資訊',
            actionIds: const ['facebook'],
            buttonStyle: 'text',
            layout: 'plain',
            fields: const ['tax'],
          );
          final next = HomeShopInfoSetting.fromMap(
            preset.apply(original).toMap(),
          );
          expect(next.mode, mode, reason: preset.id);
          expect(next.imageUrl, original.imageUrl);
          expect(next.phoneLabel, original.phoneLabel);
          expect(next.sectionTitle, original.sectionTitle);
          expect(next.layout, preset.layout);
          expect(next.actionPresentation, preset.presentation);
          expect(next.buttonStyle, preset.buttonStyle);
          expect(next.photoShape, preset.photoShape);
          expect(next.actionIds, ['phone', 'map', 'line']);
          expect(next.orderedFields, [
            'tax',
            'hours',
            'address',
            'phone',
            'license',
          ]);
          expect(next.followTheme, false);
          expect(next.isFixed(true), mode == 'pull' || mode == 'compact');
          expect(next.toMap().toString(), isNot(contains('template_previews')));
        }
      }
    },
  );
  for (final preset in shopInfoPresets) {
    testWidgets(
      '${preset.id} complete footer fits phone and desktop without sample content',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final width in [320.0, 390.0, 430.0, 1100.0]) {
          final s = preset.apply(const HomeShopInfoSetting(mode: 'scroll'));
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: ModernShopInfoPanel(
                        footer: footer(s),
                        alwaysExpanded: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${preset.id} at $width',
          );
          expect(find.textContaining('客戶自己的長地址123號五樓'), findsWidgets);
          expect(find.textContaining('PRIVATE'), findsNothing);
        }
      },
    );
    testWidgets(
      '${preset.id} keeps original pull dock and opens complete selected footer',
      (tester) async {
        final f = footer(preset.apply(const HomeShopInfoSetting(mode: 'pull')));
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: const Center(child: Text('首頁內容')),
                bottomNavigationBar: buildShopInfoBottomArea(
                  context: context,
                  footer: f,
                  useBottomBar: true,
                  navigationBar: const SizedBox(
                    height: 56,
                    child: Text('原本導覽'),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('原本導覽'), findsOneWidget);
        await tester.fling(find.text('店家資訊'), const Offset(0, -120), 500);
        await tester.pumpAndSettle();
        expect(find.byTooltip('關閉店家資訊'), findsOneWidget);
        expect(find.textContaining('客戶自己的長地址123號五樓'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('關閉店家資訊'));
        await tester.pumpAndSettle();
      },
    );
  }
}
