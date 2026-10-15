import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_shared_entry_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/refined_image_entry_card.dart';

const double kSharedEntryMaxRowWidth = 640;
const double kSharedEntryGap = 12;
const double kSharedEntrySingleColumnCap = 280;

/// 每排固定為所選的 1、2 或 3 張。舊資料的 4 張在這裡收成 3 張。
int sharedEntryColumnCount({required int preferred, required double width}) {
  final int requested = sharedEntryColumns(preferred);
  if (!width.isFinite || width <= 0) {
    return requested;
  }
  return requested;
}

double sharedEntryRowWidth(double available) {
  if (!available.isFinite || available <= 0) {
    return kSharedEntryMaxRowWidth;
  }
  return math.min(available, kSharedEntryMaxRowWidth);
}

double sharedEntrySlotWidth({
  required double width,
  required int columns,
  double gap = kSharedEntryGap,
}) {
  final int count = sharedEntryColumnCount(preferred: columns, width: width);
  return math.max(0, (width - gap * (count - 1)) / count);
}

/// 圖片在自己的欄位裡縮小並置中。一排一張時先限制最大寬度，避免拉滿整支手機。
double sharedEntryVisualWidth({
  required double slot,
  required int columns,
  required double imageScale,
}) {
  final double capped = columns <= 1
      ? math.min(slot, kSharedEntrySingleColumnCap)
      : slot;
  final double factor = imageScale.clamp(0.7, 1);
  return math.max(0, capped * factor);
}

/// 首頁共用精緻小卡區。排列在這裡，卡片內容由 [cardBuilder] 提供。
class ModernHomeSharedEntrySection extends StatelessWidget {
  const ModernHomeSharedEntrySection({
    super.key,
    required this.theme,
    required this.setting,
    required this.cardIds,
    required this.cardBuilder,
  });

  final HomeThemeModel theme;
  final HomeSharedEntrySectionSetting setting;
  final List<String> cardIds;
  final Widget Function(String id) cardBuilder;

  @override
  Widget build(BuildContext context) {
    final bool titled = setting.showTitle && setting.title.trim().isNotEmpty;
    if (!titled && cardIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double rowWidth = sharedEntryRowWidth(constraints.maxWidth);
        final double inset = setting.style.insetX;
        final double inner = math.max(0, rowWidth - inset * 2);
        final int columns = sharedEntryColumnCount(
          preferred: setting.columns,
          width: inner,
        );
        final double gapX = setting.style.gapX;
        final double gapY = setting.style.gapY;
        final double slot = sharedEntrySlotWidth(
          width: inner,
          columns: columns,
          gap: gapX,
        );
        final bool scrolling =
            setting.overflow == HomeSharedEntryOverflows.scroll &&
            cardIds.length > columns;
        final Widget body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (titled)
              HomeEntryFontScope(
                fontFamily: setting.style.appliedFontFamily,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: cardIds.isEmpty ? 0 : math.max(12, gapY),
                  ),
                  child: Text(
                    setting.title.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                ),
              ),
            if (scrolling)
              _scrollRow(context, slot, gapX)
            else
              _wrapRows(slot: slot, columns: columns, gapX: gapX, gapY: gapY),
          ],
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: SizedBox(width: inner, child: body),
          ),
        );
      },
    );
  }

  Widget _wrapRows({
    required double slot,
    required int columns,
    required double gapX,
    required double gapY,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (
          int start = 0;
          start < cardIds.length;
          start += columns
        ) ...<Widget>[
          if (start > 0) SizedBox(height: gapY),
          _cardRow(
            cardIds.sublist(start, math.min(start + columns, cardIds.length)),
            slot,
            gapX,
          ),
        ],
      ],
    );
  }

  /// 只有小卡這一列橫向滑動，首頁本身維持直向。
  Widget _scrollRow(BuildContext context, double slot, double gapX) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: <PointerDeviceKind>{
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          key: const Key('shared-entry-scroll'),
          scrollDirection: Axis.horizontal,
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: _cardRow(cardIds, slot, gapX),
        ),
      ),
    );
  }

  Widget _cardRow(List<String> ids, double slot, double gapX) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int index = 0; index < ids.length; index++) ...<Widget>[
          if (index > 0) SizedBox(width: gapX),
          SizedBox(width: slot, child: cardBuilder(ids[index])),
        ],
      ],
    );
  }
}

/// 單張小卡沿用來源功能的字型，不影響共用區標題。
class HomeEntryFontScope extends StatelessWidget {
  const HomeEntryFontScope({
    super.key,
    required this.fontFamily,
    required this.child,
  });

  final String? fontFamily;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String? family = fontFamily;
    if (family == null || family.isEmpty) {
      return child;
    }
    final ThemeData current = Theme.of(context);
    return Theme(
      data: current.copyWith(
        textTheme: current.textTheme.apply(fontFamily: family),
        primaryTextTheme: current.primaryTextTheme.apply(fontFamily: family),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontFamily: family),
        child: child,
      ),
    );
  }
}

/// 把小卡自己的設定套到精緻圖片卡。圖片網址由呼叫端決定，這裡不讀功能資料。
class SharedEntryRefinedCard extends StatelessWidget {
  const SharedEntryRefinedCard({
    super.key,
    required this.card,
    required this.style,
    required this.sourceId,
    required this.theme,
    required this.imageUrl,
    required this.onTap,
    this.icon = Icons.image_outlined,
    this.columns = 3,
  });

  final HomeSharedEntryCardSetting card;
  final HomeSharedEntryStyle style;
  final String sourceId;
  final HomeThemeModel theme;
  final String imageUrl;
  final VoidCallback onTap;
  final IconData icon;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final String placement = HomeSharedEntryPlacements.migrate(
      style.textPlacement,
    );
    final bool onImage =
        placement == HomeSharedEntryPlacements.center ||
        placement == HomeSharedEntryPlacements.insideBottom;
    final String position = switch (placement) {
      HomeSharedEntryPlacements.above => HomeDisplayTextPositions.above,
      HomeSharedEntryPlacements.outsideBelow => HomeDisplayTextPositions.below,
      _ => HomeDisplayTextPositions.overlay,
    };
    final bool titleCustom =
        card.titleColorMode == HomeSharedEntryColorModes.custom;
    final bool bodyCustom =
        card.bodyColorMode == HomeSharedEntryColorModes.custom;
    return HomeEntryFontScope(
      fontFamily: style.appliedFontFamily,
      child: RefinedImageEntryCard(
        cardKey: Key('shared-entry-$sourceId'),
        featureId: sourceId,
        theme: theme,
        title: card.title,
        subtitle: card.subtitle,
        showTitle: card.showTitle,
        showSubtitle: card.showSubtitle,
        textMode: HomeRoomSimpleTextModes.below,
        textAlign: HomeRoomSimpleTextAligns.center,
        textSize: style.titleSize,
        textWeight: style.titleWeight,
        textColor: titleCustom
            ? HomeRoomSimpleTextColors.custom
            : HomeRoomSimpleTextColors.dark,
        textColorValue: titleCustom ? card.textColor : null,
        aspect: style.aspect,
        radius: style.radius,
        mask: style.mask,
        imageUrl: imageUrl,
        surface: style.surface,
        textPosition: position,
        bodySize: style.bodySize,
        bodyWeight: style.bodyWeight,
        bodyColorValue: bodyCustom ? card.bodyColor : null,
        bodyUsesTitleColor: false,
        contentAlign: placement == HomeSharedEntryPlacements.center
            ? 'center'
            : style.textAlign,
        imageFit: style.imageFit,
        showBorder: style.showBorder,
        cardShadow: style.cardShadow,
        showTextScrim:
            onImage &&
            style.textScrim &&
            style.mask != HomeRoomSimpleMasks.none,
        paintMaskOffImage: true,
        detachImage: !onImage,
        compactEmptyIcon: true,
        imageTextGap: style.gapText,
        contentScale: style.imageScale,
        maxContentWidth: columns <= 1 ? kSharedEntrySingleColumnCap : null,
        iconExtent: style.iconSize,
        overlayAlignment: onImage
            ? _overlayAlignment(placement, style.textAlign)
            : null,
        sizeMode: RefinedEntrySizeMode.slot,
        placeholderIcon: icon,
        onTap: onTap,
      ),
    );
  }

  Alignment _overlayAlignment(String placement, String align) {
    if (placement == HomeSharedEntryPlacements.center) {
      return Alignment.center;
    }
    return switch (align) {
      'end' => Alignment.bottomRight,
      'center' => Alignment.bottomCenter,
      _ => Alignment.bottomLeft,
    };
  }
}
