// 功能說明：外觀草稿空內容可預覽，正式前台仍隱藏，且不觸發導頁。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_about_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_faq_section.dart';

void main() {
  testWidgets('空關於我們三種版型可預覽，手動文案立即更新，正式頁不顯示', (tester) async {
    for (final layout in HomeAboutLayouts.all) {
      Widget page(bool preview, String title) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ModernHomeAboutSection(
              theme: HomeThemeModel.modernDefault,
              setting: HomeAboutSectionSetting(
                enabled: true,
                layout: layout,
                title: title,
                subtitle: '手動草稿簡介',
                showImage: false,
                showLogo: false,
                useShopNameAsTitle: false,
              ),
              shop: const {},
              environmentIntro: const {},
              shopName: '測試店家',
              logoUrl: '',
              preview: preview,
              onOpen: () => fail('預覽不可導頁'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(true, '我的手動標題'));
      expect(find.textContaining('僅供外觀預覽'), findsOneWidget);
      expect(find.text('我的手動標題'), findsWidgets);
      await tester.pumpWidget(page(true, '更新後標題'));
      expect(find.text('更新後標題'), findsWidgets);
      expect(find.text('我的手動標題'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(page(false, '更新後標題'));
      expect(find.textContaining('僅供外觀預覽'), findsNothing);
      expect(find.text('更新後標題'), findsNothing);
    }
  });
  testWidgets('空常見問題每種版型有預覽提示，正式隱藏不產生假問題', (tester) async {
    for (final layout in HomeFaqLayouts.all) {
      for (final preview in [true, false]) {
        final phase = resolveHomeInfoPhase(
          showOnHome: true,
          editorPreview: preview,
          ready: true,
          failed: false,
          hasContent: false,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernHomeFaqSection(
                theme: HomeThemeModel.modernDefault,
                setting: HomeFaqSectionSetting(layout: layout),
                items: const [],
                phase: phase,
                onOpen: () => fail('空預覽不可導頁'),
              ),
            ),
          ),
        );
        expect(
          find.textContaining('僅供外觀預覽'),
          preview ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
