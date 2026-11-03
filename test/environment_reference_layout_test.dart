import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/environment_presentation.dart';
import 'package:petnest_saas/core/models/environment_quick_layout.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/environment_image_frame_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_intro_view.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_editorial_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_layout_editor.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_gallery_grid.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_bottom_note.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';

EnvironmentPresentation recipe() => EnvironmentQuickLayout.presentation(
  EnvironmentPresentation(),
).copyWith({'customServices': EnvironmentQuickLayout.sampleServices()});
Widget view(EnvironmentPresentation p) {
  final data = EnvironmentQuickLayout.sampleIntro();
  return EnvironmentIntroView(
    style: const EnvironmentIntroStyle(),
    theme: HomeThemeModel.classicDefault,
    presentation: p,
    heroTitle: data['heroTitle'] as String,
    heroSubtitle: data['heroSubtitle'] as String,
    heroImageUrl: data['heroImageUrl'] as String,
    heroFrame: const EnvironmentImageFrameSetting(
      slot: EnvironmentImageSlot.hero,
    ),
    bannerTitle: data['bannerTitle'] as String,
    bannerImageUrl: data['bannerImageUrl'] as String,
    bannerFrame: const EnvironmentImageFrameSetting(
      slot: EnvironmentImageSlot.middleBanner,
    ),
    features: List<Map<String, dynamic>>.from(data['features'] as List),
    galleryImages: (data['galleryImages'] as List)
        .map((m) => m['imageUrl'] as String)
        .toList(),
    careItems: const [],
    bottomNote: data['bottomNote'] as String,
    imageBuilder: environmentIntroNetworkImage,
    featureIconOf: environmentIntroIcon,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['NotoSerifTC', 'KleeOne', 'MaterialIcons']) {
      final file = family == 'MaterialIcons'
          ? 'fonts/MaterialIcons-Regular.otf'
          : family == 'NotoSerifTC'
          ? 'assets/fonts/NotoSerifTC-VariableFont_wght.ttf'
          : 'assets/fonts/KleeOne-Regular.ttf';
      final loader = FontLoader(family)..addFont(rootBundle.load(file));
      await loader.load();
    }
  });
  test('快速排版只是一般設定配方，保留其他欄位與既有服務', () {
    final p = EnvironmentPresentation(
      raw: {
        'unknown': 7,
        'customServices': [
          {'id': 'existing', 'title': '原有服務'},
        ],
        'appearance': {'unknownColor': 8},
      },
    );
    final next = EnvironmentQuickLayout.presentation(p);
    expect(next.toMap()['unknown'], 7);
    expect(next.services.single.title, '原有服務');
    expect(next.appearance.toMap()['unknownColor'], 8);
    expect(next.layout.featureLayout, 'photoSide');
    expect(next.layout.toMap(), containsPair('footerTogether', true));
    expect(next.copyWith({'preset': ''}).layout.toMap(), next.layout.toMap());
  });
  for (final size in [const Size(390, 1600), const Size(1200, 1000)]) {
    testWidgets('參考排版 ${size.width} 並排與自動適配，輸出真實元件截圖', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(key: key, child: view(recipe())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Decode the local image outside the fake clock before screenshot capture.
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/environment_warm_photos_v1.png'),
          tester.element(find.byType(EnvironmentIntroView)),
        );
      });
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byType(EnvironmentPhotoSideCard).first);
      final second = tester.getRect(find.byType(EnvironmentPhotoSideCard).last);
      final gallery = tester.getRect(find.byType(EnvironmentGalleryGrid));
      final note = tester.getRect(find.byType(EnvironmentBottomNote));
      if (size.width >= 800) {
        expect(first.top, second.top);
        expect(gallery.top, note.top);
        expect(second.left, greaterThan(first.left));
      } else {
        expect(second.top, greaterThan(first.top));
        expect(note.top, greaterThan(gallery.top));
      }
      expect(find.byType(EnvironmentSplitPhoto), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      final before = first;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: view(recipe().copyWith({'preset': ''})),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(EnvironmentPhotoSideCard).first),
        before,
      );
      if (const bool.fromEnvironment('EXPORT_ENVIRONMENT_PREVIEW')) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'C:/Users/aac58/OneDrive/文件/ChatGPT/貓咪旅店專案/review-work/environment-reference-${size.width.toInt()}-808fea40.png',
          );
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('快速排版可修改並儲存，無任何桌機專用設定', (tester) async {
    const size = Size(1400, 1000);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final writes = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: size),
          child: child!,
        ),
        home: ShopEnvironmentManagePage(
          shopId: 'fixture',
          loadShop: () async => {
            'environmentIntro': {
              'heroTitle': '原有標題',
              'features': <Map<String, dynamic>>[],
            },
          },
          saveIntro: (data) async => writes.add(data),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('environment-apply-warm-template')),
    );
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, '套用到草稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('進階外觀'));
    await tester.pumpAndSettle();
    expect(find.byType(EnvironmentLayoutEditor), findsOneWidget);
    expect(find.text('桌機特色卡排列（寬度 800 以上）'), findsNothing);
    // A normal public control changes the same record populated by the recipe.
    final editor = tester.widget<EnvironmentLayoutEditor>(
      find.byType(EnvironmentLayoutEditor),
    );
    editor.onChanged(
      editor.value.copyWith({'photoFraction': .33, 'heroEyebrow': '客戶自己的小標'}),
    );
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, '儲存').first);
    await tester.pumpAndSettle();
    final p = EnvironmentPresentation.fromMap(
      writes.single['environmentPresentation'],
    );
    expect(p.layout.photoFraction, .33);
    expect(p.layout.text('heroEyebrow'), '客戶自己的小標');
    expect(writes.single['features'], hasLength(2));
    expect(p.services, hasLength(3));
    final state =
        tester.state(find.byType(ShopEnvironmentManagePage))
            as ShopDashboardLeaveAware;
    expect(state.dashboardHasUnsavedChanges, isFalse);
    expect(tester.takeException(), isNull);
  });
}
