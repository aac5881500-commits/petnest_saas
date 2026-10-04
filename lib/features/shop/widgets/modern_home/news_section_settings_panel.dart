import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/news_section_layout_preview.dart';

/// 消息展示右側設定。只改草稿，不直接寫入 Firestore。
class NewsSectionSettingsPanel extends StatefulWidget {
  const NewsSectionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.locked,
    required this.onChanged,
    required this.onOpenFeatures,
  });

  final HomeNewsSectionSetting setting;
  final HomeThemeModel theme;
  final bool locked;
  final ValueChanged<HomeNewsSectionSetting> onChanged;
  final VoidCallback onOpenFeatures;

  @override
  State<NewsSectionSettingsPanel> createState() =>
      _NewsSectionSettingsPanelState();
}

class _NewsSectionSettingsPanelState extends State<NewsSectionSettingsPanel> {
  int _pane = 0;
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.setting.title);
  }

  @override
  void didUpdateWidget(NewsSectionSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_titleController.text != widget.setting.title) {
      _titleController.text = widget.setting.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _update(HomeNewsSectionSetting next) {
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locked) {
      return ListView(
        primary: false,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
        children: <Widget>[
          Text(kHomeNewsLockedMessage, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const Key('home-news-open-features'),
              onPressed: widget.onOpenFeatures,
              child: const Text('前往前台功能'),
            ),
          ),
        ],
      );
    }
    final String layout = HomeNewsLayouts.migrate(widget.setting.layout);
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
        Expanded(child: _pane == 0 ? _layouts() : _details(layout)),
      ],
    );
  }

  Widget _layouts() {
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: <Widget>[
        for (final String layout in HomeNewsLayouts.all) _choice(layout),
      ],
    );
  }

  Widget _choice(String layout) {
    final bool selected =
        HomeNewsLayouts.migrate(widget.setting.layout) == layout;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('news-layout-$layout'),
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (selected) {
              return;
            }
            _update(widget.setting.copyWith(layout: layout));
          },
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? widget.theme.primaryColor
                    : const Color(0xFFE6E8EC),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                NewsSectionLayoutPreview(layout: layout, theme: widget.theme),
                const SizedBox(height: 8),
                Text(
                  HomeNewsLayouts.label(layout),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _details(String layout) {
    final HomeNewsSectionSetting setting = widget.setting;
    final bool single = layout == HomeNewsLayouts.singleLine;
    final bool multi = layout == HomeNewsLayouts.multiLine;
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: <Widget>[
        const Text('內容來源', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _chips(
          values: HomeNewsSources.all,
          labelOf: HomeNewsSources.label,
          selected: HomeNewsSources.migrate(setting.source),
          onChanged: (String value) {
            _update(setting.copyWith(source: value));
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: '首頁標題',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) {
            _update(setting.copyWith(title: value.trim()));
          },
        ),
        if (multi) ...<Widget>[
          const Text('顯示數量', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _chips(
            values: const <String>['2', '3'],
            labelOf: (String value) => '$value 筆',
            selected:
                '${HomeNewsSectionSetting.migrateCount(setting.multiLineCount)}',
            onChanged: (String value) {
              _update(setting.copyWith(multiLineCount: int.parse(value)));
            },
          ),
          const SizedBox(height: 8),
          _switch('顯示摘要', setting.showSummary, (bool value) {
            _update(setting.copyWith(showSummary: value));
          }),
          _switch('顯示日期', setting.showDate, (bool value) {
            _update(setting.copyWith(showDate: value));
          }),
          _switch('顯示類型標籤', setting.showTypeBadge, (bool value) {
            _update(setting.copyWith(showTypeBadge: value));
          }),
          _switch('顯示查看全部', setting.showArrow, (bool value) {
            _update(setting.copyWith(showArrow: value));
          }),
        ],
        if (single)
          _switch('顯示箭頭', setting.showArrow, (bool value) {
            _update(setting.copyWith(showArrow: value));
          }),
        const Text('文字對齊', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _chips(
          values: HomeNewsTextAligns.all,
          labelOf: HomeNewsTextAligns.label,
          selected: setting.textAlign,
          onChanged: (String value) {
            _update(setting.copyWith(textAlign: value));
          },
        ),
        const SizedBox(height: 12),
        const Text('卡片外觀', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _chips(
          values: HomeNewsSurfaces.all,
          labelOf: HomeNewsSurfaces.label,
          selected: setting.surfaceStyle,
          onChanged: (String value) {
            _update(setting.copyWith(surfaceStyle: value));
          },
        ),
      ],
    );
  }

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _chips({
    required List<String> values,
    required String Function(String value) labelOf,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String value in values)
          ChoiceChip(
            label: Text(labelOf(value)),
            selected: selected == value,
            onSelected: (_) => onChanged(value),
          ),
      ],
    );
  }
}
