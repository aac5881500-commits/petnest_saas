import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/faq_section_layout_preview.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_layout_option_card.dart';

/// 常見問題右側設定。只改草稿，不直接寫入 Firestore。
class FaqSectionSettingsPanel extends StatefulWidget {
  const FaqSectionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.locked,
    required this.onChanged,
    required this.onOpenFeatures,
  });

  final HomeInformationSectionsSetting setting;
  final HomeThemeModel theme;
  final bool locked;
  final ValueChanged<HomeInformationSectionsSetting> onChanged;
  final VoidCallback onOpenFeatures;

  @override
  State<FaqSectionSettingsPanel> createState() =>
      _FaqSectionSettingsPanelState();
}

class _FaqSectionSettingsPanelState extends State<FaqSectionSettingsPanel> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;

  HomeFaqSectionSetting get _faq => widget.setting.faq;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _faq.title);
    _subtitle = TextEditingController(text: _faq.subtitle);
  }

  @override
  void didUpdateWidget(FaqSectionSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_title.text != _faq.title) {
      _title.text = _faq.title;
    }
    if (_subtitle.text != _faq.subtitle) {
      _subtitle.text = _faq.subtitle;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  void _update(HomeFaqSectionSetting next) {
    widget.onChanged(widget.setting.copyWith(faq: next));
  }

  @override
  Widget build(BuildContext context) {
    final HomeFaqSectionSetting setting = _faq;
    final String layout = HomeFaqLayouts.migrate(setting.layout);
    final bool showsQuestions =
        layout == HomeFaqLayouts.preview ||
        layout == HomeFaqLayouts.horizontalCards ||
        layout == HomeFaqLayouts.twoColumnCards;
    final bool answerPreview =
        layout == HomeFaqLayouts.horizontalCards ||
        layout == HomeFaqLayouts.twoColumnCards;
    final bool entryCount =
        layout == HomeFaqLayouts.compact || layout == HomeFaqLayouts.singleLine;
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      children: <Widget>[
        if (widget.locked) ...<Widget>[
          Card(
            color: const Color(0xFFFFF7ED),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFFED7AA)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    kHomeFaqLockedMessage,
                    style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('home-faq-open-features'),
                    onPressed: widget.onOpenFeatures,
                    child: const Text('前往前台功能'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        IgnorePointer(
          ignoring: widget.locked,
          child: Opacity(
            opacity: widget.locked ? 0.45 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                HomeDraftSwitch(
                  title: '首頁顯示',
                  value: setting.showOnHome,
                  onChanged: (bool value) {
                    _update(setting.copyWith(showOnHome: value));
                  },
                ),
                const SizedBox(height: 8),
                HomeSectionLayoutPicker(
                  theme: widget.theme,
                  selectedId: layout,
                  onSelected: (String value) {
                    _update(setting.copyWith(layout: value));
                  },
                  choices: <HomeSectionLayoutChoice>[
                    for (final String item in HomeFaqLayouts.all)
                      HomeSectionLayoutChoice(
                        id: item,
                        title: HomeFaqLayouts.label(item),
                        description: HomeFaqLayouts.description(item),
                        badge: HomeFaqLayouts.badge(item),
                        preview: FaqSectionLayoutPreview(
                          layout: item,
                          theme: widget.theme,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: '標題',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String value) {
                    _update(setting.copyWith(title: value.trim()));
                  },
                ),
                TextField(
                  controller: _subtitle,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: '副標題',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String value) {
                    _update(setting.copyWith(subtitle: value.trim()));
                  },
                ),
                if (showsQuestions)
                  HomeDraftCountChips(
                    label: '顯示題數',
                    values: const <int>[2, 3, 4, 5],
                    selected: HomeFaqSectionSetting.migratePreviewCount(
                      setting.previewCount,
                    ),
                    onChanged: (int value) {
                      _update(setting.copyWith(previewCount: value));
                    },
                  ),
                if (answerPreview)
                  HomeDraftSwitch(
                    title: '顯示答案預覽',
                    value: setting.showAnswerPreview,
                    onChanged: (bool value) {
                      _update(setting.copyWith(showAnswerPreview: value));
                    },
                  ),
                if (entryCount)
                  HomeDraftSwitch(
                    title: '顯示問題總數',
                    value: setting.showQuestionCount,
                    onChanged: (bool value) {
                      _update(setting.copyWith(showQuestionCount: value));
                    },
                  ),
                if (showsQuestions)
                  HomeDraftSwitch(
                    title: '顯示查看全部',
                    value: setting.showViewAll,
                    onChanged: (bool value) {
                      _update(setting.copyWith(showViewAll: value));
                    },
                  ),
                if (showsQuestions) ...<Widget>[
                  const Text(
                    '開頭樣式',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final String style in HomeFaqLeadingStyles.all)
                        ChoiceChip(
                          label: Text(HomeFaqLeadingStyles.label(style)),
                          selected:
                              HomeFaqLeadingStyles.migrate(
                                setting.leadingStyle,
                              ) ==
                              style,
                          onSelected: (_) {
                            _update(setting.copyWith(leadingStyle: style));
                          },
                        ),
                    ],
                  ),
                ],
                HomeDraftSwitch(
                  title: '保留住宿服務快捷入口',
                  value: setting.keepServiceEntry,
                  onChanged: (bool value) {
                    _update(setting.copyWith(keepServiceEntry: value));
                  },
                ),
                if (!setting.showOnHome && !setting.keepServiceEntry)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(kHomeInfoHiddenEntryMessage),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
