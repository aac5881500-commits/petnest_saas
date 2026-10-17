// 檔案名稱：test/home_poster_font_style_test.dart
// 功能說明：海報文字圖層字體、快速樣式與預覽字型一致。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_banner_editor_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('舊海報沒有字體欄位時沿用系統預設', () {
    final StoreBannerTextElement element =
        StoreBannerTextElement.fromMap(const <String, dynamic>{
          'id': 'old',
          'text': '舊標題',
          'positionX': 0.2,
          'positionY': 0.3,
          'fontFamily': 'NotARealFont',
        });
    expect(element.fontFamily, isEmpty);
    expect(element.appliedFontFamily, isNull);
    expect(element.letterSpacing, 0);
    expect(element.positionX, 0.2);
    expect(element.text, '舊標題');
  });

  test('字體與字距可各自儲存並讀回', () {
    const StoreBannerTextElement title = StoreBannerTextElement(
      id: 'a_title',
      text: '主標題',
      positionX: 0.12,
      positionY: 0.2,
      fontFamily: StoreBannerFonts.sans,
    );
    const StoreBannerTextElement subtitle = StoreBannerTextElement(
      id: 'a_sub',
      text: '副標題',
      fontFamily: StoreBannerFonts.serif,
      letterSpacing: 2,
    );
    final StoreBannerModel banner = StoreBannerModel(
      id: 'poster',
      textElements: <StoreBannerTextElement>[title, subtitle],
    );
    final StoreBannerModel loaded = StoreBannerModel.fromMap(banner.toMap());
    expect(loaded.textElements[0].fontFamily, StoreBannerFonts.sans);
    expect(loaded.textElements[1].fontFamily, StoreBannerFonts.serif);
    expect(loaded.textElements[1].letterSpacing, 2);
    expect(loaded.textElements[0].text, '主標題');
    expect(loaded.textElements[1].positionY, subtitle.positionY);
  });

  test('快速樣式只改外觀，手動改大小後不再視為該樣式', () {
    const StoreBannerTextElement element = StoreBannerTextElement(
      id: 'line',
      text: '夏季住宿',
      positionX: 0.33,
      positionY: 0.44,
      textAlign: 'center',
      maxWidthPreset: StoreBannerTextWidthPresets.wide,
    );
    final StoreBannerTextStylePreset classic =
        StoreBannerTextStylePreset.all.first;
    final StoreBannerTextElement styled = classic.apply(element);
    expect(styled.text, '夏季住宿');
    expect(styled.positionX, 0.33);
    expect(styled.positionY, 0.44);
    expect(styled.textAlign, 'center');
    expect(styled.maxWidthPreset, StoreBannerTextWidthPresets.wide);
    expect(styled.fontFamily, StoreBannerFonts.sans);
    expect(styled.fontSize, 104);
    expect(classic.matches(styled), isTrue);

    final StoreBannerTextElement tweaked = styled.copyWith(fontSize: 80);
    expect(classic.matches(tweaked), isFalse);
    expect(tweaked.fontFamily, StoreBannerFonts.sans);
    expect(tweaked.text, '夏季住宿');
  });

  test('五種快速樣式都使用已安裝字型', () {
    expect(StoreBannerTextStylePreset.all, hasLength(5));
    for (final StoreBannerTextStylePreset preset
        in StoreBannerTextStylePreset.all) {
      expect(StoreBannerFonts.applied(preset.fontFamily), preset.fontFamily);
    }
  });

  testWidgets('不同圖層在預覽使用各自的字型', (WidgetTester tester) async {
    final StoreBannerModel banner = StoreBannerModel(
      id: 'fonts',
      contentMode: StoreBannerContentModes.templateOverlay,
      textElements: const <StoreBannerTextElement>[
        StoreBannerTextElement(
          id: 'a_title',
          text: '主標題字',
          positionX: 0.08,
          positionY: 0.16,
          fontFamily: StoreBannerFonts.sans,
          fontSize: 72,
        ),
        StoreBannerTextElement(
          id: 'a_sub',
          text: '副標題字',
          positionX: 0.08,
          positionY: 0.48,
          fontFamily: StoreBannerFonts.serif,
          fontSize: 36,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: StoreBannerView(
              banner: banner,
              theme: HomeThemeModel.modernDefault,
              scope: PetNestBannerScope.home,
              composeLive: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('主標題字')).style?.fontFamily,
      StoreBannerFonts.sans,
    );
    expect(
      tester.widget<Text>(find.text('副標題字')).style?.fontFamily,
      StoreBannerFonts.serif,
    );
  });

  testWidgets('文字分頁可切換字體與快速樣式，手機桌機不溢出', (WidgetTester tester) async {
    Future<void> open(Size size) async {
      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final StoreBannerEditorController controller =
          StoreBannerEditorController();
      await tester.pumpWidget(
        MaterialApp(
          home: ShopStoreBannerEditorPage(
            key: ValueKey<double>(size.width),
            shopId: 'shop',
            controller: controller,
            scope: PetNestBannerScope.home,
            showInlinePreview: false,
            banner: const StoreBannerModel(
              id: 'poster',
              contentMode: StoreBannerContentModes.templateOverlay,
              imageUrl: 'https://example.com/poster.jpg',
              textElements: <StoreBannerTextElement>[
                StoreBannerTextElement(
                  id: 'poster_title',
                  text: '主標題',
                  positionX: 0.2,
                  positionY: 0.3,
                ),
                StoreBannerTextElement(
                  id: 'poster_sub',
                  text: '副標題',
                  positionX: 0.2,
                  positionY: 0.55,
                  fontFamily: StoreBannerFonts.rounded,
                ),
              ],
            ),
            existingBanners: const <StoreBannerModel>[],
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('文字'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('poster-text-editor')),
              matching: find.byWidgetPredicate(
                (Widget widget) =>
                    widget is ListTile &&
                    widget is! SwitchListTile &&
                    widget.title is Text &&
                    (widget.title! as Text).data == '副標題',
              ),
            )
            .first,
      );
      await tester.pumpAndSettle();
      Future<void> reveal(Finder target, {double delta = 180}) async {
        final Finder scrollable = find
            .descendant(
              of: find.byKey(const ValueKey<String>('poster-text-editor')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(target, delta, scrollable: scrollable);
        await tester.pumpAndSettle();
        final double bottom = tester.getBottomLeft(target).dy;
        final double limit =
            tester.view.physicalSize.height / tester.view.devicePixelRatio - 96;
        if (bottom > limit) {
          await tester.drag(scrollable, Offset(0, limit - bottom - 24));
          await tester.pumpAndSettle();
        }
      }

      await reveal(find.text('字體'));
      expect(find.text('字體'), findsWidgets);
      expect(find.text('快速文字樣式'), findsOneWidget);
      await reveal(find.text('經典標題'));
      expect(tester.takeException(), isNull);

      expect(
        controller.draft!.resolvedTextElements
            .firstWhere(
              (StoreBannerTextElement item) => item.id.endsWith('_sub'),
            )
            .fontFamily,
        StoreBannerFonts.rounded,
      );

      await tester.tap(find.text('經典標題'));
      await tester.pumpAndSettle();
      final StoreBannerTextElement styled = controller
          .draft!
          .resolvedTextElements
          .firstWhere(
            (StoreBannerTextElement item) => item.id.endsWith('_sub'),
          );
      expect(styled.fontFamily, StoreBannerFonts.sans);
      expect(styled.text, '副標題');
      expect(styled.positionX, 0.2);
      expect(styled.positionY, 0.55);

      await reveal(find.byType(DropdownButtonFormField<String>), delta: -180);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('思源宋體').last);
      await tester.pumpAndSettle();
      final StoreBannerTextElement manual = controller
          .draft!
          .resolvedTextElements
          .firstWhere(
            (StoreBannerTextElement item) => item.id.endsWith('_sub'),
          );
      expect(manual.fontFamily, StoreBannerFonts.serif);
      expect(manual.fontSize, 104);
      expect(manual.text, '副標題');
      expect(tester.takeException(), isNull);
    }

    await open(const Size(1100, 900));
    await tester.pumpWidget(const SizedBox.shrink());
    await open(const Size(390, 844));
    await tester.binding.setSurfaceSize(null);
  });
}
