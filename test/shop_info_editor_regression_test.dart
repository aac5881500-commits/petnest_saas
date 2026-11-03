import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_shop_info_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_preview_navigator.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_info_settings_panel.dart';

ModernShopFooter info(HomeShopInfoSetting setting) => ModernShopFooter(
  shopId: 'demo',
  shopName: '固定顯示店名',
  shop: const {
    'phone': '0912345678',
    'address': '店家地址',
    'description': '舊簡介',
    'businessHours': '10:00–20:00',
    'taxId': 'PRIVATE',
    'showTaxId': false,
  },
  primaryColor: Colors.orange,
  darkTextColor: Colors.brown,
  secondaryTextColor: Colors.grey,
  cardColor: Colors.white,
  borderColor: Colors.orangeAccent,
  setting: setting,
  isPreview: true,
);

void main() {
  test(
    'required information ignores old hide flags and preserves ordering and intro',
    () {
      final old = HomeShopInfoSetting.fromMap({
        'enabled': false,
        'showName': false,
        'showIntro': false,
        'showActions': false,
        'fields': ['phone', 'address'],
        'introText': '自訂店家簡介',
      });
      expect(
        old.enabled && old.showName && old.showIntro && old.showActions,
        true,
      );
      expect(const HomeShopInfoSetting(enabled: false).enabled, true);
      expect(old.orderedFields, [
        'phone',
        'address',
        'hours',
        'license',
        'tax',
      ]);
      for (final preset in shopInfoPresets) {
        final restored = HomeShopInfoSetting.fromMap(preset.apply(old).toMap());
        expect(restored.orderedFields, old.orderedFields);
        expect(restored.introText, '自訂店家簡介');
        expect(
          restored.enabled &&
              restored.showName &&
              restored.showIntro &&
              restored.showActions,
          true,
        );
      }
    },
  );
  for (final mode in ['pull', 'compact']) {
    testWidgets(
      '$mode sheet and barrier stay in preview and leave editor usable',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int edits = 0;
        final footer = info(
          HomeShopInfoSetting(
            mode: mode,
            introText: '即時自訂簡介',
            layout: 'photoDetails',
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    key: const ValueKey('preview-boundary'),
                    width: 390,
                    height: 600,
                    child: HomePreviewNavigator(
                      child: Builder(
                        builder: (ctx) => Scaffold(
                          body: const Text('手機即時預覽'),
                          bottomNavigationBar: footer.buildDock(
                            ctx,
                            pull: mode == 'pull',
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => edits++,
                    child: const Text('右側編輯不應被遮住'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.text(mode == 'pull' ? '店家資訊' : '固定顯示店名'));
        await tester.pumpAndSettle();
        final frame = tester.getRect(
          find.byKey(const ValueKey('preview-boundary')),
        );
        final barrier = tester.getRect(find.byType(ModalBarrier).last);
        expect(barrier.left, greaterThanOrEqualTo(frame.left));
        expect(barrier.right, lessThanOrEqualTo(frame.right));
        expect(barrier.bottom, lessThanOrEqualTo(frame.bottom));
        expect(find.text('即時自訂簡介'), findsOneWidget);
        expect(find.textContaining('PRIVATE'), findsNothing);
        await tester.tap(find.text('右側編輯不應被遮住'));
        await tester.pump();
        expect(edits, 1);
        expect(find.byTooltip('關閉店家資訊'), findsOneWidget);
        await tester.tap(find.byTooltip('關閉店家資訊'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('關閉店家資訊'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'owner editor can expand, type, change presets and reopen without element failures',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var setting = const HomeShopInfoSetting();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              child: StatefulBuilder(
                builder: (context, setState) => ShopInfoSettingsPanel(
                  setting: setting,
                  defaultIntro: '原本的店家簡介',
                  onChanged: (next) => setState(() => setting = next),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.byType(SwitchListTile),
        findsNothing,
      ); // only optional follow-theme inside collapsed advanced section
      for (var i = 0; i < 4; i++) {
        final group = find.text('聯絡按鈕與標題（選填）');
        await tester.scrollUntilVisible(
          group,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(group);
        await tester.pumpAndSettle();
        final title = find.byKey(const ValueKey('footer-section-title'));
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        await tester.enterText(title, '店家資訊$i');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          group,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(group);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final card = find.text(shopInfoPresets[i + 1].label);
        await tester.scrollUntilVisible(
          card,
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(setting.preset, shopInfoPresets[i + 1].id);
        expect(setting.sectionTitle, '店家資訊$i');
        expect(tester.takeException(), isNull);
      }
      final intro = find.byKey(const ValueKey('shop-info-introduction'));
      await tester.scrollUntilVisible(
        intro,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(intro, '從這裡輸入新的店家簡介');
      await tester.pumpAndSettle();
      expect(setting.introText, '從這裡輸入新的店家簡介');
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('顯示店家資訊'), findsNothing);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(5));
      final phoneHandle = find.byType(ReorderableDragStartListener).at(2);
      await tester.ensureVisible(phoneHandle);
      await tester.pumpAndSettle();
      await tester.drag(phoneHandle, const Offset(0, -125));
      await tester.pumpAndSettle();
      expect(setting.orderedFields.indexOf('phone'), lessThan(2));
      expect(tester.takeException(), isNull);
    },
  );
}
