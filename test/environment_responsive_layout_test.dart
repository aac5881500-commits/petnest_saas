import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/environment_presentation.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/environment_image_frame_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_feature_card.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_intro_view.dart';

void main() {
  test('區塊排序補足缺漏並忽略無效項目，未知設定仍保留', () {
    final p = EnvironmentPresentation(
      raw: {
        'preset': 'warm',
        'sectionOrder': ['gallery', 'bad', 'gallery'],
        'hiddenSections': ['note', 'bad'],
        'sectionTitles': {'features': '旅宿亮點'},
        'contentMaxWidth': 9000,
        'featureImageMaxHeight': -1,
        'legacy': true,
      },
    );
    expect(p.sectionOrder, [
      'gallery',
      'hero',
      'features',
      'banner',
      'care',
      'note',
    ]);
    expect(p.hiddenSections, ['note']);
    expect(p.sectionTitle('features', '預設'), '旅宿亮點');
    expect(p.contentMaxWidth, 1400);
    expect(p.featureImageMaxHeight, 160);
    expect(p.copyWith({'desktopColumns': 'double'}).toMap()['legacy'], isTrue);
  });
  for (final width in [375.0, 390.0, 430.0, 1200.0]) {
    testWidgets('上圖下文在 $width 寬度下保持可讀且限制圖片高度', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentIntroView(
              style: const EnvironmentIntroStyle(cardLayout: 'vertical'),
              theme: HomeThemeModel.classicDefault,
              heroTitle: '',
              heroSubtitle: '',
              heroImageUrl: '',
              heroFrame: const EnvironmentImageFrameSetting(
                slot: EnvironmentImageSlot.hero,
              ),
              bannerTitle: '',
              bannerImageUrl: '',
              bannerFrame: const EnvironmentImageFrameSetting(
                slot: EnvironmentImageSlot.middleBanner,
              ),
              features: [
                for (var i = 0; i < 2; i++)
                  {
                    'title': '環境特色 $i',
                    'description': '可以安心休息與探索的空間。',
                    'imageUrl': 'fixture-$i',
                  },
              ],
              galleryImages: const [],
              careItems: const [],
              bottomNote: '',
              imageBuilder:
                  ({
                    required String imageUrl,
                    double? width,
                    double? height,
                    BoxFit fit = BoxFit.cover,
                  }) =>
                      ColoredBox(key: ValueKey(imageUrl), color: Colors.green),
              featureIconOf: (_) => Icons.pets,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byType(EnvironmentFeatureCard).at(0));
      final second = tester.getRect(find.byType(EnvironmentFeatureCard).at(1));
      if (width >= 800) {
        expect(first.top, second.top);
        expect(second.left, greaterThan(first.left));
      } else {
        expect(second.top, greaterThanOrEqualTo(first.bottom));
      }
      expect(
        tester.getSize(find.byKey(const ValueKey('fixture-0'))).height,
        lessThanOrEqualTo(280),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
