// 功能：正式房型介紹列表與後台預覽共用，圖片比例不決定整張卡片高度。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'room_intro_facts.dart';
import 'room_intro_browsers.dart';
import 'room_intro_comparison.dart';

class RoomIntroList extends StatelessWidget {
  const RoomIntroList({
    super.key,
    required this.rooms,
    required this.setting,
    required this.theme,
    required this.onOpen,
    this.onCompare,
    this.showComparison = true,
  });
  final VoidCallback? onCompare;
  final bool showComparison;
  final List<Map<String, dynamic>> rooms;
  final RoomListAppearance setting;
  final HomeThemeModel theme;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(
        MediaQuery.textScalerOf(context).scale(1) * setting.look.scale,
      ),
    ),
    child: _content(context),
  );
  Widget _content(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final ordered = setting.ordered(rooms);
      final layout = !showComparison && setting.layout == 'comparison'
          ? 'vertical'
          : setting.layout;
      final gap = roomSectionGap(setting.spacing);
      final width = constraints.maxWidth.clamp(
        0.0,
        ['columns', 'lodging', 'comparison', 'switcher'].contains(layout)
            ? 1200.0
            : 760.0,
      );
      final grid = ['columns', 'lodging'].contains(layout);
      final count =
          grid &&
              width >= 320 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.2
          ? (width / 260).floor().clamp(2, 4)
          : 1;
      final columns = count > 1;
      final cardWidth = (width - gap * (count - 1)) / count;
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                setting.title,
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              if (setting.showDescription &&
                  setting.description.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    setting.description,
                    style: TextStyle(color: theme.secondaryTextColor),
                  ),
                ),
              SizedBox(height: gap),
              if (ordered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('目前尚無房型介紹'),
                ),
              if (showComparison && onCompare != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onCompare,
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('比較房型'),
                  ),
                ),
              if (layout == 'comparison')
                RoomIntroComparison(
                  rooms: ordered,
                  theme: theme,
                  onOpen: onOpen,
                )
              else if (['carousel', 'switcher'].contains(layout))
                RoomIntroBrowser(
                  rooms: ordered,
                  layout: layout,
                  card: (r) =>
                      _card(context, r, horizontal: false, narrow: false),
                )
              else
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final r in ordered)
                      SizedBox(
                        width: cardWidth,
                        child: _card(
                          context,
                          r,
                          horizontal: setting.layout == 'horizontal',
                          narrow: columns,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
  Widget _card(
    BuildContext context,
    Map<String, dynamic> room, {
    required bool horizontal,
    required bool narrow,
  }) {
    final facts = RoomIntroFacts(room);
    final photos = facts.photos;
    final photo = photos.isEmpty
        ? SizedBox(
            height: horizontal || narrow ? 110 : 180,
            child: _placeholder(),
          )
        : AspectRatio(
            aspectRatio: roomImageRatio(setting.imageAspect),
            child: setting.layout == 'lodging'
                ? RoomIntroPhotoPager(
                    key: ValueKey(facts.id),
                    urls: photos,
                    fit: setting.imageFit == 'contain'
                        ? BoxFit.contain
                        : BoxFit.cover,
                  )
                : Image.network(
                    photos.first,
                    fit: setting.imageFit == 'contain'
                        ? BoxFit.contain
                        : BoxFit.cover,
                    errorBuilder: (_, error, stack) => _placeholder(),
                  ),
          );
    final copy = Padding(
      padding: EdgeInsets.all(setting.look.padding),
      child: Column(
        crossAxisAlignment: setting.look.align == 'center'
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (room['name'] ?? '未命名房型').toString(),
            style: TextStyle(
              fontSize: narrow ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          if (setting.layout == 'lodging' && setting.showCapacity)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                facts.capacity,
                style: TextStyle(color: theme.secondaryTextColor),
              ),
            ),
          Text(
            facts.price,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          if (setting.layout != 'lodging' && setting.showCapacity)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                facts.capacity,
                style: TextStyle(color: theme.secondaryTextColor),
              ),
            ),
          if (setting.look.showDimensions && facts.dimensions.isNotEmpty)
            Text(facts.dimensions),
          if (setting.showFeatures) _features(room),
          const SizedBox(height: 10),
          if (setting.buttonStyle == 'text')
            TextButton(
              onPressed: () => onOpen(room),
              child: const Text('查看房型介紹 →'),
            )
          else if (setting.buttonStyle == 'filled')
            FilledButton(
              onPressed: () => onOpen(room),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('查看房型介紹'),
            )
          else
            FilledButton.tonal(
              onPressed: () => onOpen(room),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primaryColor.withValues(alpha: .12),
                foregroundColor: theme.primaryColor,
              ),
              child: const Text('查看房型介紹'),
            ),
        ],
      ),
    );
    return Material(
      key: ValueKey('room-intro-card-${room['id']}'),
      elevation: setting.look.shadow ? 3 : 0,
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(setting.look.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(room),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(setting.look.radius),
            border: setting.look.border
                ? Border.all(color: theme.cardBorderColor)
                : null,
            boxShadow: setting.look.shadow
                ? [
                    const BoxShadow(
                      color: Color(0x15000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: LayoutBuilder(
            builder: (context, c) => horizontal && c.maxWidth >= 310
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: c.maxWidth * .34, child: photo),
                      Expanded(child: copy),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [photo, copy],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _features(Map<String, dynamic> room) {
    final keys = RoomIntroFacts(room).features.take(3).toList();
    return keys.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              keys.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.secondaryTextColor),
            ),
          );
  }

  Widget _placeholder() => ColoredBox(
    color: theme.primaryColor.withValues(alpha: .08),
    child: Center(
      child: Icon(Icons.bed_outlined, color: theme.primaryColor, size: 36),
    ),
  );
}
