import 'package:flutter/material.dart';
import '../../../../core/models/home_storybook_setting.dart';
import '../../../../core/models/home_theme_model.dart';
import 'editorial_section_widgets.dart';

/// Platform decoration only. It never supplies a business or pet photograph.
class HomeDiaryFlowers extends StatelessWidget {
  const HomeDiaryFlowers({super.key, this.width = 58, this.opacity = .8});
  final double width, opacity;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: width,
          height: width * .75,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomRight,
              minWidth: width * 4.1,
              maxWidth: width * 4.1,
              minHeight: width * 1.37,
              maxHeight: width * 1.37,
              child: Image.asset(
                HomeStorybookSetting.trimAsset,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class HomeDiaryNote extends StatelessWidget {
  const HomeDiaryNote({
    super.key,
    required this.theme,
    required this.child,
    this.blue = false,
    this.flowers = false,
    this.padding = const EdgeInsets.all(10),
  });
  final HomeThemeModel theme;
  final Widget child;
  final bool blue, flowers;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final s = theme.storybook.diary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.storybook.radius),
        gradient: LinearGradient(
          colors: [
            Color(
              blue ? theme.storybook.blueColor : theme.storybook.paperColor,
            ).withValues(alpha: .72),
            theme.backgroundColor.withValues(alpha: .3),
            Color(
              blue ? theme.storybook.blueColor : theme.storybook.paperColor,
            ).withValues(alpha: .65),
          ],
        ),
      ),
      child: Stack(
        children: [
          if (flowers && s.flowers)
            Positioned(
              right: 0,
              bottom: 0,
              child: HomeDiaryFlowers(opacity: s.decorationOpacity),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class HomeDiaryDoor extends StatelessWidget {
  const HomeDiaryDoor({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onOpen,
    this.blue = false,
  });
  final HomeThemeModel theme;
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onOpen;
  final bool blue;
  @override
  Widget build(BuildContext context) => HomeDiaryNote(
    theme: theme,
    blue: blue,
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
          child: Row(
            children: [
              Icon(icon, color: theme.textColor, size: 27),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: theme.storybook.diary.fontFamily,
                        fontFamilyFallback: const ['NotoSansTC'],
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.secondaryTextColor,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 15, color: theme.textColor),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeDiaryAbout extends StatelessWidget {
  const HomeDiaryAbout({
    super.key,
    required this.theme,
    required this.photo,
    required this.body,
    required this.onOpen,
    required this.button,
    this.title = '',
    this.showImage = true,
    this.showButton = true,
    this.imageLeft = true,
    this.imageTop = false,
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.center,
  });
  final HomeThemeModel theme;
  final String photo, body, button, title;
  final VoidCallback onOpen;
  final bool showImage, showButton, imageLeft, imageTop;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final s = theme.storybook.diary;
      final image = ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          height: s.refNumber('aboutPhotoHeight'),
          width: double.infinity,
          child: sectionPhoto(photo, fit: imageFit, alignment: imageAlignment),
        ),
      );
      final copy = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: TextStyle(
                  fontFamily: s.fontFamily,
                  fontFamilyFallback: const ['NotoSansTC'],
                  color: theme.textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            Text(
              body,
              style: TextStyle(
                fontFamily: s.fontFamily,
                fontFamilyFallback: const ['NotoSansTC'],
                fontSize: 14,
                height: 1.6,
                color: theme.textColor,
              ),
            ),
            if (showButton)
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '$button ›',
                  style: TextStyle(color: theme.primaryColor, fontSize: 11),
                ),
              ),
          ],
        ),
      );
      final stacked =
          imageTop ||
          c.maxWidth < 270 ||
          MediaQuery.textScalerOf(context).scale(14) > 23;
      return HomeDiaryNote(
        theme: theme,
        flowers: true,
        padding: EdgeInsets.zero,
        child: !showImage
            ? copy
            : stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [image, copy],
              )
            : Row(
                children: [
                  if (imageLeft)
                    Expanded(
                      flex: (s.refNumber('aboutFraction') * 100).round(),
                      child: image,
                    ),
                  Expanded(
                    flex: ((1 - s.refNumber('aboutFraction')) * 100).round(),
                    child: copy,
                  ),
                  if (!imageLeft)
                    Expanded(
                      flex: (s.refNumber('aboutFraction') * 100).round(),
                      child: image,
                    ),
                ],
              ),
      );
    },
  );
}

/// Compact two-card rail with working arrows and a separate all-rooms link.
class HomeDiaryRoomRail extends StatefulWidget {
  const HomeDiaryRoomRail({
    super.key,
    required this.theme,
    required this.rooms,
    required this.imageOf,
    required this.priceOf,
    required this.onRoom,
    required this.onAll,
  });
  final HomeThemeModel theme;
  final List<Map<String, dynamic>> rooms;
  final String Function(Map<String, dynamic>) imageOf, priceOf;
  final ValueChanged<Map<String, dynamic>> onRoom;
  final VoidCallback onAll;
  @override
  State<HomeDiaryRoomRail> createState() => _HomeDiaryRoomRailState();
}

class _HomeDiaryRoomRailState extends State<HomeDiaryRoomRail> {
  final controller = ScrollController();
  int active = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final theme = widget.theme, s = theme.storybook.diary;
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final cardWidth =
          c.maxWidth * (scale > 1.5 ? .8 : s.refNumber('roomFraction'));
      final h = s.refNumber('roomPhotoHeight');
      void move(int direction) {
        final next = (active + direction).clamp(0, widget.rooms.length - 1);
        controller.animateTo(
          ((cardWidth + 8) * next).clamp(
            0,
            controller.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: h + 61 * scale,
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    final next = (controller.offset / (cardWidth + 8)).round();
                    if (next != active) setState(() => active = next);
                    return false;
                  },
                  child: ListView.separated(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.rooms.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final room = widget.rooms[i];
                      return SizedBox(
                        width: cardWidth,
                        child: Material(
                          color: Color(
                            theme.storybook.paperColor,
                          ).withValues(alpha: .6),
                          borderRadius: BorderRadius.circular(11),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => widget.onRoom(room),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: h,
                                  child: sectionPhoto(widget.imageOf(room)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    5,
                                    8,
                                    0,
                                  ),
                                  child: Text(
                                    (room['name'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.textColor,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: s.fontFamily,
                                      fontFamilyFallback: const ['NotoSansTC'],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    widget.priceOf(room),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.rooms.length > 1) ...[
                  Positioned(
                    left: 0,
                    top: h / 2 - 13,
                    child: _arrow(Icons.chevron_left, () => move(-1)),
                  ),
                  Positioned(
                    right: 0,
                    top: h / 2 - 13,
                    child: _arrow(Icons.chevron_right, () => move(1)),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  for (int i = 0; i < widget.rooms.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: CircleAvatar(
                        radius: 2.5,
                        backgroundColor: active == i
                            ? theme.primaryColor
                            : theme.cardBorderColor,
                      ),
                    ),
                ],
              ),
              TextButton(
                onPressed: widget.onAll,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 0,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '全部房型 ›',
                  style: TextStyle(fontSize: 11, color: theme.primaryColor),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  Widget _arrow(IconData icon, VoidCallback onTap) => Material(
    color: const Color(0xFFFFF2D7),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(icon, size: 18, color: widget.theme.textColor),
      ),
    ),
  );
}

class HomeDiaryServices extends StatelessWidget {
  const HomeDiaryServices({super.key, required this.theme});
  final HomeThemeModel theme;
  @override
  Widget build(BuildContext context) => HomeDiaryNote(
    theme: theme,
    flowers: true,
    child: LayoutBuilder(
      builder: (context, c) => Wrap(
        spacing: 0,
        runSpacing: 8,
        children: [
          for (int i = 0; i < 3; i++)
            SizedBox(
              width:
                  c.maxWidth /
                  (MediaQuery.textScalerOf(context).scale(14) > 23 ? 1 : 3),
              child: Column(
                children: [
                  Icon(
                    [
                      Icons.cleaning_services_outlined,
                      Icons.pets_outlined,
                      Icons.assignment_outlined,
                    ][i],
                    size: 30,
                    color: theme.textColor,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    theme.storybook.diary.refText('service${i + 1}'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: theme.storybook.diary.fontFamily,
                      fontFamilyFallback: const ['NotoSansTC'],
                      fontSize: 13,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// Pure storefront card: price and stock are supplied by existing store logic.
class HomeDiaryProductCard extends StatelessWidget {
  const HomeDiaryProductCard({
    super.key,
    required this.theme,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.onOpen,
    this.badge,
    this.outOfStock = false,
  });
  final HomeThemeModel theme;
  final String name, imageUrl;
  final Widget price;
  final Widget? badge;
  final VoidCallback onOpen;
  final bool outOfStock;
  @override
  Widget build(BuildContext context) {
    final fraction = (theme.storybook.diary.refNumber('productFraction') * 100)
        .round();
    return HomeDiaryNote(
      theme: theme,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              Expanded(
                flex: fraction,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      sectionPhoto(imageUrl),
                      if (badge != null)
                        Positioned(top: 4, left: 4, child: badge!),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 100 - fraction,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: theme.storybook.diary.fontFamily,
                          fontFamilyFallback: const ['NotoSansTC'],
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                      price,
                      if (outOfStock)
                        Text(
                          '售罄',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.secondaryTextColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
