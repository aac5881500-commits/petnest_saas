import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_photo.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/editorial_section_widgets.dart';

void main() {
  testWidgets('about builtin cover is preserved from settings to homepage', (tester) async {
    final url = HomeAboutSectionSetting.resolveImageUrl(
      setting: const HomeAboutSectionSetting(imageSource: 'aboutCover'),
      shop: const {'homeAppearance': {'aboutPage': {'cover': {'source': 'builtin', 'assetId': 'daylight-cover'}}}},
      environmentIntro: const {},
    );
    expect(url, 'builtin-about:daylight-cover');
    await tester.pumpWidget(MaterialApp(home: SizedBox(width: 200, height: 150, child: sectionPhoto(url))));
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
    expect(tester.takeException(), isNull);
  });
  testWidgets('homepage feature photos render environment template assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnvironmentHighlightCards(
            items: const [
              {'title': '窗邊貓窩', 'imageUrl': 'builtin-env:warm-room'},
              {'title': '垂直貓跳台', 'imageUrl': 'builtin-env:warm-climb'},
            ],
            theme: HomeThemeModel.modernDefault,
            onOpen: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EnvironmentPhoto), findsNWidgets(2));
    expect(find.byType(Image), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('about gallery photo resolves and renders same template source', (
    tester,
  ) async {
    final url = HomeAboutSectionSetting.resolveImageUrl(
      setting: const HomeAboutSectionSetting(imageSource: 'galleryFirst'),
      shop: const {},
      environmentIntro: const {
        'galleryImages': [
          {'imageUrl': 'builtin-env:warm-about'},
        ],
      },
    );
    expect(url, 'builtin-env:warm-about');
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 200, height: 150, child: sectionPhoto(url)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
    expect(tester.takeException(), isNull);
  });
  testWidgets('uploaded photos keep their original HTTPS source', (
    tester,
  ) async {
    const url = 'https://example.com/shop/upload.jpg';
    await tester.pumpWidget(MaterialApp(home: sectionPhoto(url)));
    expect(tester.widget<Image>(find.byType(Image)).image, isA<NetworkImage>());
    expect(
      (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url,
      url,
    );
    await tester.pumpAndSettle();
  });
}
