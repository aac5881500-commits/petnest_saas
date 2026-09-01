import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';

void main() {
  test('missing firestore fields use standard defaults', () {
    final EnvironmentIntroStyle style = EnvironmentIntroStyle.fromMap(null);
    expect(style.displaySize, EnvironmentIntroStyle.sizeStandard);
    expect(style.fontSize, EnvironmentIntroStyle.fontStandard);
    expect(style.cardLayout, EnvironmentIntroStyle.layoutHorizontal);
    expect(style.cardDensity, EnvironmentIntroStyle.densityStandard);

    final EnvironmentIntroStyle empty = EnvironmentIntroStyle.fromMap(
      <String, dynamic>{},
    );
    expect(empty.displaySize, EnvironmentIntroStyle.sizeStandard);
    expect(empty.cardLayout, EnvironmentIntroStyle.layoutHorizontal);
  });

  test('invalid values fall back to standard', () {
    final EnvironmentIntroStyle style =
        EnvironmentIntroStyle.fromMap(<String, dynamic>{
          'environmentDisplaySize': 'huge',
          'environmentFontSize': '',
          'environmentFeatureCardLayout': 'grid',
          'environmentFeatureCardDensity': 12,
        });
    expect(style.displaySize, EnvironmentIntroStyle.sizeStandard);
    expect(style.fontSize, EnvironmentIntroStyle.fontStandard);
    expect(style.cardLayout, EnvironmentIntroStyle.layoutHorizontal);
    expect(style.cardDensity, EnvironmentIntroStyle.densityStandard);
  });

  test('font small is smaller and large is bigger than standard', () {
    const EnvironmentIntroStyle small = EnvironmentIntroStyle(
      fontSize: EnvironmentIntroStyle.fontSmall,
    );
    const EnvironmentIntroStyle standard = EnvironmentIntroStyle();
    const EnvironmentIntroStyle large = EnvironmentIntroStyle(
      fontSize: EnvironmentIntroStyle.fontLarge,
    );
    expect(small.pageTitleSize < standard.pageTitleSize, isTrue);
    expect(standard.pageTitleSize < large.pageTitleSize, isTrue);
    expect(small.cardTitleSize < large.cardTitleSize, isTrue);
    expect(small.careTitleSize < large.careTitleSize, isTrue);
    expect(small.bottomNoteSize < large.bottomNoteSize, isTrue);
  });

  test('display size changes spacing without using widget scale', () {
    const EnvironmentIntroStyle compact = EnvironmentIntroStyle(
      displaySize: EnvironmentIntroStyle.sizeCompact,
    );
    const EnvironmentIntroStyle standard = EnvironmentIntroStyle();
    const EnvironmentIntroStyle large = EnvironmentIntroStyle(
      displaySize: EnvironmentIntroStyle.sizeLarge,
    );
    expect(compact.pagePadding < standard.pagePadding, isTrue);
    expect(standard.pagePadding < large.pagePadding, isTrue);
    expect(compact.sectionGap < large.sectionGap, isTrue);
    expect(compact.heroHeightScale < large.heroHeightScale, isTrue);
  });

  test('card density changes minHeight and padding not a fixed height', () {
    const EnvironmentIntroStyle compact = EnvironmentIntroStyle(
      cardDensity: EnvironmentIntroStyle.densityCompact,
    );
    const EnvironmentIntroStyle standard = EnvironmentIntroStyle();
    const EnvironmentIntroStyle comfortable = EnvironmentIntroStyle(
      cardDensity: EnvironmentIntroStyle.densityComfortable,
    );
    expect(compact.featureMinHeight < comfortable.featureMinHeight, isTrue);
    expect(compact.featurePadding < comfortable.featurePadding, isTrue);
    expect(
      compact.featureImageMaxHeight < comfortable.featureImageMaxHeight,
      isTrue,
    );
    expect(standard.featureMinHeight, 92);
    expect(standard.featureImageMaxHeight, 84);
  });

  test('care columns drop to 2 when large and narrow', () {
    const EnvironmentIntroStyle large = EnvironmentIntroStyle(
      displaySize: EnvironmentIntroStyle.sizeLarge,
    );
    expect(large.careColumns(360), 2);
    expect(large.careColumns(520), 3);
    const EnvironmentIntroStyle standard = EnvironmentIntroStyle();
    expect(standard.careColumns(360), 3);
    expect(standard.galleryColumns(390), 2);
    expect(standard.galleryColumns(800), 3);
  });
}
