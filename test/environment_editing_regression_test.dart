import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/environment_presentation.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_feature_manager.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_gallery_grid.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_services_editor.dart';

void main() {
  test('手機桌機照片設定獨立並保留未知欄位', () {
    final p = EnvironmentPresentation(
      raw: {
        'photoSettings': {
          'phone_hero': {'aspect': '4:3', 'fit': 'contain', 'alignment': 'top'},
          'desktop_hero': {
            'height': 320,
            'fit': 'cover',
            'alignment': 'bottom',
          },
        },
        'sectionGaps': {'gallery': 40},
        'legacy': true,
      },
    );
    expect(p.photoHeight('hero', 360, 260), 270);
    expect(p.photoHeight('hero', 1200, 260), 320);
    expect(p.photoFit('hero', 360, BoxFit.cover), BoxFit.contain);
    expect(
      p.photoAlignment('hero', 1200, Alignment.center),
      Alignment.bottomCenter,
    );
    expect(p.sectionGap('gallery', 22), 40);
    expect(p.sectionGap('features', 22), 22);
    expect(p.copyWith({'galleryLayout': 'mosaic'}).toMap()['legacy'], isTrue);
  });

  testWidgets('窄版特色管理的標題與所有操作不溢位', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: EnvironmentFeatureManager(
                features: [
                  {'title': '安靜休息與自由探索的環境特色', 'icon': 'home'},
                ],
                onAdd: () {},
                onDelete: (_) async {},
                onEdit: (_) async {},
                onChangeIcon: (_) async {},
                onChangeLayout: (_) async {},
                onManageImage: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('更換特色圖示'), findsOneWidget);
    expect(find.byTooltip('切換圖片左右位置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final layout in ['grid', 'single', 'mosaic']) {
    testWidgets('相簿 $layout 排列與照片放大可操作', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EnvironmentGalleryGrid(
                images: const ['a', 'b', 'c', 'd'],
                captions: const ['窗邊休憩', '', '', ''],
                layout: layout,
                imageBuilder:
                    ({
                      required String imageUrl,
                      double? width,
                      double? height,
                      BoxFit fit = BoxFit.cover,
                    }) => ColoredBox(
                      key: ValueKey('photo-$imageUrl'),
                      color: Colors.green,
                      child: const SizedBox(width: 100, height: 100),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byKey(const ValueKey('photo-a')));
      final second = tester.getRect(find.byKey(const ValueKey('photo-b')));
      if (layout == 'single') {
        expect(second.top, greaterThan(first.bottom));
      } else {
        expect(first.top, second.top);
      }
      await tester.tap(find.byKey(const ValueKey('photo-a')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.text('關閉'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('服務名稱有效後即時解除必填錯誤', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EnvironmentServicesEditor(
              selectedKeys: const [],
              presentation: EnvironmentPresentation(),
              onSelected: (_) {},
              onChanged: (_) {},
              onUpload: (_) {},
              onRemoveImage: (_) {},
              onDelete: (_) {},
              iconOf: (_) => Icons.pets,
              busy: false,
            ),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('新增自訂服務'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('新增自訂服務'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('套用到草稿'));
    await tester.pumpAndSettle();
    expect(find.text('請填寫名稱'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '名稱'), '每日陪伴');
    await tester.pumpAndSettle();
    expect(find.text('請填寫名稱'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
