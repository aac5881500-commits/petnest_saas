import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_block.dart';

void main() {
  test('subtitle style persists independently of content and template', () {
    final style = const StoreBrandStyle().copyWith(
      subtitleAngle: -4.6,
      subtitleFontFamily: 'KleeOne',
    );
    final restored = StoreBrandStyle.fromMap(style.toMap());
    expect(restored.subtitleAngle, -4.6);
    expect(restored.subtitleFontFamily, 'KleeOne');
    expect(restored.markType, 'builtinIcon');
    expect(restored.copyWith(nameFontSize: 20).subtitleAngle, -4.6);
    expect(
      StoreBrandStyle.fromMap({'homepageBrandSubtitleAngle': 99}).subtitleAngle,
      15,
    );
    expect(
      StoreBrandStyle.fromMap({
        'homepageBrandMarkType': 'wordmark',
      }).subtitleAngle,
      -4.6,
    );
  });
  testWidgets('deleting and reentering subtitle preserves editable rotation', (
    tester,
  ) async {
    final style = const StoreBrandStyle(
      subtitleAngle: -6,
      subtitleFontFamily: 'KleeOne',
    );
    for (final caption in ['安心的後盾', '', '重新輸入副標']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: StoreBrandBlock(
                contextKind: StoreBrandDisplayContext.home,
                style: style,
                shopName: '貓咪旅店',
                subtitle: caption,
                logoUrl: '',
                theme: HomeThemeModel.modernDefault,
              ),
            ),
          ),
        ),
      );
      final rotation = find.byKey(const ValueKey('brand-subtitle-rotation'));
      if (caption.isEmpty) {
        expect(rotation, findsNothing);
      } else {
        expect(rotation, findsOneWidget);
        final transform = tester.widget<Transform>(rotation);
        expect(transform.transform.entry(0, 1), closeTo(0.104528, .00001));
        expect(
          tester.widget<Text>(find.text(caption)).style?.fontFamily,
          'KleeOne',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
}
