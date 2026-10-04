import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

/// 新版首頁房型展示。正式前台與外觀預覽共用這一個元件。
class ModernHomeRoomSection extends StatelessWidget {
  const ModernHomeRoomSection({
    super.key,
    required this.theme,
    required this.setting,
    required this.roomTypes,
    required this.preview,
    this.loadFailed = false,
    this.selectedRoomTypeId,
    this.onSelectRoomType,
    this.onOpenRoom,
    this.onOpenAllRooms,
    this.onManageRooms,
  });

  final HomeThemeModel theme;
  final HomeRoomSectionSetting setting;
  final List<Map<String, dynamic>> roomTypes;
  final bool preview;
  final bool loadFailed;
  final String? selectedRoomTypeId;
  final ValueChanged<String>? onSelectRoomType;
  final ValueChanged<Map<String, dynamic>>? onOpenRoom;
  final VoidCallback? onOpenAllRooms;
  final VoidCallback? onManageRooms;

  String get _title {
    final String title = setting.title.trim();
    return title.isEmpty ? '房型介紹' : title;
  }

  Map<String, Map<String, dynamic>> get _byId {
    final Map<String, Map<String, dynamic>> rooms =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> room in roomTypes) {
      final String id = HomeRoomSectionSetting.roomTypeIdOf(room);
      if (id.isNotEmpty) {
        rooms[id] = room;
      }
    }
    return rooms;
  }

  @override
  Widget build(BuildContext context) {
    if (loadFailed) {
      return _message('房型資料讀取失敗');
    }
    final bool published = HomeRoomSectionSetting.hasPublishedRooms(roomTypes);
    if (!published) {
      if (!preview) {
        return const SizedBox.shrink();
      }
      return _emptyPreview();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (setting.layout != HomeRoomSectionLayouts.simpleEntry) _header(),
        if (setting.layout != HomeRoomSectionLayouts.simpleEntry)
          const SizedBox(height: 9),
        _body(),
      ],
    );
  }

  Widget _header() {
    final bool titleAction =
        setting.layout == HomeRoomSectionLayouts.cardGrid &&
        setting.compact.allRoomsPlacement ==
            HomeRoomAllRoomsPlacements.titleRight;
    return Row(
      children: <Widget>[
        Icon(
          Icons.bedroom_parent_outlined,
          size: 16,
          color: theme.primaryColor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
        ),
        if (titleAction)
          TextButton(
            onPressed: _openAll,
            child: Text(
              '全部房型',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: theme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _body() {
    final Map<String, Map<String, dynamic>> rooms = _byId;
    switch (setting.layout) {
      case HomeRoomSectionLayouts.simpleEntry:
        return _simpleEntry();
      case HomeRoomSectionLayouts.cardGrid:
        return _cardGrid(rooms);
      default:
        return _horizontal(rooms);
    }
  }

  Widget _horizontal(Map<String, Map<String, dynamic>> rooms) {
    final List<String> ids = setting.homeRoomIds(roomTypes);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320;
        final double cardWidth = (maxWidth * 0.42).clamp(112.0, 168.0);
        final double textScale = MediaQuery.textScalerOf(context).scale(1);
        final double imageHeight = 70;
        final double cardHeight =
            imageHeight + 18 + (setting.showPrice ? 40 : 24) * textScale;
        return SizedBox(
          height: cardHeight,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const <PointerDeviceKind>{
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.separated(
                key: const Key('home-room-scroll'),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                primary: false,
                itemCount: ids.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) {
                  if (index == ids.length) {
                    return SizedBox(
                      width: 88,
                      child: _allRoomsCard(
                        fullWidth: false,
                        imageHeight: imageHeight,
                      ),
                    );
                  }
                  final String id = ids[index];
                  final Map<String, dynamic>? room = rooms[id];
                  if (room == null) {
                    return const SizedBox.shrink();
                  }
                  return SizedBox(
                    width: cardWidth,
                    child: _roomCard(
                      room: room,
                      roomTypeId: id,
                      imageHeight: imageHeight,
                      overlay: false,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cardGrid(Map<String, Map<String, dynamic>> rooms) {
    final List<String> ids = setting.homeRoomIds(roomTypes);
    final bool fillWithAllRooms =
        setting.compact.allRoomsPlacement == HomeRoomAllRoomsPlacements.endCard;
    if (ids.isEmpty) {
      if (!fillWithAllRooms) {
        return const SizedBox.shrink();
      }
      return _allRoomsCard(fullWidth: true, imageHeight: 96);
    }
    final bool overlay =
        setting.mixed.textPlacement == HomeRoomMixedTextPlacements.overlay;
    final List<List<HomeRoomSlot>> rows = HomeRoomSectionSetting.mixedRows(
      roomIds: ids,
      sizeOf: setting.mixed.sizeOf,
      fillWithAllRooms: fillWithAllRooms,
    );
    return Column(
      children: <Widget>[
        for (int index = 0; index < rows.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 8),
          _row(
            rows[index],
            rooms,
            imageHeightFor: (HomeRoomSlot slot) {
              if (slot.size == HomeRoomCardSizes.single) {
                return HomeRoomImageHeights.singlePixels(
                  setting.mixed.largeImageHeight,
                );
              }
              return HomeRoomImageHeights.compactPixels(
                setting.mixed.smallImageHeight,
              );
            },
            overlay: overlay,
          ),
        ],
      ],
    );
  }

  Widget _row(
    List<HomeRoomSlot> slots,
    Map<String, Map<String, dynamic>> rooms, {
    required double Function(HomeRoomSlot slot) imageHeightFor,
    required bool overlay,
  }) {
    if (slots.length == 1 && slots.first.fullWidth) {
      return _slot(
        slots.first,
        rooms,
        imageHeight: imageHeightFor(slots.first),
        overlay: overlay,
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int index = 0; index < slots.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: _slot(
                slots[index],
                rooms,
                imageHeight: imageHeightFor(slots[index]),
                overlay: overlay,
              ),
            ),
          ],
          if (slots.length == 1) const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _slot(
    HomeRoomSlot slot,
    Map<String, Map<String, dynamic>> rooms, {
    required double imageHeight,
    required bool overlay,
  }) {
    if (slot.allRooms) {
      return _allRoomsCard(fullWidth: slot.fullWidth, imageHeight: imageHeight);
    }
    final Map<String, dynamic>? room = rooms[slot.roomTypeId];
    if (room == null) {
      return const SizedBox.shrink();
    }
    return _roomCard(
      room: room,
      roomTypeId: slot.roomTypeId!,
      imageHeight: imageHeight,
      overlay: overlay && slot.size != HomeRoomCardSizes.wide,
      layoutSize: slot.size,
      nameMaxLines: 2,
    );
  }

  Widget _simpleEntry() {
    final String size = HomeRoomSimpleCardSizes.migrate(
      setting.simple.cardSize,
    );
    if (size == HomeRoomSimpleCardSizes.small) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double parent = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 320;
          double width = parent * 0.5;
          if (width > 200) {
            width = 200;
          }
          if (width > parent) {
            width = parent;
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: width,
              child: _simpleShell(child: _simpleSmallEntry()),
            ),
          );
        },
      );
    }
    return _simpleShell(
      child: size == HomeRoomSimpleCardSizes.single
          ? _simpleSingleEntry()
          : _simpleWideEntry(),
    );
  }

  Widget _simpleShell({required Widget child}) {
    final Color fill = switch (setting.simple.surface) {
      HomeRoomSimpleSurfaces.transparent => Colors.transparent,
      HomeRoomSimpleSurfaces.outlined => theme.backgroundColor,
      _ => theme.cardColor,
    };
    final Border? border =
        setting.simple.surface == HomeRoomSimpleSurfaces.transparent
        ? null
        : Border.all(color: theme.cardBorderColor);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('home-room-simple'),
        borderRadius: BorderRadius.circular(14),
        onTap: _openAll,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _simpleIconBox({double box = 40, double icon = 22}) {
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _simpleIcon(setting.simple.icon),
        color: theme.primaryColor,
        size: icon,
      ),
    );
  }

  Widget _simpleTitle({int maxLines = 2, double fontSize = 15}) {
    return Text(
      _title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: theme.textColor,
      ),
    );
  }

  Widget _simpleSubtitle({required int maxLines}) {
    if (!setting.simple.showSubtitle) {
      return const SizedBox.shrink();
    }
    return Text(
      setting.simple.subtitle,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        height: 1.2,
        color: theme.secondaryTextColor,
      ),
    );
  }

  Widget _simpleSmallEntry() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _simpleIconBox(box: 32, icon: 18),
          const SizedBox(height: 8),
          _simpleTitle(fontSize: 13),
          if (setting.simple.showSubtitle) ...<Widget>[
            const SizedBox(height: 2),
            _simpleSubtitle(maxLines: 2),
          ],
        ],
      ),
    );
  }

  Widget _simpleSingleEntry() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              _simpleIconBox(),
              const SizedBox(width: 12),
              Expanded(child: _simpleTitle()),
            ],
          ),
          if (setting.simple.showSubtitle) ...<Widget>[
            const SizedBox(height: 6),
            _simpleSubtitle(maxLines: 2),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  '查看全部房型',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _simpleWideEntry() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: <Widget>[
          _simpleIconBox(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _simpleTitle(),
                if (setting.simple.showSubtitle) ...<Widget>[
                  const SizedBox(height: 2),
                  _simpleSubtitle(maxLines: 1),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.primaryColor),
        ],
      ),
    );
  }

  Widget _roomCard({
    required Map<String, dynamic> room,
    required String roomTypeId,
    required double imageHeight,
    required bool overlay,
    String? layoutSize,
    int nameMaxLines = 1,
  }) {
    final String name = (room['name'] ?? '未命名房型').toString().trim();
    final String imageUrl = _firstImage(room);
    final bool selected = selectedRoomTypeId == roomTypeId;
    final String price = HomeRoomSectionSetting.priceLabel(room['price']);
    final bool wide = layoutSize == HomeRoomCardSizes.wide;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('home-room-card-$roomTypeId'),
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (preview) {
            onSelectRoomType?.call(roomTypeId);
            return;
          }
          onOpenRoom?.call(room);
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? theme.primaryColor : theme.cardBorderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: wide
              ? _wideCard(
                  roomTypeId: roomTypeId,
                  name: name,
                  price: price,
                  imageUrl: imageUrl,
                )
              : overlay
              ? _overlayCard(
                  name: name,
                  price: price,
                  imageUrl: imageUrl,
                  imageHeight: imageHeight,
                  nameMaxLines: nameMaxLines,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    HomeRoomCover(
                      imageUrl: imageUrl,
                      height: imageHeight,
                      theme: theme,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                      child: _caption(
                        name: name,
                        price: price,
                        onImage: false,
                        nameMaxLines: nameMaxLines,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _wideCard({
    required String roomTypeId,
    required String name,
    required String price,
    required String imageUrl,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320;
        double imageWidth = maxWidth * 0.36;
        if (imageWidth > 136) {
          imageWidth = 136;
        }
        if (imageWidth > maxWidth * 0.46) {
          imageWidth = maxWidth * 0.46;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: imageWidth,
              child: HomeRoomCover(
                imageUrl: imageUrl,
                height: 108,
                theme: theme,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(13),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _caption(
                      name: name,
                      price: price,
                      onImage: false,
                      nameMaxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            '查看房型',
                            key: Key('home-room-wide-hint-$roomTypeId'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _overlayCard({
    required String name,
    required String price,
    required String imageUrl,
    required double imageHeight,
    int nameMaxLines = 1,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      child: SizedBox(
        height: imageHeight,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            HomeRoomCover(
              imageUrl: imageUrl,
              height: imageHeight,
              theme: theme,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x00000000), Color(0xB3000000)],
                  stops: <double>[0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: _caption(
                name: name,
                price: price,
                onImage: true,
                nameMaxLines: nameMaxLines,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _caption({
    required String name,
    required String price,
    required bool onImage,
    int nameMaxLines = 1,
  }) {
    final Color nameColor = onImage ? Colors.white : theme.textColor;
    final Color priceColor = onImage ? Colors.white : theme.primaryColor;
    final bool showPrice =
        setting.showPrice &&
        setting.layout != HomeRoomSectionLayouts.simpleEntry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          name.isEmpty ? '未命名房型' : name,
          maxLines: nameMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: nameColor,
          ),
        ),
        if (showPrice) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            price,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: priceColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _allRoomsCard({required bool fullWidth, required double imageHeight}) {
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('home-room-all'),
        borderRadius: BorderRadius.circular(14),
        onTap: _openAll,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: fullWidth ? 72 : imageHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.meeting_room_outlined,
                    color: theme.primaryColor,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '查看全部房型',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyPreview() {
    return Container(
      key: const Key('home-room-empty-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '目前尚未建立已發布房型',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onManageRooms, child: const Text('前往房型管理')),
        ],
      ),
    );
  }

  Widget _message(String text) {
    return Container(
      width: double.infinity,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
      ),
    );
  }

  void _openAll() {
    if (preview) {
      onSelectRoomType?.call('');
      return;
    }
    onOpenAllRooms?.call();
  }

  static String _firstImage(Map<String, dynamic> room) {
    final Object? raw = room['images'];
    if (raw is! List) {
      return '';
    }
    for (final Object? item in raw) {
      final String url = item?.toString().trim() ?? '';
      if (url.isNotEmpty) {
        return url;
      }
    }
    return '';
  }

  static IconData _simpleIcon(String icon) {
    switch (icon) {
      case HomeRoomSimpleIcons.home:
        return Icons.home_outlined;
      case HomeRoomSimpleIcons.hotel:
        return Icons.holiday_village_outlined;
      default:
        return Icons.bed_outlined;
    }
  }
}

class HomeRoomCover extends StatelessWidget {
  const HomeRoomCover({
    super.key,
    required this.imageUrl,
    required this.height,
    required this.theme,
    this.imageProvider,
    this.borderRadius = _topRadius,
  });

  final String imageUrl;
  final double height;
  final HomeThemeModel theme;
  final ImageProvider<Object>? imageProvider;
  final BorderRadius borderRadius;

  static const BorderRadius _topRadius = BorderRadius.vertical(
    top: Radius.circular(13),
  );

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? provider = imageProvider;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: provider != null
            ? Image(
                image: provider,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _fallback(),
              )
            : imageUrl.isEmpty
            ? _fallback()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: theme.primaryColor.withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          Icons.bedroom_parent_outlined,
          key: const Key('home-room-fallback-icon'),
          size: 28,
          color: theme.primaryColor,
        ),
      ),
    );
  }
}
