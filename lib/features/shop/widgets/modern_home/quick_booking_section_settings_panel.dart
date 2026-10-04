import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_quick_booking_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_layout_option_card.dart';

/// 快速預約右側設定。只改草稿，不直接寫入 Firestore。
class QuickBookingSectionSettingsPanel extends StatefulWidget {
  const QuickBookingSectionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.accommodationAvailable,
    required this.daycareAvailable,
    required this.onChanged,
  });

  final HomeQuickBookingSectionSetting setting;
  final HomeThemeModel theme;
  final bool accommodationAvailable;
  final bool daycareAvailable;
  final ValueChanged<HomeQuickBookingSectionSetting> onChanged;

  @override
  State<QuickBookingSectionSettingsPanel> createState() =>
      _QuickBookingSectionSettingsPanelState();
}

class _QuickBookingSectionSettingsPanelState
    extends State<QuickBookingSectionSettingsPanel> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _button;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.setting.title);
    _subtitle = TextEditingController(text: widget.setting.subtitle);
    _button = TextEditingController(text: widget.setting.buttonText);
  }

  @override
  void didUpdateWidget(QuickBookingSectionSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_title, widget.setting.title);
    _sync(_subtitle, widget.setting.subtitle);
    _sync(_button, widget.setting.buttonText);
  }

  void _sync(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.text = value;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _button.dispose();
    super.dispose();
  }

  void _update(HomeQuickBookingSectionSetting next) {
    widget.onChanged(next);
  }

  bool _canHideStay(HomeQuickBookingSectionSetting setting) {
    return setting.showDaycare && widget.daycareAvailable;
  }

  bool _canHideDaycare(HomeQuickBookingSectionSetting setting) {
    return setting.showAccommodation && widget.accommodationAvailable;
  }

  @override
  Widget build(BuildContext context) {
    final HomeQuickBookingSectionSetting setting = widget.setting;
    final String layout = HomeQuickBookingLayouts.migrate(setting.layout);
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('顯示快速預約'),
          subtitle: const Text('在新版首頁加入可拖曳的預約入口'),
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
            for (final String item in HomeQuickBookingLayouts.all)
              HomeSectionLayoutChoice(
                id: item,
                title: HomeQuickBookingLayouts.label(item),
                description: HomeQuickBookingLayouts.description(item),
                badge: HomeQuickBookingLayouts.badge(item),
                preview: _LayoutSketch(layout: item, theme: widget.theme),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          maxLength: 16,
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
          maxLength: 36,
          decoration: const InputDecoration(
            labelText: '副標題',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) {
            _update(setting.copyWith(subtitle: value.trim()));
          },
        ),
        TextField(
          controller: _button,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: '按鈕文字',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) {
            _update(setting.copyWith(buttonText: value.trim()));
          },
        ),
        if (layout == HomeQuickBookingLayouts.serviceSplit) ...<Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示住宿預約'),
            subtitle: widget.accommodationAvailable
                ? null
                : const Text('請先到預約設定開啟住宿預約'),
            value: setting.showAccommodation && widget.accommodationAvailable,
            onChanged: widget.accommodationAvailable
                ? (bool value) {
                    if (!value && !_canHideStay(setting)) {
                      return;
                    }
                    _update(setting.copyWith(showAccommodation: value));
                  }
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示寵物安親'),
            subtitle: widget.daycareAvailable
                ? null
                : const Text('請先到安親設定開啟安親服務'),
            value: setting.showDaycare && widget.daycareAvailable,
            onChanged: widget.daycareAvailable
                ? (bool value) {
                    if (!value && !_canHideDaycare(setting)) {
                      return;
                    }
                    _update(setting.copyWith(showDaycare: value));
                  }
                : null,
          ),
        ],
        const SizedBox(height: 8),
        const Text('卡片背景', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final String surface in HomeQuickBookingSurfaces.all)
              ChoiceChip(
                label: Text(HomeQuickBookingSurfaces.label(surface)),
                selected:
                    HomeQuickBookingSurfaces.migrate(setting.surfaceStyle) ==
                    surface,
                onSelected: (_) {
                  _update(setting.copyWith(surfaceStyle: surface));
                },
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('顯示圖示'),
          value: setting.showIcon,
          onChanged: (bool value) {
            _update(setting.copyWith(showIcon: value));
          },
        ),
        const Text('文字排列', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final String align in HomeQuickBookingTextAligns.all)
              ChoiceChip(
                label: Text(HomeQuickBookingTextAligns.label(align)),
                selected:
                    HomeQuickBookingTextAligns.migrate(setting.textAlign) ==
                    align,
                onSelected: (_) {
                  _update(setting.copyWith(textAlign: align));
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _LayoutSketch extends StatelessWidget {
  const _LayoutSketch({required this.layout, required this.theme});

  final String layout;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: switch (HomeQuickBookingLayouts.migrate(layout)) {
          HomeQuickBookingLayouts.compactCard => Align(
            alignment: Alignment.centerLeft,
            child: _bar(width: 72, height: 28),
          ),
          HomeQuickBookingLayouts.singleLine => Row(
            children: <Widget>[
              _bar(width: 18, height: 18),
              const SizedBox(width: 8),
              _bar(width: 72),
            ],
          ),
          _ => Row(
            children: <Widget>[
              Expanded(child: _bar(width: 48, height: 28)),
              const SizedBox(width: 6),
              Expanded(child: _bar(width: 48, height: 28)),
            ],
          ),
        },
      ),
    );
  }

  Widget _bar({required double width, double height = 8}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(99),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}
