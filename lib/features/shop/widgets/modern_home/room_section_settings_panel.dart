import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_bridge.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_editor.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/room_section_layout_preview.dart';
import 'package:petnest_saas/features/shop/widgets/platform_media_asset_picker.dart';

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
    this.sharedZoneEnabled = false,
    this.hideSharedPlacement = false,
    this.displayStyles,
    this.onDisplayStyles,
  });

  final String shopId;
  final HomeRoomSectionSetting setting;
  final HomeThemeModel theme;
  final ValueChanged<HomeRoomSectionSetting> onChanged;

  /// 測試或上層已有資料時直接傳入，不再另外訂閱。
  final List<Map<String, dynamic>>? rooms;
  final String? selectedRoomTypeId;
  final VoidCallback? onManageRooms;
  final bool sharedZoneEnabled;

  /// 加入小卡改由外層開關負責時，不再顯示另一組「加入共用區」。
  final bool hideSharedPlacement;
  final HomeDisplayStyleSetting? displayStyles;
  final ValueChanged<HomeDisplayStyleSetting>? onDisplayStyles;

  @override
  State<RoomSectionSettingsPanel> createState() =>
      _RoomSectionSettingsPanelState();
}

class _RoomSectionSettingsPanelState extends State<RoomSectionSettingsPanel> {
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

  Set<String> get _catalogIds =>
      HomeRoomSectionSetting.knownIds(_catalog).toSet();

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
    final String layout = widget.setting.layout;
    final bool simple = layout == HomeRoomSectionLayouts.simpleEntry;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: CustomScrollView(
          primary: false,
          cacheExtent: 2200,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              sliver: SliverToBoxAdapter(child: _stylePicker()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              sliver: SliverToBoxAdapter(child: _fontField()),
            ),
            if (widget.onDisplayStyles != null)
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (widget.onDisplayStyles != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: _roomStyleEditor(),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              sliver: SliverToBoxAdapter(child: _sharedFields(simple)),
            ),
            if (simple)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '簡約入口不列出個別房型。已儲存的排序會在切回其他版型時沿用。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Colors.black54,
                    ),
                  ),
                ),
              )
            else
              ..._roomSlivers(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
              sliver: SliverToBoxAdapter(child: _layoutDetails(layout)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stylePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.selectedRoomTypeId != null &&
            widget.selectedRoomTypeId!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
        const Text('展示樣式', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 300 ? 2 : 1;
            final double width =
                (constraints.maxWidth - 8 * (columns - 1)) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final (String layout, String description)
                    in const <(String, String)>[
                      (HomeRoomSectionLayouts.horizontalScroll, '左右滑動查看房型'),
                      (HomeRoomSectionLayouts.cardGrid, '一排兩張，可改單卡或長卡'),
                      (HomeRoomSectionLayouts.simpleEntry, '一張精緻圖片入口'),
                      (HomeRoomSectionLayouts.featured, '第一間大圖，下一間圖文'),
                      (HomeRoomSectionLayouts.refinedCards, '圖片為主，可滑看下一張'),
                    ])
                  SizedBox(
                    width: width,
                    child: _choice(layout: layout, description: description),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _fontField() {
    final String current = widget.setting.appliedFontFamily ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('統一字體', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('room-font-family-$current'),
          initialValue: current,
          isExpanded: true,
          menuMaxHeight: 280,
          decoration: const InputDecoration(
            labelText: '房型展示字體',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          selectedItemBuilder: (BuildContext context) {
            return <Widget>[
              for (final _RoomFontOption option in _RoomFontOption.values)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: option.family.isEmpty ? null : option.family,
                    ),
                  ),
                ),
            ];
          },
          items: <DropdownMenuItem<String>>[
            for (final _RoomFontOption option in _RoomFontOption.values)
              DropdownMenuItem<String>(
                value: option.family,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: option.family.isEmpty ? null : option.family,
                  ),
                ),
              ),
          ],
          onChanged: (String? value) {
            if (value == null || value == widget.setting.fontFamily) {
              return;
            }
            _update(widget.setting.copyWith(fontFamily: value));
          },
        ),
      ],
    );
  }

  void _setSimple(HomeRoomSimpleSetting simple) {
    _update(widget.setting.copyWith(simple: simple));
  }

  Future<void> _pickSimpleImage() async {
    final PlatformMediaAsset? asset = await showPlatformMediaAssetPicker(
      context: context,
      category: PlatformMediaCategories.dailyCareCard,
      selectedId: widget.setting.simple.imageAssetId,
      title: '選擇入口圖片',
    );
    if (!mounted || asset == null) {
      return;
    }
    _setSimple(widget.setting.simple.copyWith(imageAssetId: asset.id));
  }

  Widget _sharedFields(bool simple) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('顯示內容', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (simple)
          const Text(
            '簡約入口的標題在下方文字設定。',
            style: TextStyle(fontSize: 12, height: 1.35, color: Colors.black54),
          ),
        if (!simple)
          TextField(
            controller: _titleController,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: '標題',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String value) {
              _update(widget.setting.copyWith(title: value.trim()));
            },
          ),
        if (!simple)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示價格'),
            value: widget.setting.showPrice,
            onChanged: (bool value) {
              _update(widget.setting.copyWith(showPrice: value));
            },
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
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                RoomSectionLayoutPreview(
                  layout: layout,
                  theme: widget.theme,
                  height: 46,
                ),
                const SizedBox(height: 6),
                Text(
                  HomeRoomSectionLayouts.label(layout),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _roomSlivers() {
    if (_roomsError != null) {
      return const <Widget>[SliverToBoxAdapter(child: Text('房型資料讀取失敗'))];
    }
    final List<String> published = widget.setting.publishedIds(_catalog);
    if (published.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('目前尚未建立已發布房型'),
              if (widget.onManageRooms != null)
                TextButton(
                  onPressed: widget.onManageRooms,
                  child: const Text('前往房型管理'),
                ),
            ],
          ),
        ),
      ];
    }
    final bool mixed = widget.setting.layout == HomeRoomSectionLayouts.cardGrid;
    return <Widget>[
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Text('房型排列', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      SliverReorderableList(
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
    ];
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
    final Widget identity = Expanded(
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
    );
    final Widget visibility = Switch(
      key: Key('room-visible-$id'),
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
    );
    return Material(
      key: key,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wideSettings = constraints.maxWidth >= 560;
            final Widget dragHandle = touch
                ? ReorderableDelayedDragStartListener(
                    index: index,
                    child: handle,
                  )
                : ReorderableDragStartListener(index: index, child: handle);
            final Widget summary = Row(
              children: <Widget>[
                dragHandle,
                _thumb(room),
                const SizedBox(width: 8),
                identity,
                visibility,
                if (mixed && wideSettings) ...<Widget>[
                  const SizedBox(width: 8),
                  _sizePicker(id),
                ],
              ],
            );
            if (!mixed || wideSettings) {
              return summary;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                summary,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: _sizePicker(id)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sizePicker(String id) {
    return SegmentedButton<String>(
      key: Key('room-size-$id'),
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: <ButtonSegment<String>>[
        for (final String size in HomeRoomCardSizes.all)
          ButtonSegment<String>(
            value: size,
            label: Text(HomeRoomCardSizes.label(size)),
          ),
      ],
      selected: <String>{widget.setting.mixed.sizeOf(id)},
      onSelectionChanged: (Set<String> value) {
        final Map<String, String> sizes = Map<String, String>.from(
          widget.setting.mixed.itemSizes,
        );
        sizes[id] = value.first;
        sizes.removeWhere(
          (String roomId, String _) => !_catalogIds.contains(roomId),
        );
        _update(
          widget.setting.copyWith(
            mixed: widget.setting.mixed.copyWith(itemSizes: sizes),
          ),
        );
      },
    );
  }

  Widget _roomStyleEditor() {
    final HomeDisplayStyleSetting display =
        widget.displayStyles ?? HomeDisplayStyleSetting.unset;
    final HomeDisplayStyle legacy = roomDisplayLegacy(widget.setting.simple);
    final String mode = display.effectiveMode(
      sectionId: HomeDisplaySections.rooms,
      legacy: legacy,
      baseline: HomeDisplayStyle.roomsBaseline,
    );
    final HomeDisplayStyle effective = display.resolve(
      sectionId: HomeDisplaySections.rooms,
      legacy: legacy,
      baseline: HomeDisplayStyle.roomsBaseline,
    );
    return HomeDisplaySectionOverride(
      label: '房型介紹',
      shared: display.style,
      mode: mode,
      effective: effective,
      onInherit: () {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.rooms,
            mode: HomeDisplayStyleModes.inherit,
            clearOverride: true,
          ),
        );
      },
      onCustom: () {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.rooms,
            mode: HomeDisplayStyleModes.custom,
          ),
        );
      },
      onEdit: (HomeDisplayStyle edited) {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.rooms,
            mode: HomeDisplayStyleModes.custom,
            override: edited.diff(display.style),
          ),
        );
      },
    );
  }

  Widget _simpleDetails() {
    final HomeRoomSimpleSetting simple = widget.setting.simple;
    final bool onImage = simple.textMode != HomeRoomSimpleTextModes.below;
    final bool chosen = simple.imageAssetId.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!widget.hideSharedPlacement) ...<Widget>[
          const Text('顯示方式', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            '獨立顯示沿用這張入口自己的尺寸。加入共用區後，每排張數改由首頁共用精緻小卡區決定。',
            style: TextStyle(fontSize: 12, height: 1.35, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          _chips(
            options: const <(String, String)>[
              (HomeRoomSimplePlacements.independent, '獨立顯示'),
              (HomeRoomSimplePlacements.shared, '加入共用小卡區'),
            ],
            selected: simple.placement,
            onChanged: (String value) {
              _setSimple(simple.copyWith(placement: value));
            },
          ),
          if (simple.placement == HomeRoomSimplePlacements.shared &&
              !widget.sharedZoneEnabled)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '目前共用小卡區未啟用，此入口暫時不會顯示。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.black54,
                ),
              ),
            ),
        ],
        const SizedBox(height: 14),
        const Text('圖片', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            OutlinedButton(
              key: const Key('room-simple-image'),
              onPressed: _pickSimpleImage,
              child: Text(chosen ? '更換圖片' : '從平台圖庫選擇'),
            ),
            if (chosen)
              TextButton(
                onPressed: () => _setSimple(simple.copyWith(imageAssetId: '')),
                child: const Text('清除圖片'),
              ),
          ],
        ),
        if (widget.onDisplayStyles == null) ...<Widget>[
          const SizedBox(height: 8),
          _sideBySide(
            left: _chips(
              options: const <(String, String)>[
                (HomeRoomSimpleAspects.square, '正方形'),
                (HomeRoomSimpleAspects.portrait, '直式'),
                (HomeRoomSimpleAspects.landscape, '橫式'),
              ],
              selected: simple.aspect,
              onChanged: (String value) =>
                  _setSimple(simple.copyWith(aspect: value)),
            ),
            right: _chips(
              options: const <(String, String)>[
                (HomeRoomSimpleRadii.small, '圓角小'),
                (HomeRoomSimpleRadii.medium, '圓角中'),
                (HomeRoomSimpleRadii.large, '圓角大'),
              ],
              selected: simple.radius,
              onChanged: (String value) =>
                  _setSimple(simple.copyWith(radius: value)),
            ),
          ),
          const SizedBox(height: 8),
          _label('圖片效果'),
          _chips(
            options: const <(String, String)>[
              (HomeRoomSimpleMasks.none, '遮罩無'),
              (HomeRoomSimpleMasks.light, '遮罩淡'),
              (HomeRoomSimpleMasks.strong, '遮罩深'),
            ],
            selected: simple.mask,
            onChanged: (String value) =>
                _setSimple(simple.copyWith(mask: value)),
          ),
        ],
        const Divider(height: 28),
        const Text('文字', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (widget.onDisplayStyles == null) _textModePicker(simple),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: '主標題',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (String value) {
            _update(widget.setting.copyWith(title: value.trim()));
          },
        ),
        if (simple.textMode != HomeRoomSimpleTextModes.overlay) ...<Widget>[
          TextField(
            controller: _subtitleController,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '副標題',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String value) {
              _setSimple(
                widget.setting.simple.copyWith(subtitle: value.trim()),
              );
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示副標題'),
            value: simple.showSubtitle,
            onChanged: (bool value) {
              _setSimple(simple.copyWith(showSubtitle: value));
            },
          ),
        ],
        if (widget.onDisplayStyles == null) ...<Widget>[
          _sideBySide(
            left: _chips(
              options: const <(String, String)>[
                (HomeRoomSimpleTextSizes.small, '文字小'),
                (HomeRoomSimpleTextSizes.medium, '文字中'),
                (HomeRoomSimpleTextSizes.large, '文字大'),
              ],
              selected: simple.textSize,
              onChanged: (String value) =>
                  _setSimple(simple.copyWith(textSize: value)),
            ),
            right: _chips(
              options: const <(String, String)>[
                (HomeRoomSimpleTextWeights.regular, '一般'),
                (HomeRoomSimpleTextWeights.medium, '中等'),
                (HomeRoomSimpleTextWeights.bold, '粗體'),
              ],
              selected: simple.textWeight,
              onChanged: (String value) =>
                  _setSimple(simple.copyWith(textWeight: value)),
            ),
          ),
          const SizedBox(height: 6),
          _textColorPalette(simple),
          if (onImage) ...<Widget>[
            const SizedBox(height: 6),
            _chips(
              options: const <(String, String)>[
                (HomeRoomSimpleTextAligns.bottomStart, '左下'),
                (HomeRoomSimpleTextAligns.center, '正中央'),
                (HomeRoomSimpleTextAligns.bottomEnd, '右下'),
              ],
              selected: simple.textAlign,
              onChanged: (String value) =>
                  _setSimple(simple.copyWith(textAlign: value)),
            ),
          ],
        ],
        if (widget.onDisplayStyles == null) ...<Widget>[
          const Divider(height: 28),
          const Text('卡片外觀', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          _label('背景'),
          _chips(
            options: const <(String, String)>[
              (HomeRoomSimpleSurfaces.filled, '淡色底'),
              (HomeRoomSimpleSurfaces.outlined, '只有框線'),
              (HomeRoomSimpleSurfaces.transparent, '透明'),
            ],
            selected: simple.surface,
            onChanged: (String value) =>
                _setSimple(simple.copyWith(surface: value)),
          ),
        ],
        const SizedBox(height: 8),
        _label('卡片規格'),
        _chips(
          options: <(String, String)>[
            for (final String size in HomeRoomSimpleCardSizes.all)
              (size, HomeRoomSimpleCardSizes.label(size)),
          ],
          selected: HomeRoomSimpleCardSizes.migrate(simple.cardSize),
          onChanged: (String value) =>
              _setSimple(simple.copyWith(cardSize: value)),
        ),
        const SizedBox(height: 8),
        _label('沒有圖片時的圖示'),
        if (chosen)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              '已使用圖片，移除圖片後可設定預設圖示。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.black54,
              ),
            ),
          ),
        IgnorePointer(
          ignoring: chosen,
          child: Opacity(
            opacity: chosen ? 0.45 : 1,
            child: _chips(
              options: <(String, String)>[
                for (final String icon in HomeRoomSimpleIcons.all)
                  (icon, HomeRoomSimpleIcons.label(icon)),
              ],
              selected: simple.icon,
              onChanged: (String value) =>
                  _setSimple(widget.setting.simple.copyWith(icon: value)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _textColorPalette(HomeRoomSimpleSetting simple) {
    final int current = _resolvedTextColor(simple);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: Text('文字顏色', style: TextStyle(fontSize: 13))),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Color(current),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE6E8EC)),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '目前顏色',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final _TextSwatch swatch in _TextSwatch.values)
              _swatchButton(simple, swatch),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _hex(current),
          decoration: const InputDecoration(
            labelText: '色碼',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (String value) {
            final int? color = _parseHex(value);
            if (color == null) {
              return;
            }
            _setSimple(
              widget.setting.simple.copyWith(
                textColor: HomeRoomSimpleTextColors.custom,
                textColorValue: color,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _swatchButton(HomeRoomSimpleSetting simple, _TextSwatch swatch) {
    final bool selected = swatch.mode == HomeRoomSimpleTextColors.custom
        ? simple.textColor == swatch.mode &&
              simple.textColorValue == swatch.argb
        : simple.textColor == swatch.mode;
    return Tooltip(
      message: swatch.label,
      child: InkWell(
        key: Key('room-simple-color-${swatch.argb.toRadixString(16)}'),
        customBorder: const CircleBorder(),
        onTap: () {
          _setSimple(
            simple.copyWith(
              textColor: swatch.mode,
              textColorValue: swatch.mode == HomeRoomSimpleTextColors.custom
                  ? swatch.argb
                  : simple.textColorValue,
            ),
          );
        },
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Color(swatch.argb),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? widget.theme.primaryColor
                  : const Color(0xFFE6E8EC),
              width: selected ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }

  int _resolvedTextColor(HomeRoomSimpleSetting simple) {
    switch (simple.textColor) {
      case HomeRoomSimpleTextColors.light:
        return 0xFFFFFFFF;
      case HomeRoomSimpleTextColors.custom:
        return simple.textColorValue ?? 0xFFFFFFFF;
      default:
        return 0xFF3A2A20;
    }
  }

  Widget _textModePicker(HomeRoomSimpleSetting simple) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _modeCard(simple, HomeRoomSimpleTextModes.below, '圖片下方', const <String>[
          '圖',
          '字',
        ]),
        _modeCard(
          simple,
          HomeRoomSimpleTextModes.overlay,
          '圖片內文字',
          const <String>['圖＋字'],
        ),
        _modeCard(
          simple,
          HomeRoomSimpleTextModes.caption,
          '主副標題',
          const <String>['標題', '副標'],
        ),
      ],
    );
  }

  Widget _modeCard(
    HomeRoomSimpleSetting simple,
    String mode,
    String label,
    List<String> lines,
  ) {
    final bool selected = simple.textMode == mode;
    return SizedBox(
      width: 104,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('room-simple-mode-$mode'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _setSimple(simple.copyWith(textMode: mode)),
          child: Ink(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? widget.theme.primaryColor
                    : const Color(0xFFE6E8EC),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.theme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    lines.join('\n'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, height: 1.2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sideBySide({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[left, const SizedBox(height: 6), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _chips({
    required List<(String, String)> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final (String value, String label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) => onChanged(value),
          ),
      ],
    );
  }

  String _hex(int? value) {
    if (value == null) {
      return '';
    }
    return '#${value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  int? _parseHex(String raw) {
    String hex = raw.trim().replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) {
      return null;
    }
    return int.tryParse(hex, radix: 16);
  }

  Widget _layoutDetails(String layout) {
    if (layout == HomeRoomSectionLayouts.horizontalScroll ||
        layout == HomeRoomSectionLayouts.featured ||
        layout == HomeRoomSectionLayouts.refinedCards) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (layout != HomeRoomSectionLayouts.simpleEntry) ...<Widget>[
          const Text('外觀細節', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
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
        if (layout == HomeRoomSectionLayouts.simpleEntry) _simpleDetails(),
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
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget large = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _label('單卡圖片高度'),
                  _heightPicker(
                    selected: widget.setting.mixed.largeImageHeight,
                    onChanged: (String value) {
                      _update(
                        widget.setting.copyWith(
                          mixed: widget.setting.mixed.copyWith(
                            largeImageHeight: value,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
              final Widget small = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _label('小卡圖片高度'),
                  _heightPicker(
                    selected: widget.setting.mixed.smallImageHeight,
                    onChanged: (String value) {
                      _update(
                        widget.setting.copyWith(
                          mixed: widget.setting.mixed.copyWith(
                            smallImageHeight: value,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[large, const SizedBox(height: 12), small],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: large),
                  const SizedBox(width: 12),
                  Expanded(child: small),
                ],
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

class _TextSwatch {
  const _TextSwatch(this.label, this.mode, this.argb);

  final String label;
  final String mode;
  final int argb;

  static const List<_TextSwatch> values = <_TextSwatch>[
    _TextSwatch('白色', HomeRoomSimpleTextColors.light, 0xFFFFFFFF),
    _TextSwatch('深色', HomeRoomSimpleTextColors.dark, 0xFF3A2A20),
    _TextSwatch('暖橘', HomeRoomSimpleTextColors.custom, 0xFFA56B45),
    _TextSwatch('櫻花', HomeRoomSimpleTextColors.custom, 0xFFE06B84),
    _TextSwatch('霧藍', HomeRoomSimpleTextColors.custom, 0xFF5E84A6),
    _TextSwatch('森綠', HomeRoomSimpleTextColors.custom, 0xFF2F6B4F),
  ];
}

class _RoomFontOption {
  const _RoomFontOption(this.family, this.label);

  final String family;
  final String label;

  static const List<_RoomFontOption> values = <_RoomFontOption>[
    _RoomFontOption('', '系統預設'),
    _RoomFontOption('jfOpenHuninn', 'jf open 粉圓'),
    _RoomFontOption('NotoSansTC', 'Noto Sans TC 現代黑體'),
    _RoomFontOption('NotoSerifTC', 'Noto Serif TC 傳統宋體'),
    _RoomFontOption('KleeOne', 'Klee One 日系手寫'),
    _RoomFontOption('ChironSungHK', '昭源宋體 Chiron Sung HK'),
  ];
}
