import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_shared_entry_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/services/platform_media_library_service.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/platform_media_asset_picker.dart';

class SharedEntryCardRef {
  const SharedEntryCardRef({required this.id, required this.label});

  final String id;
  final String label;
}

/// 首頁版面裡的共用精緻小卡區設定。內部排序不影響首頁區塊拖曳。
class SharedEntrySettingsCard extends StatefulWidget {
  const SharedEntrySettingsCard({
    super.key,
    required this.setting,
    required this.cards,
    required this.onChanged,
    this.assetLookup,
  });

  final HomeSharedEntrySectionSetting setting;
  final List<SharedEntryCardRef> cards;
  final ValueChanged<HomeSharedEntrySectionSetting> onChanged;

  /// 測試可代入圖庫查詢。正式畫面沿用平台圖庫快取與單筆讀取。
  final Future<PlatformMediaAsset?> Function(String assetId)? assetLookup;

  @override
  State<SharedEntrySettingsCard> createState() =>
      _SharedEntrySettingsCardState();
}

class _SharedEntrySettingsCardState extends State<SharedEntrySettingsCard> {
  late final TextEditingController _title = TextEditingController(
    text: widget.setting.title,
  );
  int _pane = 0;

  @override
  void didUpdateWidget(SharedEntrySettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting.title != widget.setting.title &&
        _title.text != widget.setting.title) {
      _title.text = widget.setting.title;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _move(String id, int delta) {
    final List<String> visible = <String>[
      for (final SharedEntryCardRef card in widget.cards) card.id,
    ];
    final int index = visible.indexOf(id);
    final int target = index + delta;
    if (index < 0 || target < 0 || target >= visible.length) {
      return;
    }
    final int newIndex = target > index ? target + 1 : target;
    final List<String> saved = widget.setting.cardOrder.isEmpty
        ? visible
        : widget.setting.cardOrder;
    widget.onChanged(
      widget.setting.copyWith(
        cardOrder: HomeSectionOrder.reorderVisible(
          saved: saved,
          visible: visible,
          oldIndex: index,
          newIndex: newIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final HomeSharedEntrySectionSetting setting = widget.setting;
    final int columns = sharedEntryColumns(setting.columns);
    final bool scrolling = setting.overflow == HomeSharedEntryOverflows.scroll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _title,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: '區域標題',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (String value) {
            widget.onChanged(setting.copyWith(title: value));
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('啟用共用小卡區'),
          value: setting.enabled,
          onChanged: (bool value) {
            widget.onChanged(setting.copyWith(enabled: value));
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('顯示區域標題'),
          value: setting.showTitle,
          onChanged: (bool value) {
            widget.onChanged(setting.copyWith(showTitle: value));
          },
        ),
        const SizedBox(height: 8),
        _SharedEntryStylePanel(
          pane: _pane,
          onPane: (int value) => setState(() => _pane = value),
          setting: setting,
          scrolling: scrolling,
          columns: columns,
          preview: _preview(columns, scrolling),
          cards: <Widget>[
            if (widget.cards.isEmpty)
              const Text('尚未加入小卡。', style: TextStyle(fontSize: 13, height: 1.4))
            else
              for (int index = 0; index < widget.cards.length; index++)
                _cardRow(widget.cards[index], index),
          ],
          onAdd: _addCard,
          onChanged: widget.onChanged,
        ),
      ],
    );
  }

  Future<void> _addCard() async {
    final List<String> joined = <String>[
      for (final String id in widget.setting.cardOrder)
        if (HomeSharedEntrySources.canJoin(id)) id,
    ];
    final List<String>? picked = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        final Set<String> selected = joined.toSet();
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setLocal) {
            final Size size = MediaQuery.sizeOf(context);
            final double width = math.min(440, math.max(280, size.width - 40));
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width,
                  maxHeight: size.height * 0.86,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Text(
                        '加入小卡',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: <Widget>[
                          for (final String id
                              in HomeSharedEntrySources.joinable)
                            CheckboxListTile(
                              key: Key('shared-entry-option-$id'),
                              value: selected.contains(id),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(HomeSharedEntrySources.label(id)),
                              subtitle: joined.contains(id)
                                  ? const Text('已加入')
                                  : null,
                              onChanged: (bool? value) {
                                setLocal(() {
                                  if (value ?? false) {
                                    selected.add(id);
                                  } else {
                                    selected.remove(id);
                                  }
                                });
                              },
                            ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                            child: Text(
                              '取消勾選只會從首頁小卡區移出，已編輯的圖片與文字會保留。每日照護、商城與服務捷徑沒有獨立的顧客入口頁，暫不加入。',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '已選 ${selected.length} 張',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('shared-entry-add-cancel'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                          const SizedBox(width: 4),
                          FilledButton(
                            key: const Key('shared-entry-add-apply'),
                            onPressed: () {
                              Navigator.of(context).pop(<String>[
                                for (final String id
                                    in HomeSharedEntrySources.joinable)
                                  if (selected.contains(id)) id,
                              ]);
                            },
                            child: const Text('確認套用'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    widget.onChanged(widget.setting.applyJoined(picked));
  }

  Future<void> _editCard(String id) async {
    final HomeSharedEntryCardSetting saved = widget.setting.cardOf(id);
    HomeSharedEntryCardSetting draft = saved.rememberImage(saved.imageAssetId);
    final HomeSharedEntryCardSetting? next =
        await showDialog<HomeSharedEntryCardSetting>(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setLocal) {
                final double screenWidth = MediaQuery.sizeOf(context).width;
                final double screenHeight = MediaQuery.sizeOf(context).height;
                final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
                final bool wide = screenWidth >= 720;
                final Widget form = _SharedEntryCardForm(
                  card: draft,
                  assetLookup: widget.assetLookup,
                  onChanged: (HomeSharedEntryCardSetting value) {
                    setLocal(() => draft = value);
                  },
                );
                return AlertDialog(
                  insetPadding: EdgeInsets.fromLTRB(16, 24, 16, 24 + keyboard),
                  title: Text('編輯${HomeSharedEntrySources.label(id)}'),
                  content: SizedBox(
                    width: wide
                        ? math.min(640, screenWidth - 80)
                        : math.max(260, screenWidth - 48),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(160, screenHeight - keyboard - 210),
                      ),
                      child: SingleChildScrollView(child: form),
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      key: const Key('shared-entry-edit-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      key: const Key('shared-entry-edit-done'),
                      onPressed: () => Navigator.of(context).pop(draft),
                      child: const Text('完成'),
                    ),
                  ],
                );
              },
            );
          },
        );
    if (next == null || !mounted) {
      return;
    }
    widget.onChanged(widget.setting.updateCard(id, next));
  }

  Widget _preview(int columns, bool scrolling) {
    final int count = widget.cards.length;
    if (count == 0) {
      return const Text(
        '尚未加入小卡',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = 6;
        final double slot = math.max(
          0,
          (constraints.maxWidth - gap * (columns - 1)) / columns,
        );
        final Widget wrapped = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int start = 0; start < count; start += columns) ...<Widget>[
              if (start > 0) const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  for (
                    int index = start;
                    index < math.min(start + columns, count);
                    index++
                  ) ...<Widget>[
                    if (index > start) SizedBox(width: gap),
                    Container(
                      width: slot,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F1EA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE6E8EC)),
                      ),
                      child: Text(
                        widget.cards[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
        if (!scrolling || count <= columns) {
          return wrapped;
        }
        return SizedBox(
          height: 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (BuildContext context, int index) {
              return const SizedBox(width: 6);
            },
            itemBuilder: (BuildContext context, int index) {
              return _previewTile(widget.cards[index].label, slot);
            },
          ),
        );
      },
    );
  }

  Widget _previewTile(String label, double width) {
    return Container(
      width: width,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1EA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _cardRow(SharedEntryCardRef card, int index) {
    final bool first = index == 0;
    final bool last = index == widget.cards.length - 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE6E8EC)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  card.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                key: Key('shared-entry-edit-${card.id}'),
                onPressed: () => _editCard(card.id),
                child: const Text('編輯'),
              ),
              IconButton(
                key: Key('shared-entry-remove-${card.id}'),
                tooltip: '移出小卡區',
                onPressed: () =>
                    widget.onChanged(widget.setting.without(card.id)),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
              IconButton(
                key: Key('shared-entry-up-${card.id}'),
                tooltip: '上移',
                onPressed: first ? null : () => _move(card.id, -1),
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              ),
              IconButton(
                key: Key('shared-entry-down-${card.id}'),
                tooltip: '下移',
                onPressed: last ? null : () => _move(card.id, 1),
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SharedEntryJoinSwitch extends StatelessWidget {
  const SharedEntryJoinSwitch({
    super.key,
    required this.joined,
    required this.zoneEnabled,
    required this.onChanged,
  });

  final bool joined;
  final bool zoneEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('加入首頁精緻小卡區'),
          value: joined,
          onChanged: onChanged,
        ),
        if (joined && !zoneEnabled)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '目前精緻小卡區未啟用，此入口暫時不會顯示。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.black54,
              ),
            ),
          ),
      ],
    );
  }
}

class _SharedEntryCardForm extends StatelessWidget {
  const _SharedEntryCardForm({
    required this.card,
    required this.onChanged,
    this.assetLookup,
  });

  final HomeSharedEntryCardSetting card;
  final ValueChanged<HomeSharedEntryCardSetting> onChanged;
  final Future<PlatformMediaAsset?> Function(String assetId)? assetLookup;

  @override
  Widget build(BuildContext context) {
    final bool hasImage = card.imageAssetId.isNotEmpty;
    final List<String> recent = card.recentImageAssetIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _group('基本內容', <Widget>[
          TextFormField(
            key: const Key('shared-entry-card-title'),
            initialValue: card.title,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: '主標題',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String value) => onChanged(card.copyWith(title: value)),
          ),
          TextFormField(
            key: const Key('shared-entry-card-subtitle'),
            initialValue: card.subtitle,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '副標題',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String value) =>
                onChanged(card.copyWith(subtitle: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示主標題'),
            value: card.showTitle,
            onChanged: (bool value) =>
                onChanged(card.copyWith(showTitle: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示副標題'),
            value: card.showSubtitle,
            onChanged: (bool value) =>
                onChanged(card.copyWith(showSubtitle: value)),
          ),
        ]),
        const SizedBox(height: 12),
        _group('圖片', <Widget>[
          Row(
            children: <Widget>[
              _SharedEntryAssetThumb(
                key: const Key('shared-entry-current-image'),
                assetId: card.imageAssetId,
                selected: hasImage,
                size: 72,
                lookup: assetLookup,
                onTap: null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasImage ? '目前使用圖庫圖片' : '目前沒有圖片，前台會顯示固定圖示',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('最近使用', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          if (recent.isEmpty)
            const Text(
              '尚無最近使用的圖片',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            )
          else
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(width: 8);
                },
                itemBuilder: (BuildContext context, int index) {
                  final String id = recent[index];
                  return _SharedEntryAssetThumb(
                    key: Key('shared-entry-recent-$id'),
                    assetId: id,
                    selected: id == card.imageAssetId,
                    lookup: assetLookup,
                    onTap: () => onChanged(
                      card
                          .copyWith(imageAssetId: id, useSourceImage: false)
                          .rememberImage(id),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                key: const Key('shared-entry-pick-image'),
                onPressed: () async {
                  final PlatformMediaAsset? asset =
                      await showPlatformMediaAssetPicker(
                        context: context,
                        category: PlatformMediaCategories.dailyCareCard,
                        selectedId: card.imageAssetId,
                        title: '選擇小卡圖片',
                      );
                  if (asset == null) {
                    return;
                  }
                  onChanged(
                    card
                        .copyWith(imageAssetId: asset.id, useSourceImage: false)
                        .rememberImage(asset.id),
                  );
                },
                child: Text(hasImage ? '更換圖片' : '從圖庫選擇'),
              ),
              if (hasImage)
                TextButton(
                  key: const Key('shared-entry-clear-image'),
                  onPressed: () => onChanged(
                    card.copyWith(imageAssetId: '', useSourceImage: false),
                  ),
                  child: const Text('清除目前圖片'),
                ),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        _group('文字外觀', <Widget>[
          _colorPicker(
            label: '主標題顏色',
            custom: card.titleColorMode == HomeSharedEntryColorModes.custom,
            color: card.textColor,
            onTheme: () => onChanged(
              card.copyWith(titleColorMode: HomeSharedEntryColorModes.theme),
            ),
            onColor: (int value) => onChanged(
              card.copyWith(
                titleColorMode: HomeSharedEntryColorModes.custom,
                textColor: value,
              ),
            ),
          ),
          _colorPicker(
            label: '副標題顏色',
            custom: card.bodyColorMode == HomeSharedEntryColorModes.custom,
            color: card.bodyColor,
            onTheme: () => onChanged(
              card.copyWith(bodyColorMode: HomeSharedEntryColorModes.theme),
            ),
            onColor: (int value) => onChanged(
              card.copyWith(
                bodyColorMode: HomeSharedEntryColorModes.custom,
                bodyColor: value,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _colorPicker({
    required String label,
    required bool custom,
    required int color,
    required VoidCallback onTheme,
    required ValueChanged<int> onColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ChoiceChip(
                label: const Text('沿用預設顏色'),
                selected: !custom,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => onTheme(),
              ),
              for (final int swatch in _sharedEntryColorSwatches)
                InkWell(
                  onTap: () => onColor(swatch),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(swatch),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: custom && color == swatch
                            ? const Color(0xFF3A2A20)
                            : const Color(0xFFE6E8EC),
                        width: custom && color == swatch ? 2 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SharedEntryAssetThumb extends StatefulWidget {
  const _SharedEntryAssetThumb({
    super.key,
    required this.assetId,
    required this.selected,
    required this.lookup,
    required this.onTap,
    this.size = 56,
  });

  final String assetId;
  final bool selected;
  final Future<PlatformMediaAsset?> Function(String assetId)? lookup;
  final VoidCallback? onTap;
  final double size;

  @override
  State<_SharedEntryAssetThumb> createState() => _SharedEntryAssetThumbState();
}

class _SharedEntryAssetThumbState extends State<_SharedEntryAssetThumb> {
  String _url = '';
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_SharedEntryAssetThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      _load();
    }
  }

  Future<void> _load() async {
    final int token = ++_token;
    final String id = widget.assetId.trim();
    if (id.isEmpty) {
      if (mounted && _url.isNotEmpty) {
        setState(() => _url = '');
      }
      return;
    }
    String next = '';
    try {
      final PlatformMediaAsset? asset =
          await (widget.lookup ??
              PlatformMediaLibraryService.instance.getEnabledAssetById)(id);
      final String thumb = asset?.thumbnailUrl.trim() ?? '';
      next = thumb.isEmpty ? (asset?.imageUrl.trim() ?? '') : thumb;
    } catch (_) {
      next = '';
    }
    if (!mounted || token != _token || next == _url) {
      return;
    }
    setState(() => _url = next);
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = _url.isEmpty
        ? const Icon(Icons.image_outlined, size: 22, color: Color(0xFF8A7568))
        : Image.network(
            _url,
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            gaplessPlayback: true,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) {
                  return const Icon(
                    Icons.image_outlined,
                    size: 22,
                    color: Color(0xFF8A7568),
                  );
                },
          );
    return Material(
      color: const Color(0xFFF6F1EA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: widget.selected
              ? const Color(0xFFA56B45)
              : const Color(0xFFE6E8EC),
          width: widget.selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: ColoredBox(
              color: const Color(0xFFF6F1EA),
              child: Center(child: image),
            ),
          ),
        ),
      ),
    );
  }
}

const List<int> _sharedEntryColorSwatches = <int>[
  0xFF3A2A20,
  0xFFFFFFFF,
  0xFFA56B45,
  0xFF5E84A6,
  0xFF2F6B4F,
];

class _SharedEntryStylePanel extends StatelessWidget {
  const _SharedEntryStylePanel({
    required this.pane,
    required this.onPane,
    required this.setting,
    required this.scrolling,
    required this.columns,
    required this.preview,
    required this.cards,
    required this.onAdd,
    required this.onChanged,
  });

  final int pane;
  final ValueChanged<int> onPane;
  final HomeSharedEntrySectionSetting setting;
  final bool scrolling;
  final int columns;
  final Widget preview;
  final List<Widget> cards;
  final VoidCallback onAdd;
  final ValueChanged<HomeSharedEntrySectionSetting> onChanged;

  HomeSharedEntryStyle get style => setting.style;

  void _style(HomeSharedEntryStyle next) {
    onChanged(setting.copyWith(style: next));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 680;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final (int index, String label) in <(int, String)>[
                  (0, '快速風格'),
                  (1, '排列'),
                  (2, '尺寸間距'),
                  (3, '文字'),
                  (4, '卡片外觀'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: pane == index,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onPane(index),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            switch (pane) {
              1 => _layoutPane(wide),
              2 => _spacePane(wide),
              3 => _textPane(wide),
              4 => _surfacePane(wide),
              _ => _presetPane(wide),
            },
          ],
        );
      },
    );
  }

  Widget _presetPane(bool wide) {
    final String current = HomeSharedEntryPresets.match(style);
    final List<Widget> items = <Widget>[
      _presetCard(
        id: HomeSharedEntryPresets.compact,
        title: '原始緊湊',
        hint: '圖片滿欄，間距較小',
        selected: current == HomeSharedEntryPresets.compact,
        bars: 3,
        gap: 3,
      ),
      _presetCard(
        id: HomeSharedEntryPresets.airy,
        title: '精緻留白',
        hint: '圖片稍小，留白較寬',
        selected: current == HomeSharedEntryPresets.airy,
        bars: 3,
        gap: 8,
      ),
      _presetCard(
        id: HomeSharedEntryPresets.custom,
        title: '自訂樣式',
        hint: '手動調整後停在這裡',
        selected: current == HomeSharedEntryPresets.custom,
        bars: 2,
        gap: 6,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          '選擇風格後會套用尺寸、間距、圓角與邊框。已加入的小卡內容不會被清掉。',
          style: TextStyle(fontSize: 12, height: 1.35, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int index = 0; index < items.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: items[index]),
              ],
            ],
          )
        else
          for (final Widget item in items) ...<Widget>[
            item,
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _presetCard({
    required String id,
    required String title,
    required String hint,
    required bool selected,
    required int bars,
    required double gap,
  }) {
    return Material(
      color: selected ? const Color(0xFFF6F1EA) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? const Color(0xFFA56B45) : const Color(0xFFE6E8EC),
        ),
      ),
      child: InkWell(
        key: Key('shared-preset-$id'),
        borderRadius: BorderRadius.circular(12),
        onTap: id == HomeSharedEntryPresets.custom
            ? null
            : () => _style(HomeSharedEntryPresets.apply(style, id)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  for (int index = 0; index < bars; index++) ...<Widget>[
                    if (index > 0) SizedBox(width: gap),
                    Expanded(
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7D3C4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                hint,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layoutPane(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('每排張數', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (wide)
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 1, label: Text('一排 1 張')),
              ButtonSegment<int>(value: 2, label: Text('一排 2 張')),
              ButtonSegment<int>(value: 3, label: Text('一排 3 張')),
            ],
            selected: <int>{columns},
            onSelectionChanged: (Set<int> value) {
              onChanged(setting.copyWith(columns: value.first));
            },
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final int count in <int>[1, 2, 3])
                ChoiceChip(
                  label: Text('一排 $count 張'),
                  selected: columns == count,
                  onSelected: (_) {
                    onChanged(setting.copyWith(columns: count));
                  },
                ),
            ],
          ),
        const SizedBox(height: 12),
        const Text('超出時顯示方式', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (wide)
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: HomeSharedEntryOverflows.wrap,
                label: Text('自動換到下一排'),
              ),
              ButtonSegment<String>(
                value: HomeSharedEntryOverflows.scroll,
                label: Text('左右滑動瀏覽'),
              ),
            ],
            selected: <String>{
              scrolling
                  ? HomeSharedEntryOverflows.scroll
                  : HomeSharedEntryOverflows.wrap,
            },
            onSelectionChanged: (Set<String> value) {
              onChanged(setting.copyWith(overflow: value.first));
            },
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              ChoiceChip(
                label: const Text('自動換到下一排'),
                selected: !scrolling,
                onSelected: (_) {
                  onChanged(
                    setting.copyWith(overflow: HomeSharedEntryOverflows.wrap),
                  );
                },
              ),
              ChoiceChip(
                label: const Text('左右滑動瀏覽'),
                selected: scrolling,
                onSelected: (_) {
                  onChanged(
                    setting.copyWith(overflow: HomeSharedEntryOverflows.scroll),
                  );
                },
              ),
            ],
          ),
        const SizedBox(height: 12),
        const Text('排列預覽', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        preview,
        const SizedBox(height: 12),
        const Text('已加入的小卡', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          '這裡只調整小卡順序。拖曳首頁上的握把才會移動整個區塊。',
          style: TextStyle(fontSize: 12, height: 1.35, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ...cards,
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('shared-entry-add'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('加入小卡'),
          ),
        ),
      ],
    );
  }

  Widget _spacePane(bool wide) {
    final HomeSharedEntryStyle compact = HomeSharedEntryPresets.compactStyle;
    final List<Widget> controls = <Widget>[
      _slider(
        label: '圖片尺寸',
        value: style.imageScale,
        min: 0.7,
        max: 1,
        valueLabel: '${(style.imageScale * 100).round()}%',
        reset: compact.imageScale,
        onChanged: (double value) => _style(style.copyWith(imageScale: value)),
      ),
      _slider(
        label: '固定圖示大小',
        value: style.iconSize,
        min: 28,
        max: 72,
        valueLabel: '${style.iconSize.round()} px',
        reset: compact.iconSize,
        onChanged: (double value) => _style(style.copyWith(iconSize: value)),
      ),
      _slider(
        label: '卡片左右間距',
        value: style.gapX,
        min: 0,
        max: 28,
        valueLabel: '${style.gapX.round()} px',
        reset: compact.gapX,
        onChanged: (double value) => _style(style.copyWith(gapX: value)),
      ),
      _slider(
        label: '卡片上下間距',
        value: style.gapY,
        min: 0,
        max: 36,
        valueLabel: '${style.gapY.round()} px',
        reset: compact.gapY,
        onChanged: (double value) => _style(style.copyWith(gapY: value)),
      ),
      _slider(
        label: '圖片文字距離',
        value: style.gapText,
        min: 0,
        max: 24,
        valueLabel: '${style.gapText.round()} px',
        reset: compact.gapText,
        onChanged: (double value) => _style(style.copyWith(gapText: value)),
      ),
      _slider(
        label: '區域左右留白',
        value: style.insetX,
        min: 0,
        max: 28,
        valueLabel: '${style.insetX.round()} px',
        reset: compact.insetX,
        onChanged: (double value) => _style(style.copyWith(insetX: value)),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          '圖片尺寸是欄位裡的圖片寬度。左右間距是卡片之間的距離。重設會回到原始緊湊的數值。',
          style: TextStyle(fontSize: 12, height: 1.35, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        _grid(wide, controls),
      ],
    );
  }

  Widget _textPane(bool wide) {
    return _grid(wide, <Widget>[
      DropdownButtonFormField<String>(
        key: ValueKey<String>('shared-style-font-${style.fontFamily}'),
        initialValue: style.appliedFontFamily ?? '',
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: '統一字體',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: const <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: '', child: Text('系統預設')),
          DropdownMenuItem<String>(
            value: 'jfOpenHuninn',
            child: Text('jf open 粉圓'),
          ),
          DropdownMenuItem<String>(
            value: 'NotoSansTC',
            child: Text('Noto Sans TC'),
          ),
          DropdownMenuItem<String>(
            value: 'NotoSerifTC',
            child: Text('Noto Serif TC'),
          ),
          DropdownMenuItem<String>(value: 'KleeOne', child: Text('Klee One')),
          DropdownMenuItem<String>(value: 'ChironSungHK', child: Text('昭源宋體')),
        ],
        onChanged: (String? value) {
          if (value == null) {
            return;
          }
          _style(style.copyWith(fontFamily: value));
        },
      ),
      _chips(
        '主標題大小',
        HomeRoomSimpleTextSizes.all,
        _sizeLabel,
        style.titleSize,
        (String value) => _style(style.copyWith(titleSize: value)),
      ),
      _chips(
        '副標題大小',
        HomeRoomSimpleTextSizes.all,
        _sizeLabel,
        style.bodySize,
        (String value) => _style(style.copyWith(bodySize: value)),
      ),
      _chips(
        '主標題字重',
        HomeRoomSimpleTextWeights.all,
        _weightLabel,
        style.titleWeight,
        (String value) => _style(style.copyWith(titleWeight: value)),
      ),
      _chips(
        '副標題字重',
        HomeRoomSimpleTextWeights.all,
        _weightLabel,
        style.bodyWeight,
        (String value) => _style(style.copyWith(bodyWeight: value)),
      ),
      _chips(
        '文字對齊',
        const <String>['start', 'center', 'end'],
        (String value) => switch (value) {
          'center' => '置中',
          'end' => '靠右',
          _ => '靠左',
        },
        style.textAlign,
        (String value) => _style(style.copyWith(textAlign: value)),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('文字位置', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String value in HomeSharedEntryPlacements.all)
                _positionButton(value),
            ],
          ),
        ],
      ),
    ]);
  }

  Widget _surfacePane(bool wide) {
    final bool onImage =
        style.textPlacement == HomeSharedEntryPlacements.center ||
        style.textPlacement == HomeSharedEntryPlacements.insideBottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _grid(wide, <Widget>[
          _chips(
            '卡片背景',
            HomeRoomSimpleSurfaces.all,
            HomeRoomSimpleSurfaces.label,
            style.surface,
            (String value) => _style(style.copyWith(surface: value)),
          ),
          _chips(
            '圓角',
            HomeRoomSimpleRadii.all,
            (String value) => switch (value) {
              HomeRoomSimpleRadii.small => '圓角小',
              HomeRoomSimpleRadii.large => '圓角大',
              _ => '圓角中',
            },
            style.radius,
            (String value) => _style(style.copyWith(radius: value)),
          ),
          _chips(
            '邊框',
            const <String>['border', 'plain'],
            (String value) => value == 'plain' ? '無框線' : '有框線',
            style.showBorder ? 'border' : 'plain',
            (String value) =>
                _style(style.copyWith(showBorder: value == 'border')),
          ),
          _chips(
            '陰影',
            const <String>[
              HomeDisplayShadows.none,
              HomeDisplayShadows.soft,
              HomeDisplayShadows.strong,
            ],
            (String value) => switch (value) {
              HomeDisplayShadows.soft => '淡陰影',
              HomeDisplayShadows.strong => '明顯陰影',
              _ => '無陰影',
            },
            style.cardShadow,
            (String value) => _style(style.copyWith(cardShadow: value)),
          ),
          _chips(
            '圖片比例',
            HomeRoomSimpleAspects.all,
            (String value) => switch (value) {
              HomeRoomSimpleAspects.portrait => '直式',
              HomeRoomSimpleAspects.landscape => '橫式',
              _ => '正方形',
            },
            style.aspect,
            (String value) => _style(style.copyWith(aspect: value)),
          ),
          _chips(
            '圖片裁切',
            const <String>['cover', 'contain'],
            (String value) => value == 'contain' ? '完整顯示' : '裁切填滿',
            style.imageFit,
            (String value) => _style(style.copyWith(imageFit: value)),
          ),
          _chips(
            '圖片遮罩',
            HomeRoomSimpleMasks.all,
            (String value) => switch (value) {
              HomeRoomSimpleMasks.light => '淡遮罩',
              HomeRoomSimpleMasks.strong => '深遮罩',
              _ => '無遮罩',
            },
            style.mask,
            (String value) => _style(style.copyWith(mask: value)),
          ),
        ]),
        if (!onImage)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '遮罩只蓋在圖片上。文字放在圖片外時，不會被遮罩影響。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.black54,
              ),
            ),
          ),
      ],
    );
  }

  Widget _positionButton(String value) {
    final bool selected = style.textPlacement == value;
    final bool above = value == HomeSharedEntryPlacements.above;
    final bool outside = value == HomeSharedEntryPlacements.outsideBelow;
    final bool center = value == HomeSharedEntryPlacements.center;
    return InkWell(
      key: Key('shared-placement-$value'),
      onTap: () => _style(style.copyWith(textPlacement: value)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 92,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFA56B45) : const Color(0xFFE6E8EC),
          ),
          color: selected ? const Color(0xFFF6F1EA) : Colors.white,
        ),
        child: Column(
          children: <Widget>[
            if (above) _positionLines(),
            Container(
              height: 32,
              alignment: center ? Alignment.center : Alignment.bottomCenter,
              decoration: BoxDecoration(
                color: const Color(0xFFE7D3C4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: !above && !outside
                  ? Padding(
                      padding: const EdgeInsets.all(4),
                      child: _positionLines(onPhoto: true),
                    )
                  : null,
            ),
            if (outside) _positionLines(),
            const SizedBox(height: 4),
            Text(
              HomeSharedEntryPlacements.label(value),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionLines({bool onPhoto = false}) {
    return Column(
      children: <Widget>[
        Container(
          height: 3,
          margin: const EdgeInsets.only(bottom: 3),
          color: onPhoto ? Colors.white : const Color(0xFF3A2A20),
        ),
        Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: onPhoto ? const Color(0xCCFFFFFF) : const Color(0xFF8A7568),
        ),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String valueLabel,
    required double reset,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              valueLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            IconButton(
              tooltip: '重設為緊湊',
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged(reset),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _grid(bool wide, List<Widget> children) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final Widget child in children) ...<Widget>[
            child,
            const SizedBox(height: 8),
          ],
        ],
      );
    }
    final List<Widget> rows = <Widget>[];
    for (int index = 0; index < children.length; index += 2) {
      final Widget right = index + 1 < children.length
          ? children[index + 1]
          : const SizedBox.shrink();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: children[index]),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        ),
      );
      rows.add(const SizedBox(height: 8));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _chips(
    String label,
    List<String> values,
    String Function(String value) labelOf,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final String value in values)
              ChoiceChip(
                label: Text(labelOf(value)),
                selected: selected == value,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    );
  }

  String _sizeLabel(String value) {
    return switch (value) {
      HomeRoomSimpleTextSizes.small => '小',
      HomeRoomSimpleTextSizes.large => '大',
      _ => '中',
    };
  }

  String _weightLabel(String value) {
    return switch (value) {
      HomeRoomSimpleTextWeights.regular => '一般',
      HomeRoomSimpleTextWeights.medium => '中等',
      _ => '粗體',
    };
  }
}
