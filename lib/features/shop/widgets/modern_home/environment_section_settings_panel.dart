import 'environment_end_entry.dart';
import 'package:flutter/material.dart';
import 'environment_home_image_settings.dart';
import 'modern_home_environment_section.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/environment_section_layout_preview.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_bridge.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_editor.dart';

/// 環境展示右側設定。版型與顯示細節只改草稿。
class EnvironmentSectionSettingsPanel extends StatefulWidget {
  const EnvironmentSectionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.onChanged,
    this.visible = true,
    this.onVisibleChanged,
    this.environmentIntro = const {},
    this.onManage,
    this.displayStyles,
    this.onDisplayStyles,
  });

  final bool visible;
  final ValueChanged<bool>? onVisibleChanged;
  final Map<String, dynamic> environmentIntro;
  final VoidCallback? onManage;
  final HomeEnvironmentSectionSetting setting;
  final HomeThemeModel theme;
  final ValueChanged<HomeEnvironmentSectionSetting> onChanged;
  final HomeDisplayStyleSetting? displayStyles;
  final ValueChanged<HomeDisplayStyleSetting>? onDisplayStyles;

  @override
  State<EnvironmentSectionSettingsPanel> createState() =>
      _EnvironmentSectionSettingsPanelState();
}

class _EnvironmentSectionSettingsPanelState
    extends State<EnvironmentSectionSettingsPanel> {
  late final TextEditingController _cardTitleController,
      _cardSubtitleController;
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.setting.title);
    _subtitleController = TextEditingController(text: widget.setting.subtitle);
    _cardTitleController = TextEditingController(
      text: widget.setting.cardTitle,
    );
    _cardSubtitleController = TextEditingController(
      text: widget.setting.cardSubtitle,
    );
  }

  @override
  void didUpdateWidget(EnvironmentSectionSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cardTitleController.text != widget.setting.cardTitle) {
      _cardTitleController.text = widget.setting.cardTitle;
    }
    if (_cardSubtitleController.text != widget.setting.cardSubtitle) {
      _cardSubtitleController.text = widget.setting.cardSubtitle;
    }
    if (_titleController.text != widget.setting.title) {
      _titleController.text = widget.setting.title;
    }
    if (_subtitleController.text != widget.setting.subtitle) {
      _subtitleController.text = widget.setting.subtitle;
    }
  }

  @override
  void dispose() {
    _cardTitleController.dispose();
    _cardSubtitleController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  void _update(HomeEnvironmentSectionSetting next) {
    widget.onChanged(next);
  }

  Widget _card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );

  Widget _text(
    TextEditingController controller,
    String label,
    ValueChanged<String> changed, {
    int max = 80,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      maxLength: max,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: changed,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final setting = widget.setting;
    final keys = (widget.environmentIntro['facilityKeys'] is List
        ? (widget.environmentIntro['facilityKeys'] as List)
              .whereType<String>()
              .toList()
        : <String>[]);
    final facilities = ModernHomeEnvironmentSection.facilitiesFor(
      keys,
      introduction: widget.environmentIntro,
    );
    final selected = setting.selectedFacilities(facilities);
    return ListView(
      key: const PageStorageKey('environment-section-settings'),
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: [
        _card('首頁展示', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('在首頁顯示環境展示'),
            subtitle: const Text('只控制首頁的獨立展示，不影響首頁小卡及功能內頁。'),
            value: widget.visible,
            onChanged: widget.onVisibleChanged,
          ),
          if (!widget.visible)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('目前未在首頁展示，仍可調整下方設定。'),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示區塊標題'),
            value: setting.showTitle,
            onChanged: (v) => _update(setting.copyWith(showTitle: v)),
          ),
          _text(
            _titleController,
            '區塊標題文字',
            (v) => _update(setting.copyWith(title: v)),
            max: 24,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示簡短說明'),
            value: setting.showDescription,
            onChanged: (v) => _update(setting.copyWith(showDescription: v)),
          ),
          _text(
            _subtitleController,
            '區塊說明文字',
            (v) => _update(setting.copyWith(subtitle: v)),
            max: 40,
          ),
        ]),
        _card('展示版型', [
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 420 ? 2 : 1;
              return Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  for (final layout in HomeEnvironmentLayouts.all)
                    SizedBox(
                      width: (constraints.maxWidth - (cols - 1) * 10) / cols,
                      child: _choice(
                        layout: layout,
                        description: switch (layout) {
                          HomeEnvironmentLayouts.facilityScroll =>
                            '展示已選設備，列表末端入口可查看完整環境。',
                          HomeEnvironmentLayouts.simpleEntry =>
                            '獨立入口卡，與首頁小卡分開設定。',
                          HomeEnvironmentLayouts.imageEntry => '使用現有環境照片作為入口。',
                          _ => '照片與文案並排，缺圖時保留可用入口。',
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ]),
        _card('目前版型設定', [
          if (setting.layout == HomeEnvironmentLayouts.facilityScroll) ...[
            _label('首頁顯示設備數量'),
            Wrap(
              spacing: 8,
              children: [
                for (final count in [4, 6, 8, 0])
                  ChoiceChip(
                    label: Text(count == 0 ? '全部' : '$count 個'),
                    selected: setting.facilityLimit == count,
                    onSelected: (_) =>
                        _update(setting.copyWith(facilityLimit: count)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '已設定 ${facilities.length} 項設備，首頁展示 ${selected.length} 項',
              ),
            ),
            if (facilities.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _pickFacilities(facilities),
                icon: const Icon(Icons.checklist),
                label: const Text('挑選首頁設備'),
              )
            else ...[
              const Text('目前沒有可展示的設備。'),
              TextButton(
                onPressed: widget.onManage,
                child: const Text('前往環境介紹管理'),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('顯示末端環境入口'),
              subtitle: const Text('入口放在設備列表最後，點擊可查看完整環境介紹。'),
              value: setting.showEndEntryCard,
              onChanged: (v) => _update(setting.copyWith(showEndEntryCard: v)),
            ),

            if (setting.showEndEntryCard) ...[
              _label('入口樣式'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final style in HomeEnvironmentEndEntryStyles.all)
                    ChoiceChip(
                      selected:
                          HomeEnvironmentEndEntryStyles.migrate(
                            setting.endEntryStyle,
                          ) ==
                          style,
                      onSelected: (_) =>
                          _update(setting.copyWith(endEntryStyle: style)),
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: IgnorePointer(
                              child: EnvironmentEndEntry(
                                style: style,
                                color: widget.theme.primaryColor,
                                onPressed: () {},
                              ),
                            ),
                          ),
                          Text(HomeEnvironmentEndEntryStyles.label(style)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ] else ...[
            _text(
              _cardTitleController,
              '卡片內標題',
              (v) => _update(setting.copyWith(cardTitle: v)),
              max: 40,
            ),
            _text(
              _cardSubtitleController,
              '卡片內說明',
              (v) => _update(setting.copyWith(cardSubtitle: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('顯示卡片內說明'),
              value: setting.showSubtitle,
              onChanged: (v) => _update(setting.copyWith(showSubtitle: v)),
            ),
            EnvironmentHomeImageSettings(
              setting: setting,
              environmentIntro: widget.environmentIntro,
              onChanged: _update,
              onPickLegacy: _pickImage,
              onManage: widget.onManage,
            ),
            if (setting.layout == HomeEnvironmentLayouts.simpleEntry) ...[
              _label('卡片尺寸'),
              _segments(
                values: HomeEnvironmentCardSizes.all,
                labelOf: HomeEnvironmentCardSizes.label,
                selected: setting.simpleCardSize,
                onChanged: (v) => _update(setting.copyWith(simpleCardSize: v)),
              ),
            ] else ...[
              if (setting.layout == HomeEnvironmentLayouts.imageEntry) ...[
                _label('圖片高度'),
                _segments(
                  values: HomeEnvironmentImageHeights.all,
                  labelOf: HomeEnvironmentImageHeights.label,
                  selected: setting.imageHeight,
                  onChanged: (v) => _update(setting.copyWith(imageHeight: v)),
                ),
                _label('文字位置'),
                _segments(
                  values: HomeEnvironmentTextPlacements.all,
                  labelOf: HomeEnvironmentTextPlacements.label,
                  selected: setting.imageTextPlacement,
                  onChanged: _setTextPlacement,
                ),
              ],
              if (setting.layout == HomeEnvironmentLayouts.editorial)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('圖片放在左側'),
                  value: setting.editorialImageLeft,
                  onChanged: (v) =>
                      _update(setting.copyWith(editorialImageLeft: v)),
                ),
            ],
          ],
          ExpansionTile(
            key: const PageStorageKey<String>(
              'environment-section-advanced-appearance',
            ),
            tilePadding: EdgeInsets.zero,
            title: const Text('進階外觀'),
            children: [
              if (setting.layout == HomeEnvironmentLayouts.simpleEntry &&
                  !setting.usesPlatformImage) ...[
                _label('卡片底框'),
                _segments(
                  values: HomeEnvironmentSurfaces.all,
                  labelOf: HomeEnvironmentSurfaces.label,
                  selected: setting.simpleSurface,
                  onChanged: (v) => _update(setting.copyWith(simpleSurface: v)),
                ),
                _label('圖示'),
                _segments(
                  values: HomeEnvironmentIcons.all,
                  labelOf: HomeEnvironmentIcons.label,
                  selected: setting.simpleIcon,
                  onChanged: (v) => _update(setting.copyWith(simpleIcon: v)),
                ),
              ],
              if (widget.onDisplayStyles != null) _styleEditor(),
            ],
          ),
        ]),
      ],
    );
  }

  Future<void> _pickImage() async {
    final urls = HomeEnvironmentSectionSetting.availableImageUrls(
      widget.environmentIntro,
      source: widget.setting.imageSource,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇現有環境照片'),
        content: SizedBox(
          width: 520,
          height: 340,
          child: urls.isEmpty
              ? const Center(child: Text('目前沒有此來源的照片，請先到環境介紹管理設定。'))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: urls.length,
                  itemBuilder: (context, index) => InkWell(
                    onTap: () => Navigator.pop(context, urls[index]),
                    child: Image.network(
                      urls[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) =>
                          const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      _update(widget.setting.copyWith(selectedImageUrl: result));
    }
  }

  Future<void> _pickFacilities(List<Map<String, dynamic>> available) async {
    final byKey = {for (final item in available) item['key'].toString(): item};
    final existing = widget.setting.facilitySelectionCustomized
        ? widget.setting.homeFacilityKeys
        : byKey.keys.toList();
    final selected = existing.where(byKey.containsKey).toSet();
    final order = [
      ...existing.where(byKey.containsKey),
      ...byKey.keys.where((id) => !existing.contains(id)),
    ];
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('挑選首頁設備與排序'),
          content: SizedBox(
            width: 500,
            height: 360,
            child: ReorderableListView.builder(
              itemCount: order.length,
              onReorder: (oldIndex, newIndex) => refresh(() {
                if (newIndex > oldIndex) newIndex--;
                final id = order.removeAt(oldIndex);
                order.insert(newIndex, id);
              }),
              itemBuilder: (context, index) {
                final id = order[index];
                return CheckboxListTile(
                  key: ValueKey(id),
                  contentPadding: const EdgeInsets.only(right: 40),
                  title: Text(byKey[id]!['title'].toString()),
                  value: selected.contains(id),
                  onChanged: (v) => refresh(() {
                    v == true ? selected.add(id) : selected.remove(id);
                  }),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                order.where(selected.contains).toList(),
              ),
              child: const Text('套用到草稿'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      _update(
        widget.setting.copyWith(
          homeFacilityKeys: result,
          facilitySelectionCustomized: true,
        ),
      );
    }
  }

  Widget _choice({
    required String layout,
    required String description,
    bool recommended = false,
  }) {
    final bool selected = widget.setting.layout == layout;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('environment-layout-$layout'),
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
                EnvironmentSectionLayoutPreview(
                  layout: layout,
                  theme: widget.theme,
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        HomeEnvironmentLayouts.label(layout),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (recommended) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.theme.primaryColor.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '推薦',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: widget.theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
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

  Widget _styleEditor() {
    final HomeDisplayStyleSetting display =
        widget.displayStyles ?? HomeDisplayStyleSetting.unset;
    final HomeDisplayStyle legacy = environmentDisplayLegacy(widget.setting);
    final String mode = display.effectiveMode(
      sectionId: HomeDisplaySections.facilities,
      legacy: legacy,
      baseline: HomeDisplayStyle.facilitiesBaseline,
    );
    final HomeDisplayStyle effective = display.resolve(
      sectionId: HomeDisplaySections.facilities,
      legacy: legacy,
      baseline: HomeDisplayStyle.facilitiesBaseline,
    );
    return HomeDisplaySectionOverride(
      label: '環境介紹',
      shared: display.style,
      mode: mode,
      effective: effective,
      onInherit: () {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.facilities,
            mode: HomeDisplayStyleModes.inherit,
            clearOverride: true,
          ),
        );
      },
      onCustom: () {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.facilities,
            mode: HomeDisplayStyleModes.custom,
          ),
        );
      },
      onEdit: (HomeDisplayStyle edited) {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.facilities,
            mode: HomeDisplayStyleModes.custom,
            override: edited.diff(display.style),
          ),
        );
      },
    );
  }

  void _setTextPlacement(String value) {
    _update(widget.setting.copyWith(imageTextPlacement: value));
    final display = widget.displayStyles ?? HomeDisplayStyleSetting.unset;
    final effective = display.resolve(
      sectionId: HomeDisplaySections.facilities,
      legacy: environmentDisplayLegacy(widget.setting),
      baseline: HomeDisplayStyle.facilitiesBaseline,
    );
    final edited = effective.copyWith(
      textPosition: value == HomeEnvironmentTextPlacements.below
          ? HomeDisplayTextPositions.below
          : HomeDisplayTextPositions.overlay,
    );
    widget.onDisplayStyles?.call(
      display.updateSection(
        HomeDisplaySections.facilities,
        mode: HomeDisplayStyleModes.custom,
        override: edited.diff(display.style),
      ),
    );
  }

  Widget _segments({
    required List<String> values,
    required String Function(String value) labelOf,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    final String current = values.contains(selected) ? selected : values.first;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final String value in values)
          ChoiceChip(
            label: Text(labelOf(value)),
            selected: current == value,
            onSelected: (_) => onChanged(value),
          ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
