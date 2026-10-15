import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_bridge.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_editor.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/refined_image_entry_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/room_section_settings_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing displayStyle keeps the old section look', () {
    final HomeDisplayStyleSetting setting = HomeDisplayStyleSetting.fromMap(
      null,
    );
    expect(setting.saved, isFalse);
    final HomeDisplayStyle legacy = roomDisplayLegacy(
      const HomeRoomSimpleSetting(),
    );
    expect(
      homeResolvedDisplayStyle(
        setting: setting,
        sectionId: HomeDisplaySections.rooms,
        legacy: legacy,
        baseline: HomeDisplayStyle.roomsBaseline,
      ),
      isNull,
    );
    expect(legacy.sameLook(HomeDisplayStyle.roomsBaseline), isTrue);
    expect(
      environmentDisplayLegacy(
        const HomeEnvironmentSectionSetting(),
      ).sameLook(HomeDisplayStyle.facilitiesBaseline),
      isTrue,
    );
    expect(
      aboutDisplayLegacy(
        const HomeAboutSectionSetting(),
      ).sameLook(HomeDisplayStyle.classic),
      isTrue,
    );
  });

  test('saved shared style keeps fields that already differ', () {
    const int sharedColor = 0xFFFF0000;
    final HomeDisplayStyle shared = HomeDisplayStyle.classic.copyWith(
      titleColor: sharedColor,
    );
    final HomeDisplayStyleSetting setting = HomeDisplayStyleSetting(
      saved: true,
      style: shared,
    );
    final HomeDisplayStyle roomLegacy = roomDisplayLegacy(
      const HomeRoomSimpleSetting(textSize: HomeRoomSimpleTextSizes.large),
    );
    final HomeDisplayStyle rooms = setting.resolve(
      sectionId: HomeDisplaySections.rooms,
      legacy: roomLegacy,
      baseline: HomeDisplayStyle.roomsBaseline,
    );
    expect(rooms.titleColor, sharedColor);
    expect(rooms.titleSize, HomeDisplaySizes.large);

    final HomeDisplayStyle environment = setting.resolve(
      sectionId: HomeDisplaySections.facilities,
      legacy: environmentDisplayLegacy(const HomeEnvironmentSectionSetting()),
      baseline: HomeDisplayStyle.facilitiesBaseline,
    );
    expect(environment.titleColor, sharedColor);
    expect(environment.textPosition, shared.textPosition);
    final HomeDisplayStyle pinned = setting.resolve(
      sectionId: HomeDisplaySections.facilities,
      legacy: environmentDisplayLegacy(
        const HomeEnvironmentSectionSetting(
          imageTextPlacement: HomeEnvironmentTextPlacements.below,
        ),
      ),
      baseline: HomeDisplayStyle.facilitiesBaseline,
    );
    expect(pinned.textPosition, HomeDisplayTextPositions.below);
    expect(rooms.titleSize, isNot(environment.titleSize));
  });

  test('inherit drops implicit diffs and custom keeps only overrides', () {
    final HomeDisplayStyle shared = HomeDisplayStyle.classic.copyWith(
      titleColor: 0xFF112233,
    );
    final HomeDisplayStyle legacy = roomDisplayLegacy(
      const HomeRoomSimpleSetting(textSize: HomeRoomSimpleTextSizes.large),
    );
    final HomeDisplayStyleSetting saved = HomeDisplayStyleSetting(
      saved: true,
      style: shared,
    );
    final HomeDisplayStyleSetting inherited = saved.updateSection(
      HomeDisplaySections.rooms,
      mode: HomeDisplayStyleModes.inherit,
      clearOverride: true,
    );
    expect(
      inherited
          .resolve(
            sectionId: HomeDisplaySections.rooms,
            legacy: legacy,
            baseline: HomeDisplayStyle.roomsBaseline,
          )
          .titleSize,
      HomeDisplaySizes.medium,
    );
    expect(
      inherited.sections[HomeDisplaySections.rooms]!.override.isEmpty,
      isTrue,
    );

    final HomeDisplayStyle effective = saved.resolve(
      sectionId: HomeDisplaySections.rooms,
      legacy: legacy,
      baseline: HomeDisplayStyle.roomsBaseline,
    );
    final HomeDisplayStyleSetting custom = saved.updateSection(
      HomeDisplaySections.rooms,
      mode: HomeDisplayStyleModes.custom,
      override: effective.diff(shared),
    );
    final HomeDisplayStyle moved = custom
        .copyWith(style: shared.copyWith(titleColor: 0xFF00AA00))
        .resolve(
          sectionId: HomeDisplaySections.rooms,
          legacy: legacy,
          baseline: HomeDisplayStyle.roomsBaseline,
        );
    expect(moved.titleSize, HomeDisplaySizes.large);
    expect(moved.titleColor, 0xFF00AA00);

    const String subtitle = '查看住宿空間與價格';
    final HomeDisplayStyleSetting restored = custom.updateSection(
      HomeDisplaySections.rooms,
      mode: HomeDisplayStyleModes.inherit,
      clearOverride: true,
    );
    expect(
      restored.sections[HomeDisplaySections.rooms]!.override.isEmpty,
      isTrue,
    );
    expect(subtitle, '查看住宿空間與價格');
    final HomeDisplayStyleSetting again = HomeDisplayStyleSetting.fromMap(
      restored.toMap(),
    );
    expect(again.saved, isTrue);
    expect(
      again.sections[HomeDisplaySections.rooms]!.mode,
      HomeDisplayStyleModes.inherit,
    );
  });

  test('unified color keeps the separate body color', () {
    final HomeDisplayStyle separate = HomeDisplayStyle.classic.copyWith(
      colorMode: HomeDisplayColorModes.separate,
      titleColor: 0xFF111111,
      bodyColor: 0xFF00FF00,
    );
    final HomeDisplayStyle unified = separate.copyWith(
      colorMode: HomeDisplayColorModes.unified,
    );
    expect(unified.bodyColor, 0xFF00FF00);
    expect(unified.effectiveBodyColor, 0xFF111111);
    final HomeDisplayStyle back = unified.copyWith(
      colorMode: HomeDisplayColorModes.separate,
    );
    expect(back.effectiveBodyColor, 0xFF00FF00);
  });

  testWidgets('text sits above, on, or below the image', (
    WidgetTester tester,
  ) async {
    Future<void> pump(String position) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: RefinedImageEntryCard(
                cardKey: const Key('card'),
                featureId: 'rooms',
                theme: HomeThemeModel.modernDefault,
                title: '入口標題',
                subtitle: '說明文字',
                showSubtitle: true,
                textMode: HomeRoomSimpleTextModes.below,
                textAlign: HomeRoomSimpleTextAligns.center,
                textSize: HomeRoomSimpleTextSizes.medium,
                textWeight: HomeRoomSimpleTextWeights.bold,
                textColor: HomeRoomSimpleTextColors.dark,
                aspect: HomeRoomSimpleAspects.square,
                radius: HomeRoomSimpleRadii.medium,
                mask: HomeRoomSimpleMasks.none,
                imageUrl: '',
                textPosition: position,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump(HomeDisplayTextPositions.above);
    final double aboveTitle = tester.getTopLeft(find.text('入口標題')).dy;
    final double aboveImage = tester
        .getTopLeft(find.byKey(const Key('refined-entry-image')))
        .dy;
    expect(aboveTitle, lessThan(aboveImage));

    await pump(HomeDisplayTextPositions.below);
    final double belowTitle = tester.getTopLeft(find.text('入口標題')).dy;
    final double belowImage = tester
        .getBottomLeft(find.byKey(const Key('refined-entry-image')))
        .dy;
    expect(belowTitle, greaterThan(belowImage - 1));

    await pump(HomeDisplayTextPositions.overlay);
    final double overlayTitle = tester.getCenter(find.text('入口標題')).dy;
    final Rect image = tester.getRect(
      find.byKey(const Key('refined-entry-image')),
    );
    expect(overlayTitle, greaterThan(image.top));
    expect(overlayTitle, lessThan(image.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared editor fits desktop and phone widths', (
    WidgetTester tester,
  ) async {
    for (final double width in <double>[360, 900]) {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: HomeDisplayStyleEditor(
                  setting: HomeDisplayStyleSetting.unset,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('圖片與文字排版'), findsOneWidget);
      expect(find.text('展示卡片外觀'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('room page hides duplicate visual controls when linked', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomSectionSettingsPanel(
            shopId: 'shop',
            setting: const HomeRoomSectionSetting(
              layout: HomeRoomSectionLayouts.simpleEntry,
            ),
            theme: HomeThemeModel.modernDefault,
            rooms: const <Map<String, dynamic>>[],
            displayStyles: HomeDisplayStyleSetting.unset,
            onDisplayStyles: (_) {},
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('沿用'), findsOneWidget);
    expect(find.text('文字小'), findsNothing);
    expect(find.text('清除圖片'), findsNothing);
    expect(find.text('從平台圖庫選擇'), findsOneWidget);
  });
}
