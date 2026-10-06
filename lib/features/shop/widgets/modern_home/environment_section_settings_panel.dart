import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/environment_section_layout_preview.dart';

/// 環境展示右側設定。版型與顯示細節只改草稿。
class EnvironmentSectionSettingsPanel extends StatefulWidget {
  const EnvironmentSectionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.onChanged,
  });

  final HomeEnvironmentSectionSetting setting;
  final HomeThemeModel theme;
  final ValueChanged<HomeEnvironmentSectionSetting> onChanged;

  @override
  State<EnvironmentSectionSettingsPanel> createState() =>
      _EnvironmentSectionSettingsPanelState();
}

class _EnvironmentSectionSettingsPanelState
    extends State<EnvironmentSectionSettingsPanel> {
  int _pane = 0;
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.setting.title);
    _subtitleController = TextEditingController(text: widget.setting.subtitle);
  }

  @override
  void didUpdateWidget(EnvironmentSectionSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_titleController.text != widget.setting.title) {
      _titleController.text = widget.setting.title;
    }
    if (_subtitleController.text != widget.setting.subtitle) {
      _subtitleController.text = widget.setting.subtitle;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  void _update(HomeEnvironmentSectionSetting next) {
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
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
        Expanded(child: _pane == 1 ? _detailPane() : _layoutPane()),
      ],
    );
  }

  Widget _layoutPane() {
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: <Widget>[
        _choice(
          layout: HomeEnvironmentLayouts.facilityScroll,
          description: '已選設備單排橫滑，最後可進入環境介紹。',
        ),
        _choice(
          layout: HomeEnvironmentLayouts.simpleEntry,
          description: '只留一張入口，不列出個別設備。',
        ),
        _choice(
          layout: HomeEnvironmentLayouts.imageEntry,
          description: '用環境介紹已上傳的照片當首頁入口。',
        ),
        _choice(
          layout: HomeEnvironmentLayouts.editorial,
          description: '照片與文字並排。沒有照片時改回入口卡，不會留白洞。',
        ),
      ],
    );
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

  Widget _detailPane() {
    final String layout = widget.setting.layout;
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: <Widget>[
        if (layout == HomeEnvironmentLayouts.facilityScroll) ...<Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示標題'),
            value: widget.setting.showTitle,
            onChanged: (bool value) {
              _update(widget.setting.copyWith(showTitle: value));
            },
          ),
          TextField(
            controller: _titleController,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: '標題文字',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) {
              _update(widget.setting.copyWith(title: value.trim()));
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示最後的環境介紹入口'),
            value: widget.setting.showEndEntryCard,
            onChanged: (bool value) {
              _update(widget.setting.copyWith(showEndEntryCard: value));
            },
          ),
        ],
        if (layout == HomeEnvironmentLayouts.simpleEntry ||
            layout == HomeEnvironmentLayouts.imageEntry) ...<Widget>[
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
          TextField(
            controller: _subtitleController,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '副標題',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) {
              _update(widget.setting.copyWith(subtitle: value.trim()));
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示副標題'),
            value: widget.setting.showSubtitle,
            onChanged: (bool value) {
              _update(widget.setting.copyWith(showSubtitle: value));
            },
          ),
        ],
        if (layout == HomeEnvironmentLayouts.simpleEntry) ...<Widget>[
          _label('卡片規格'),
          _segments(
            values: HomeEnvironmentCardSizes.all,
            labelOf: HomeEnvironmentCardSizes.label,
            selected: widget.setting.simpleCardSize,
            onChanged: (String value) {
              _update(widget.setting.copyWith(simpleCardSize: value));
            },
          ),
          const SizedBox(height: 12),
          _label('卡片樣式'),
          _segments(
            values: HomeEnvironmentSurfaces.all,
            labelOf: HomeEnvironmentSurfaces.label,
            selected: widget.setting.simpleSurface,
            onChanged: (String value) {
              _update(widget.setting.copyWith(simpleSurface: value));
            },
          ),
          const SizedBox(height: 12),
          _label('圖示'),
          _segments(
            values: HomeEnvironmentIcons.all,
            labelOf: HomeEnvironmentIcons.label,
            selected: widget.setting.simpleIcon,
            onChanged: (String value) {
              _update(widget.setting.copyWith(simpleIcon: value));
            },
          ),
        ],
        if (layout == HomeEnvironmentLayouts.imageEntry) ...<Widget>[
          _label('圖片高度'),
          _segments(
            values: HomeEnvironmentImageHeights.all,
            labelOf: HomeEnvironmentImageHeights.label,
            selected: widget.setting.imageHeight,
            onChanged: (String value) {
              _update(widget.setting.copyWith(imageHeight: value));
            },
          ),
          const SizedBox(height: 12),
          _label('文字位置'),
          _segments(
            values: HomeEnvironmentTextPlacements.all,
            labelOf: HomeEnvironmentTextPlacements.label,
            selected: widget.setting.imageTextPlacement,
            onChanged: (String value) {
              _update(widget.setting.copyWith(imageTextPlacement: value));
            },
          ),
        ],
      ],
    );
  }

  Widget _segments({
    required List<String> values,
    required String Function(String value) labelOf,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    final String current = values.contains(selected) ? selected : values.first;
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: <ButtonSegment<String>>[
        for (final String value in values)
          ButtonSegment<String>(value: value, label: Text(labelOf(value))),
      ],
      selected: <String>{current},
      onSelectionChanged: (Set<String> value) => onChanged(value.first),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
