import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared by the customer room page and the live shop preview.
class RoomDetailPhotoGallery extends StatelessWidget {
  const RoomDetailPhotoGallery({
    super.key,
    required this.layout,
    required this.count,
    required this.selected,
    required this.showThumbnails,
    required this.aspectRatio,
    required this.radius,
    required this.accent,
    required this.main,
    required this.imageBuilder,
    required this.onSelected,
    required this.onOpen,
  });

  final String layout;
  final int count, selected;
  final bool showThumbnails;
  final double aspectRatio, radius;
  final Color accent;
  final Widget main;
  final Widget Function(int) imageBuilder;
  final ValueChanged<int> onSelected, onOpen;

  Widget _tile(int index, {bool thumbnail = false}) => Semantics(
    label: '照片 ${index + 1}，共 $count 張',
    button: true,
    selected: thumbnail ? index == selected : null,
    child: Material(
      color: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(math.min(radius, 12)),
        side: BorderSide(
          color: thumbnail && index == selected ? accent : Colors.transparent,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>(
          'room-photo-${thumbnail ? 'thumb' : 'tile'}-$index',
        ),
        onTap: () => thumbnail ? onSelected(index) : onOpen(index),
        child: Padding(
          padding: EdgeInsets.all(thumbnail ? 2 : 0),
          child: imageBuilder(index),
        ),
      ),
    ),
  );

  Widget _thumbnails({bool vertical = false}) => SizedBox(
    height: vertical ? null : 64,
    width: vertical ? 64 : null,
    child: ListView.separated(
      primary: false,
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      itemCount: count,
      separatorBuilder: (_, index) =>
          SizedBox(width: vertical ? 0 : 8, height: vertical ? 8 : 0),
      itemBuilder: (_, index) =>
          SizedBox(width: 72, height: 64, child: _tile(index, thumbnail: true)),
    ),
  );

  Widget _navigation() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      IconButton(
        tooltip: '上一張照片',
        onPressed: () => onSelected((selected - 1 + count) % count),
        icon: const Icon(Icons.chevron_left),
      ),
      Text('${selected + 1} / $count'),
      IconButton(
        tooltip: '下一張照片',
        onPressed: () => onSelected((selected + 1) % count),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return main;
    return LayoutBuilder(
      builder: (context, c) {
        final height = math.min(c.maxWidth / aspectRatio, 340.0);
        if (layout == 'grid') {
          final columns = c.maxWidth >= 640 ? 3 : 2;
          final width = (c.maxWidth - 8 * (columns - 1)) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (int i = 0; i < count; i++)
                SizedBox(
                  width: count == 1 ? c.maxWidth : width,
                  height: width / aspectRatio,
                  child: _tile(i),
                ),
            ],
          );
        }
        if (layout == 'collage') {
          final visible = math.min(count - 1, c.maxWidth >= 600 ? 4 : 2);
          return SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(flex: 2, child: _tile(0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      for (int i = 1; i <= visible; i++) ...<Widget>[
                        if (i > 1) const SizedBox(height: 8),
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              _tile(i),
                              if (i == visible && count > visible + 1)
                                Positioned.fill(
                                  child: Material(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(
                                      math.min(radius, 12),
                                    ),
                                    child: InkWell(
                                      onTap: () => _showAll(context),
                                      child: Center(
                                        child: Text(
                                          '查看全部 $count 張',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        Widget gallery = main;
        if (showThumbnails && (layout == 'left' || layout == 'right')) {
          final strip = _thumbnails(vertical: true);
          gallery = SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (layout == 'left') ...<Widget>[
                  strip,
                  const SizedBox(width: 8),
                ],
                Expanded(child: main),
                if (layout == 'right') ...<Widget>[
                  const SizedBox(width: 8),
                  strip,
                ],
              ],
            ),
          );
        } else if (showThumbnails && layout == 'overlay') {
          gallery = Stack(
            children: <Widget>[
              main,
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _thumbnails(),
                ),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            gallery,
            _navigation(),
            if (showThumbnails &&
                !<String>['left', 'right', 'overlay'].contains(
                  layout,
                )) ...<Widget>[const SizedBox(height: 8), _thumbnails()],
          ],
        );
      },
    );
  }

  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            children: <Widget>[
              ListTile(
                title: Text('全部照片（$count 張）'),
                trailing: IconButton(
                  tooltip: '關閉相簿',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    childAspectRatio: aspectRatio,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: count,
                  itemBuilder: (_, index) => _tile(index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
