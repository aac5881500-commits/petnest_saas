import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';

HomeDisplayStyle? homeResolvedDisplayStyle({
  required HomeDisplayStyleSetting setting,
  required String sectionId,
  required HomeDisplayStyle legacy,
  required HomeDisplayStyle baseline,
}) {
  if (!setting.saved) {
    return null;
  }
  return setting.resolve(
    sectionId: sectionId,
    legacy: legacy,
    baseline: baseline,
  );
}

HomeDisplayStyle roomDisplayLegacy(HomeRoomSimpleSetting simple) {
  final bool onImage = simple.textMode == HomeRoomSimpleTextModes.overlay;
  final int titleColor = switch (simple.textColor) {
    HomeRoomSimpleTextColors.light => 0xFFFFFFFF,
    HomeRoomSimpleTextColors.custom => simple.textColorValue ?? 0xFFFFFFFF,
    _ => 0xFF3A2A20,
  };
  return HomeDisplayStyle.roomsBaseline.copyWith(
    textPosition: onImage
        ? (simple.textAlign == HomeRoomSimpleTextAligns.center
              ? HomeDisplayTextPositions.overlay
              : HomeDisplayTextPositions.overlay)
        : HomeDisplayTextPositions.below,
    titleSize: HomeDisplaySizes.migrate(simple.textSize),
    titleWeight: HomeDisplayWeights.migrate(simple.textWeight),
    titleAlign: onImage
        ? _roomAlign(simple.textAlign)
        : HomeDisplayAligns.center,
    bodyAlign: onImage
        ? _roomAlign(simple.textAlign)
        : HomeDisplayAligns.center,
    titleColor: titleColor,
    cardBackground: HomeDisplayBackgrounds.migrate(simple.surface),
    imageAspect: simple.aspect == HomeRoomSimpleAspects.portrait
        ? 'portrait'
        : simple.aspect == HomeRoomSimpleAspects.landscape
        ? 'landscape'
        : 'square',
    imageRadius: HomeDisplayRadii.migrate(simple.radius),
    imageMask: HomeDisplayMasks.migrate(simple.mask),
  );
}

String _roomAlign(String align) {
  switch (align) {
    case HomeRoomSimpleTextAligns.center:
      return HomeDisplayAligns.center;
    case HomeRoomSimpleTextAligns.bottomEnd:
      return HomeDisplayAligns.end;
    default:
      return HomeDisplayAligns.start;
  }
}

HomeDisplayStyle environmentDisplayLegacy(
  HomeEnvironmentSectionSetting setting,
) {
  return HomeDisplayStyle.facilitiesBaseline.copyWith(
    textPosition:
        setting.imageTextPlacement == HomeEnvironmentTextPlacements.below
        ? HomeDisplayTextPositions.below
        : HomeDisplayTextPositions.overlay,
    cardBackground: HomeDisplayBackgrounds.migrate(setting.simpleSurface),
  );
}

HomeDisplayStyle aboutDisplayLegacy(HomeAboutSectionSetting setting) {
  return HomeDisplayStyle.classic.copyWith(
    titleAlign: setting.textAlign == HomeAboutTextAligns.center
        ? HomeDisplayAligns.center
        : HomeDisplayAligns.start,
    bodyAlign: setting.textAlign == HomeAboutTextAligns.center
        ? HomeDisplayAligns.center
        : HomeDisplayAligns.start,
    cardBackground: _aboutBackground(setting.surfaceStyle),
    imageFit: setting.imageFit == HomeAboutImageFits.contain
        ? HomeDisplayFits.contain
        : HomeDisplayFits.cover,
  );
}

String _aboutBackground(String surface) {
  switch (surface) {
    case HomeAboutSurfaces.transparent:
      return HomeDisplayBackgrounds.transparent;
    case HomeAboutSurfaces.translucent:
      return HomeDisplayBackgrounds.outlined;
    default:
      return HomeDisplayBackgrounds.filled;
  }
}

HomeDisplayStyle newsDisplayLegacy(HomeNewsSectionSetting setting) {
  return HomeDisplayStyle.classic.copyWith(
    titleAlign: setting.textAlign == HomeNewsTextAligns.center
        ? HomeDisplayAligns.center
        : HomeDisplayAligns.start,
    bodyAlign: setting.textAlign == HomeNewsTextAligns.center
        ? HomeDisplayAligns.center
        : HomeDisplayAligns.start,
    cardBackground: setting.surfaceStyle == HomeNewsSurfaces.transparent
        ? HomeDisplayBackgrounds.transparent
        : setting.surfaceStyle == HomeNewsSurfaces.translucent
        ? HomeDisplayBackgrounds.outlined
        : HomeDisplayBackgrounds.filled,
  );
}

String aboutSurfaceForDisplay(String background) {
  switch (HomeDisplayBackgrounds.migrate(background)) {
    case HomeDisplayBackgrounds.transparent:
      return HomeAboutSurfaces.transparent;
    case HomeDisplayBackgrounds.outlined:
      return HomeAboutSurfaces.translucent;
    default:
      return HomeAboutSurfaces.solid;
  }
}

String aboutAlignForDisplay(String align) {
  return HomeDisplayAligns.migrate(align) == HomeDisplayAligns.center
      ? HomeAboutTextAligns.center
      : HomeAboutTextAligns.left;
}

String newsSurfaceForDisplay(String background) {
  switch (HomeDisplayBackgrounds.migrate(background)) {
    case HomeDisplayBackgrounds.transparent:
      return HomeNewsSurfaces.transparent;
    case HomeDisplayBackgrounds.outlined:
      return HomeNewsSurfaces.translucent;
    default:
      return HomeNewsSurfaces.solid;
  }
}

String newsAlignForDisplay(String align) {
  return HomeDisplayAligns.migrate(align) == HomeDisplayAligns.center
      ? HomeNewsTextAligns.center
      : HomeNewsTextAligns.left;
}
