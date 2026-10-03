import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/room_section_layout_preview.dart';

/// 房型展示右側設定。版型、排序、顯示細節只改 draft。
class RoomSectionSettingsPanel extends StatefulWidget {
  const RoomSectionSettingsPanel({
    super.key,
    required this.shopId,
    required this.setting,
    required this.theme,
    required this.onChanged,
    this.rooms,
    this.selectedRoomTypeId,
    this.onManageRooms,
  });

  final String shopId;
  final HomeRoomSectionSetting setting;
  final HomeThemeModel theme;
  final ValueChanged<HomeRoomSectionSetting> onChanged;

  /// 測試或上層已有資料時直接傳入，不再另外訂閱。
  final List<Map<String, dynamic>>? rooms;
  final String? selectedRoomTypeId;
  final VoidCallback? onManageRooms;

  @override
  State<RoomSectionSettingsPanel> createState() =>
      _RoomSectionSettingsPanelState();
}

class _RoomSectionSettingsPanelState extends State<RoomSectionSettingsPanel> {
  int _pane = 0;
  List<Map<String, dynamic>> _rooms = <Map<String, dynamic>>[];
  Object? _roomsError;
  StreamSubscription<List<Map<String, dynamic>>>? _roomsSub;
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.setting.title);
    _subtitleController = TextEditingController(
      text: widget.setting.simple.subtitle,
    );
    if (widget.rooms != null) {
      _rooms = widget.rooms!;
      return;
    }
    _roomsSub = ShopService.instance
        .streamRoomTypes(widget.shopId)
        .listen(
          (List<Map<String, dynamic>> rooms) {
            if (!mounted) {
              return;
            }
            setState(() {
              _rooms = rooms;
              _roomsError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) {
              return;
            }
            setState(() => _roomsError = error);
          },
        );
  }

  @override
  void didUpdateWidget(RoomSectionSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rooms != null) {
      _rooms = widget.rooms!;
    }
    if (_titleController.text != widget.setting.title) {
      _titleController.text = widget.setting.title;
    }
    if (_subtitleController.text != widget.setting.simple.subtitle) {
      _subtitleController.text = widget.setting.simple.subtitle;
    }
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _catalog => widget.rooms ?? _rooms;

  Map<String, Map<String, dynamic>> get _byId {
    final Map<String, Map<String, dynamic>> rooms =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> room in _catalog) {
      final String id = HomeRoomSectionSetting.roomTypeIdOf(room);
      if (id.isNotEmpty) {
        rooms[id] = room;
      }
    }
    return rooms;
  }

  void _update(HomeRoomSectionSetting next) {
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: _panePicker(),
        ),
        if (widget.selectedRoomTypeId != null &&
            widget.selectedRoomTypeId!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              '目前選取：${_roomName(widget.selectedRoomTypeId!)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: widget.theme.primaryColor,
              ),
            ),
          ),
        Expanded(
          child: switch (_pane) {
            1 => _orderPane(),
            2 => _detailPane(),
            _ => _layoutPane(),
          },
        ),
      ],
    );
  }

  Widget _panePicker() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          primary: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(
                  value: 0,
                  label: Text('版型'),
                  icon: Icon(Icons.dashboard_customize_outlined),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text('房型排序'),
                  icon: Icon(Icons.swap_vert_rounded),
                ),
                ButtonSegment<int>(
                  value: 2,
                  label: Text('顯示細節'),
                  icon: Icon(Icons.tune),
                ),
              ],
              selected: <int>{_pane},
              onSelectionChanged: (Set<int> value) {
                setState(() => _pane = value.first);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _layoutPane() {
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: <Widget>[
        _choice(
          layout: HomeRoomSectionLayouts.horizontalScroll,
          description: '房型卡片單排顯示，可左右滑動查看更多房型。',
        ),
        _choice(
          layout: HomeRoomSectionLayouts.cardGrid,
          description: '預設一排兩張，也可將指定房型改成滿版大卡並自由排序。',
        ),
        _choice(
          layout: HomeRoomSectionLayouts.simpleEntry,
          description: '只留一張入口，不列出個別房型與價格。',
        ),
      ],
    );
  }

  Widget _choice({required String layout, required String description}) {
    final bool selected = widget.setting.layout == layout;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('room-layout-$layout'),
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (selected) {
              return;
            }
            _update(widget.setting.copyWith(layout: layout));
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? widget.theme.primaryColor
                    : const Color(0xFFE6E8EC),
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                RoomSectionLayoutPreview(layout: layout, theme: widget.theme),
                const SizedBox(height: 8),
                Text(
                  HomeRoomSectionLayouts.label(layout),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderPane() {
    if (_roomsError != null) {
      return const Center(child: Text('房型資料讀取失敗'));
    }
    final List<String> published = widget.setting.publishedIds(_catalog);
    if (published.isEmpty) {
      return ListView(
        primary: false,
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text('目前尚未建立已發布房型'),
          if (widget.onManageRooms != null)
            TextButton(
              onPressed: widget.onManageRooms,
              child: const Text('前往房型管理'),
            ),
        ],
      );
    }
    final bool mixed = widget.setting.layout == HomeRoomSectionLayouts.cardGrid;
    final bool simple =
        widget.setting.layout == HomeRoomSectionLayouts.simpleEntry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (simple)
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              '簡約入口不顯示個別房型。這份排序會在切回其他版型時沿用。',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        Expanded(
          child: ReorderableListView.builder(
            primary: false,
            buildDefaultDragHandles: false,
            itemCount: published.length,
            onReorder: (int oldIndex, int newIndex) {
              final List<String> saved = widget.setting.orderedIds(_catalog);
              final List<String> next = HomeRoomSectionSetting.reorder(
                saved: saved,
                visible: published,
                oldIndex: oldIndex,
                newIndex: newIndex,
              );
              if (_same(next, saved)) {
                return;
              }
              _update(widget.setting.copyWith(roomTypeOrder: next));
            },
            itemBuilder: (BuildContext context, int index) {
              final String id = published[index];
              return _orderTile(
                key: ValueKey<String>(id),
                id: id,
                index: index,
                mixed: mixed,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _orderTile({
    required Key key,
    required String id,
    required int index,
    required bool mixed,
  }) {
    final Map<String, dynamic> room = _byId[id] ?? <String, dynamic>{};
    final bool shown = !widget.setting.hiddenRoomTypeIds.contains(id);
    final bool touch = _touchPlatform(Theme.of(context).platform);
    final Widget handle = Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(
        Icons.drag_indicator_rounded,
        key: Key('room-drag-$id'),
        color: const Color(0xFF475569),
      ),
    );
    return Material(
      key: key,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                touch
                    ? ReorderableDelayedDragStartListener(
                        index: index,
                        child: handle,
                      )
                    : ReorderableDragStartListener(index: index, child: handle),
                _thumb(room),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _roomName(id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        shown ? '顯示於首頁' : '首頁已隱藏',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: shown,
                  onChanged: (bool value) {
                    final List<String> hidden = List<String>.from(
                      widget.setting.hiddenRoomTypeIds,
                    );
                    if (value) {
                      hidden.remove(id);
                    } else if (!hidden.contains(id)) {
                      hidden.add(id);
                    }
                    _update(widget.setting.copyWith(hiddenRoomTypeIds: hidden));
                  },
                ),
              ],
            ),
            if (mixed)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 44, top: 4),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: HomeRoomCardSizes.full,
                        label: Text('大卡'),
                      ),
                      ButtonSegment<String>(
                        value: HomeRoomCardSizes.half,
                        label: Text('小卡'),
                      ),
                    ],
                    selected: <String>{widget.setting.mixed.sizeOf(id)},
                    onSelectionChanged: (Set<String> value) {
                      final Map<String, String> sizes =
                          Map<String, String>.from(
                            widget.setting.mixed.itemSizes,
                          );
                      sizes[id] = value.first;
                      _update(
                        widget.setting.copyWith(
                          mixed: widget.setting.mixed.copyWith(
                            itemSizes: sizes,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailPane() {
    final String layout = widget.setting.layout;
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: <Widget>[
        TextField(
          controller: _titleController,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: '標題',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) {
            _update(widget.setting.copyWith(title: value.trim()));
          },
        ),
        if (layout != HomeRoomSectionLayouts.simpleEntry) ...<Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示價格'),
            value: widget.setting.showPrice,
            onChanged: (bool value) {
              _update(widget.setting.copyWith(showPrice: value));
            },
          ),
        ],
        if (layout == HomeRoomSectionLayouts.cardGrid) ...<Widget>[
          _label('全部房型入口'),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: HomeRoomAllRoomsPlacements.titleRight,
                label: Text('標題右側'),
              ),
              ButtonSegment<String>(
                value: HomeRoomAllRoomsPlacements.endCard,
                label: Text('最後一張卡片'),
              ),
            ],
            selected: <String>{widget.setting.compact.allRoomsPlacement},
            onSelectionChanged: (Set<String> value) {
              _update(
                widget.setting.copyWith(
                  compact: widget.setting.compact.copyWith(
                    allRoomsPlacement: value.first,
                  ),
                ),
              );
            },
          ),
        ],
        if (layout == HomeRoomSectionLayouts.simpleEntry) ...<Widget>[
          const SizedBox(height: 8),
          TextField(
            controller: _subtitleController,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '副標題',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) {
              _update(
                widget.setting.copyWith(
                  simple: widget.setting.simple.copyWith(
                    subtitle: value.trim(),
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示副標題'),
            value: widget.setting.simple.showSubtitle,
            onChanged: (bool value) {
              _update(
                widget.setting.copyWith(
                  simple: widget.setting.simple.copyWith(showSubtitle: value),
                ),
              );
            },
          ),
          _label('卡片樣式'),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: <ButtonSegment<String>>[
              for (final String surface in HomeRoomSimpleSurfaces.all)
                ButtonSegment<String>(
                  value: surface,
                  label: Text(HomeRoomSimpleSurfaces.label(surface)),
                ),
            ],
            selected: <String>{widget.setting.simple.surface},
            onSelectionChanged: (Set<String> value) {
              _update(
                widget.setting.copyWith(
                  simple: widget.setting.simple.copyWith(surface: value.first),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _label('左側圖示'),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: <ButtonSegment<String>>[
              for (final String icon in HomeRoomSimpleIcons.all)
                ButtonSegment<String>(
                  value: icon,
                  label: Text(HomeRoomSimpleIcons.label(icon)),
                ),
            ],
            selected: <String>{widget.setting.simple.icon},
            onSelectionChanged: (Set<String> value) {
              _update(
                widget.setting.copyWith(
                  simple: widget.setting.simple.copyWith(icon: value.first),
                ),
              );
            },
          ),
        ],
        if (layout == HomeRoomSectionLayouts.cardGrid) ...<Widget>[
          _label('文字位置'),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: HomeRoomMixedTextPlacements.below,
                label: Text('圖片下方'),
              ),
              ButtonSegment<String>(
                value: HomeRoomMixedTextPlacements.overlay,
                label: Text('圖片內'),
              ),
            ],
            selected: <String>{widget.setting.mixed.textPlacement},
            onSelectionChanged: (Set<String> value) {
              _update(
                widget.setting.copyWith(
                  mixed: widget.setting.mixed.copyWith(
                    textPlacement: value.first,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _label('大卡圖片高度'),
          _heightPicker(
            selected: widget.setting.mixed.largeImageHeight,
            onChanged: (String value) {
              _update(
                widget.setting.copyWith(
                  mixed: widget.setting.mixed.copyWith(largeImageHeight: value),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _label('小卡圖片高度'),
          _heightPicker(
            selected: widget.setting.mixed.smallImageHeight,
            onChanged: (String value) {
              _update(
                widget.setting.copyWith(
                  mixed: widget.setting.mixed.copyWith(smallImageHeight: value),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _heightPicker({
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: <ButtonSegment<String>>[
        for (final String height in HomeRoomImageHeights.all)
          ButtonSegment<String>(
            value: height,
            label: Text(HomeRoomImageHeights.label(height)),
          ),
      ],
      selected: <String>{selected},
      onSelectionChanged: (Set<String> value) => onChanged(value.first),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _thumb(Map<String, dynamic> room) {
    final String url = _firstImage(room);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url.isEmpty
            ? ColoredBox(
                color: widget.theme.primaryColor.withValues(alpha: 0.12),
                child: Icon(
                  Icons.bedroom_parent_outlined,
                  color: widget.theme.primaryColor,
                  size: 20,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: widget.theme.primaryColor.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.bedroom_parent_outlined,
                    color: widget.theme.primaryColor,
                    size: 20,
                  ),
                ),
              ),
      ),
    );
  }

  String _roomName(String id) {
    final String name = (_byId[id]?['name'] ?? '未命名房型').toString().trim();
    return name.isEmpty ? '未命名房型' : name;
  }

  static String _firstImage(Map<String, dynamic> room) {
    final Object? raw = room['images'];
    if (raw is! List || raw.isEmpty) {
      return '';
    }
    return raw.first.toString().trim();
  }

  static bool _touchPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  static bool _same(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
