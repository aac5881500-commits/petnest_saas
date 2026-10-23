import 'home_card_image.dart';
import 'home_section_settings_group.dart';
import 'home_section_layout_option_card.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_bridge.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_editor.dart';
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
    this.availability,
    this.displayStyles,
    this.onDisplayStyles,
  });

  final String? availability;
  final HomeNewsSectionSetting setting;
  final HomeThemeModel theme;
  final bool locked;
  final ValueChanged<HomeNewsSectionSetting> onChanged;
  final VoidCallback onOpenFeatures;
  final HomeDisplayStyleSetting? displayStyles;
  final ValueChanged<HomeDisplayStyleSetting>? onDisplayStyles;

  @override
  State<NewsSectionSettingsPanel> createState() =>
      _NewsSectionSettingsPanelState();
}

class _NewsSectionSettingsPanelState extends State<NewsSectionSettingsPanel> {
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
    return ListView(
      key: const PageStorageKey<String>('news-section-settings'),
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: [
        HomeSectionSettingsGroup(
          title: '首頁顯示',
          children: [
            const Text('控制首頁消息呈現，不變更公告及活動內容。'),
            if (widget.availability != null) Text(widget.availability!),
            TextButton(
              onPressed: widget.onOpenFeatures,
              child: const Text('前往消息管理'),
            ),
          ],
        ),
        HomeSectionSettingsGroup(
          title: '展示版型',
          children: [
            HomeSectionLayoutPicker(
              theme: widget.theme,
              selectedId: HomeNewsLayouts.migrate(widget.setting.layout),
              onSelected: (value) =>
                  _update(widget.setting.copyWith(layout: value)),
              choices: [
                for (final item in HomeNewsLayouts.all)
                  HomeSectionLayoutChoice(
                    id: item,
                    title: HomeNewsLayouts.label(item),
                    description: switch (item) {
                      HomeNewsLayouts.multiLine => '展示多則消息與摘要',
                      HomeNewsLayouts.singleLine => '精簡呈現最新消息、類型與日期',
                      _ => '半寬入口，連結既有消息頁面',
                    },
                    badge: '',
                    preview: NewsSectionLayoutPreview(
                      layout: item,
                      theme: widget.theme,
                    ),
                  ),
              ],
            ),
          ],
        ),
        HomeSectionSettingsGroup(title: '目前版型設定', children: [_details(layout)]),
      ],
    );
  }

  Widget _details(String layout) {
    final HomeNewsSectionSetting setting = widget.setting;
    final bool single = layout == HomeNewsLayouts.singleLine;
    final bool multi = layout == HomeNewsLayouts.multiLine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (layout == HomeNewsLayouts.compactCard)
          HomeCardImageSettings(
            setting: setting.cardImage,
            onChanged: (value) => _update(setting.copyWith(cardImage: value)),
          ),
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
            values: const <String>['2', '3', '5'],
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
        HomeSectionSettingsGroup(
          title: '進階外觀',
          storageId: 'news-section-advanced-appearance',
          children: [
            if (widget.onDisplayStyles != null) _styleEditor(),
            if (widget.onDisplayStyles == null) ...<Widget>[
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
          ],
        ),
      ],
    );
  }

  Widget _styleEditor() {
    final HomeDisplayStyleSetting display =
        widget.displayStyles ?? HomeDisplayStyleSetting.unset;
    final HomeDisplayStyle legacy = newsDisplayLegacy(widget.setting);
    final String mode = display.effectiveMode(
      sectionId: HomeDisplaySections.announcements,
      legacy: legacy,
      baseline: HomeDisplayStyle.classic,
    );
    final HomeDisplayStyle effective = display.resolve(
      sectionId: HomeDisplaySections.announcements,
      legacy: legacy,
      baseline: HomeDisplayStyle.classic,
    );
    return HomeDisplaySectionOverride(
      basicAppearanceOnly: true,
      label: '消息展示',
      shared: display.style,
      mode: mode,
      effective: effective,
      onInherit: () {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.announcements,
            mode: HomeDisplayStyleModes.inherit,
            clearOverride: true,
          ),
        );
      },
      onCustom: () {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.announcements,
            mode: HomeDisplayStyleModes.custom,
          ),
        );
      },
      onEdit: (HomeDisplayStyle edited) {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.announcements,
            mode: HomeDisplayStyleModes.custom,
            override: edited.diff(display.style),
          ),
        );
      },
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
