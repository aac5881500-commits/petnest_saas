import 'home_card_image.dart';
import 'home_section_settings_group.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_layout_option_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/policy_section_layout_preview.dart';

/// 入住須知右側設定。只改草稿，不直接寫入 Firestore。
class PolicySectionSettingsPanel extends StatefulWidget {
  const PolicySectionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.onChanged,
    this.onManage,
  });

  final VoidCallback? onManage;
  final HomeInformationSectionsSetting setting;
  final HomeThemeModel theme;
  final ValueChanged<HomeInformationSectionsSetting> onChanged;

  @override
  State<PolicySectionSettingsPanel> createState() =>
      _PolicySectionSettingsPanelState();
}

class _PolicySectionSettingsPanelState
    extends State<PolicySectionSettingsPanel> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;

  HomePolicySectionSetting get _policy => widget.setting.policy;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _policy.title);
    _subtitle = TextEditingController(text: _policy.subtitle);
  }

  @override
  void didUpdateWidget(PolicySectionSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_title.text != _policy.title) {
      _title.text = _policy.title;
    }
    if (_subtitle.text != _policy.subtitle) {
      _subtitle.text = _policy.subtitle;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  void _update(HomePolicySectionSetting next) {
    widget.onChanged(widget.setting.copyWith(policy: next));
  }

  @override
  Widget build(BuildContext context) {
    final HomePolicySectionSetting setting = _policy;
    final String layout = HomePolicyLayouts.migrate(setting.layout);
    final bool summary = layout == HomePolicyLayouts.summary;
    return ListView(
      key: const PageStorageKey<String>('policy-section-settings'),
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      children: <Widget>[
        const Text('此處只調整首頁呈現，條款內容請至原管理頁維護。'),
        if (widget.onManage != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onManage,
              child: const Text('管理入住須知'),
            ),
          ),
        HomeDraftSwitch(
          title: '首頁顯示',
          subtitle: '只控制首頁區塊，不會停用預約流程條款',
          value: setting.showOnHome,
          onChanged: (bool value) {
            _update(setting.copyWith(showOnHome: value));
          },
        ),
        const SizedBox(height: 8),
        const Text('展示版型', style: TextStyle(fontWeight: FontWeight.bold)),
        HomeSectionLayoutPicker(
          theme: widget.theme,
          selectedId: layout,
          onSelected: (String value) {
            _update(setting.copyWith(layout: value));
          },
          choices: <HomeSectionLayoutChoice>[
            for (final String item in HomePolicyLayouts.all)
              HomeSectionLayoutChoice(
                id: item,
                title: HomePolicyLayouts.label(item),
                description: HomePolicyLayouts.description(item),
                badge: HomePolicyLayouts.badge(item),
                preview: PolicySectionLayoutPreview(
                  layout: item,
                  theme: widget.theme,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('目前版型設定', style: TextStyle(fontWeight: FontWeight.bold)),
        if (layout == HomePolicyLayouts.compact)
          HomeCardImageSettings(
            setting: setting.cardImage,
            onChanged: (value) => _update(setting.copyWith(cardImage: value)),
          ),
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
        if (summary) ...<Widget>[
          HomeDraftCountChips(
            label: '摘要數量',
            values: const <int>[2, 3],
            selected: HomePolicySectionSetting.migrateSummaryCount(
              setting.summaryItemCount,
            ),
            onChanged: (int value) {
              _update(setting.copyWith(summaryItemCount: value));
            },
          ),
          HomeSectionSettingsGroup(
            title: '進階外觀',
            storageId: 'policy-section-advanced-appearance',
            children: [
              HomeDraftSwitch(
                title: '顯示條款版本',
                value: setting.showVersion,
                onChanged: (bool value) {
                  _update(setting.copyWith(showVersion: value));
                },
              ),
              HomeDraftSwitch(
                title: '顯示適用服務',
                value: setting.showCoverage,
                onChanged: (bool value) {
                  _update(setting.copyWith(showCoverage: value));
                },
              ),
            ],
          ),
        ],
        HomeDraftSwitch(
          title: '保留住宿服務快捷入口',
          subtitle: '控制我們的服務中的入口，與首頁獨立展示分開設定。',
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
    );
  }
}
