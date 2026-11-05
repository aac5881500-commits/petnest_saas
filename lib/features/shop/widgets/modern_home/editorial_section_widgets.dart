import '../environment/environment_photo.dart';
import 'home_desktop_layout.dart';
import '../room/room_feature_tags.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

/// Building blocks for the existing home sections, independent of any preset.
Widget sectionPhoto(
  String url, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
}) => url.isEmpty
    ? const ColoredBox(
        color: Color(0xFFF4EADD),
        child: Center(child: Icon(Icons.add_photo_alternate_outlined)),
      )
    : EnvironmentPhoto(imageUrl: url, fit: fit, alignment: alignment);

Text editorialText(
  String value,
  double size,
  HomeThemeModel theme, {
  bool bold = false,
  int? lines,
  Color? color,
  String? fontFamily,
}) => Text(
  value,
  maxLines: lines,
  overflow: lines == null ? null : TextOverflow.ellipsis,
  style: TextStyle(
    fontFamily: fontFamily ?? 'NotoSansTC',
    fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
    fontVariations: [FontVariation('wght', bold ? 800 : 450)],
    fontSize: size,
    height: 1.35,
    color: color ?? theme.textColor,
  ),
);

class EditorialSectionHeading extends StatelessWidget {
  const EditorialSectionHeading({
    super.key,
    required this.title,
    required this.theme,
    this.trailing,
    this.accent = true,
    this.fontFamily,
  });
  final String title;
  final HomeThemeModel theme;
  final Widget? trailing;
  final bool accent;
  final String? fontFamily;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (accent)
        Container(
          width: 3,
          height: HomeDesktopLayoutScope.maybeOf(context) == null ? 17 : 24,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: theme.primaryColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      Expanded(
        child: editorialText(
          title,
          HomeDesktopLayoutScope.maybeOf(context) == null ? 17 : 22,
          theme,
          bold: true,
          fontFamily: fontFamily,
        ),
      ),
      ?trailing,
    ],
  );
}

class EnvironmentHighlightCards extends StatelessWidget {
  const EnvironmentHighlightCards({
    super.key,
    required this.items,
    required this.theme,
    required this.onOpen,
    this.outlined = true,
    this.photoHeight = 100,
  });
  final List<Map<String, dynamic>> items;
  final HomeThemeModel theme;
  final VoidCallback onOpen;
  final bool outlined;
  final double photoHeight;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final desktop = HomeDesktopLayoutScope.maybeOf(context);
      final u = desktop?.cardScale ?? c.maxWidth / 790;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: 20 * u),
            Expanded(
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(18 * u),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * u,
                    vertical: 16 * u,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18 * u),
                    border: outlined
                        ? Border.all(
                            color: theme.primaryColor.withValues(alpha: .30),
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height:
                            (items[i]['imageUrl'] ?? '').toString().isNotEmpty
                            ? photoHeight
                            : 78 * u,
                        width: double.infinity,
                        child:
                            (items[i]['imageUrl'] ?? '').toString().isNotEmpty
                            ? sectionPhoto(
                                '${items[i]['imageUrl']}',
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                items[i]['iconData'] as IconData? ??
                                    Icons.pets_outlined,
                                size: 70 * u,
                                color: theme.primaryColor,
                              ),
                      ),
                      SizedBox(height: 8 * u),
                      editorialText(
                        '${items[i]['title'] ?? ''}',
                        26 * u,
                        theme,
                        bold: true,
                        lines: 1,
                      ),
                      SizedBox(height: 4 * u),
                      editorialText(
                        '${items[i]['description'] ?? ''}',
                        21 * u,
                        theme,
                        lines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class EditorialRoomStrip extends StatelessWidget {
  const EditorialRoomStrip({
    super.key,
    required this.rooms,
    required this.theme,
    required this.title,
    required this.onRoom,
    required this.onAll,
    this.showPrice = true,
    this.columns = 2,
    this.fontFamily,
    this.headerTrailing,
    this.headingAccent = true,
    this.imageRatio = 1.62,
  });
  final List<Map<String, dynamic>> rooms;
  final HomeThemeModel theme;
  final String title;
  final void Function(Map<String, dynamic>) onRoom;
  final VoidCallback onAll;
  final bool showPrice;
  final int columns;
  final String? fontFamily;
  final Widget? headerTrailing;
  final bool headingAccent;
  final double imageRatio;
  String photo(Map<String, dynamic> r) {
    for (final key in ['coverImageUrl', 'imageUrl', 'photoUrl']) {
      if ((r[key] ?? '').toString().isNotEmpty) return '${r[key]}';
    }
    for (final key in ['images', 'photos', 'imageUrls']) {
      final values = r[key];
      if (values is List && values.isNotEmpty) {
        final v = values.first;
        return v is Map ? '${v['url'] ?? v['imageUrl'] ?? ''}' : '$v';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final desktop = HomeDesktopLayoutScope.maybeOf(context);
      final u = desktop?.cardScale ?? c.maxWidth / 790;
      final count = desktop?.columnsForWidth(c.maxWidth) ?? columns;
      final width = (c.maxWidth - 16 * u * (count - 1)) / count;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialSectionHeading(
            title: title,
            theme: theme,
            accent: headingAccent,
            fontFamily: fontFamily,
            trailing:
                headerTrailing ??
                TextButton(
                  onPressed: onAll,
                  child: Text(
                    '查看全部房型 ›',
                    style: TextStyle(
                      fontSize: desktop == null ? 12 : 14,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
          ),
          SizedBox(height: 8 * u),
          SizedBox(
            height: width / imageRatio + 198 * u,
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                scrollbars: false,
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: rooms.length,
                separatorBuilder: (_, _) => SizedBox(width: 16 * u),
                itemBuilder: (_, i) {
                  final r = rooms[i];
                  final tags = <String>[
                    for (final v
                        in ((r['tags'] ?? r['features']) as List? ?? const []))
                      (RoomFeatureTags.featureOptions[v]?['name'] ?? v)
                          .toString(),
                    for (final v in (r['customFeatures'] as List? ?? const []))
                      if (v is Map && (v['name'] ?? '').toString().isNotEmpty)
                        v['name'].toString(),
                  ].take(3).toList();
                  return SizedBox(
                    width: width,
                    child: InkWell(
                      onTap: () => onRoom(r),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18 * u),
                          border: Border.all(
                            color: theme.primaryColor.withValues(alpha: .14),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: width / imageRatio,
                              child: sectionPhoto(photo(r)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(14 * u),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: editorialText(
                                          '${r['name'] ?? ''}',
                                          27 * u,
                                          theme,
                                          fontFamily: fontFamily,
                                          bold: true,
                                          lines: 1,
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 24 * u,
                                        color: theme.textColor,
                                      ),
                                    ],
                                  ),
                                  if ((r['description'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    editorialText(
                                      '${r['description']}',
                                      21 * u,
                                      theme,
                                      fontFamily: fontFamily,
                                      lines: 1,
                                    ),
                                  if (showPrice)
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 7 * u,
                                      ),
                                      child: editorialText(
                                        'NT\$${r['price'] ?? 0}／晚',
                                        27 * u,
                                        theme,
                                        fontFamily: fontFamily,
                                        bold: true,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  Wrap(
                                    spacing: 8 * u,
                                    runSpacing: 4 * u,
                                    children: [
                                      for (final tag in tags)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12 * u,
                                            vertical: 4 * u,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: theme.primaryColor
                                                  .withValues(alpha: .3),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: editorialText(
                                            tag,
                                            18 * u,
                                            theme,
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
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
          ),
          if (headerTrailing != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAll,
                child: Text(
                  '查看全部房型 ›',
                  style: TextStyle(color: theme.primaryColor),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class EditorialAboutCard extends StatelessWidget {
  const EditorialAboutCard({
    super.key,
    required this.theme,
    required this.sectionTitle,
    required this.title,
    required this.body,
    required this.photo,
    required this.button,
    required this.onOpen,
    this.imageLeft = true,
    this.showImage = true,
    this.imageTop = false,
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.center,
    this.showButton = true,
    this.showArrow = true,
    this.showDecoration = true,
  });
  final HomeThemeModel theme;
  final String sectionTitle, title, body, photo, button;
  final VoidCallback onOpen;
  final bool imageLeft,
      showButton,
      showArrow,
      showDecoration,
      showImage,
      imageTop;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final desktop = HomeDesktopLayoutScope.maybeOf(context);
      final u = desktop?.cardScale ?? c.maxWidth / 790;
      final image = ClipRRect(
        borderRadius: BorderRadius.circular(18 * u),
        child: AspectRatio(
          aspectRatio: desktop == null
              ? 363 / 226
              : (c.maxWidth - 26 * u) / 2 / desktop.aboutPhotoHeight,
          child: sectionPhoto(photo, fit: imageFit, alignment: imageAlignment),
        ),
      );
      final copy = Stack(
        children: [
          if (showDecoration)
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(
                Icons.pets,
                size: 70 * u,
                color: theme.primaryColor.withValues(alpha: .16),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              editorialText(title, 27 * u, theme, bold: true),
              SizedBox(height: 8 * u),
              editorialText(body, 21 * u, theme),
              if (showButton)
                Padding(
                  padding: EdgeInsets.only(top: 8 * u),
                  child: OutlinedButton(
                    onPressed: onOpen,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                      side: BorderSide(color: theme.primaryColor),
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20 * u,
                        vertical: 8 * u,
                      ),
                    ),
                    child: Text(
                      '$button  ›',
                      style: TextStyle(fontSize: 21 * u),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialSectionHeading(title: sectionTitle, theme: theme),
          SizedBox(height: 14 * u),
          if (!showImage)
            copy
          else if (imageTop) ...[
            image,
            SizedBox(height: 14 * u),
            copy,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: imageLeft ? image : copy),
                SizedBox(width: 26 * u),
                Expanded(child: imageLeft ? copy : image),
              ],
            ),
        ],
      );
    },
  );
}
