// 檔案名稱：lib/features/shop/widgets/modern_home/home_quick_action_settings_panel.dart
// 功能說明：首頁活動海報頁裡的前台快捷按鈕。右上角與懸浮按鈕同一張卡片，沿用既有互斥與儲存。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_quick_action_setting.dart';
import 'package:petnest_saas/core/models/home_shortcut_gate.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/shop/theme/home_color_palette.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_color_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_shortcut_catalog.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_color_field.dart';

class HomeSettingsFold extends StatefulWidget {
  const HomeSettingsFold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
    this.trailing,
    this.summary,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;
  final Widget? trailing;
  final String? summary;

  @override
  State<HomeSettingsFold> createState() => _HomeSettingsFoldState();
}

class _HomeSettingsFoldState extends State<HomeSettingsFold> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E8EC)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.black54,
                            ),
                          ),
                          if (widget.summary != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              widget.summary!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9A5B12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                  ),
                ],
              ),
              if (_expanded) ...<Widget>[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 12),
                widget.child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FrontendRoleActionsPanel extends StatelessWidget {
  const FrontendRoleActionsPanel({
    super.key,
    required this.floatingEnabled,
    required this.floatingType,
    required this.floatingSize,
    required this.labelController,
    required this.quickActions,
    required this.gate,
    required this.onFloatingEnabled,
    required this.onFloatingType,
    required this.onFloatingSize,
    required this.onQuickActions,
    required this.onLabelChanged,
  });

  final bool floatingEnabled;
  final String floatingType;
  final String floatingSize;
  final TextEditingController labelController;
  final HomeQuickActionSetting quickActions;
  final HomeShortcutGate gate;
  final ValueChanged<bool> onFloatingEnabled;
  final ValueChanged<String> onFloatingType;
  final ValueChanged<String> onFloatingSize;
  final ValueChanged<HomeQuickActionSetting> onQuickActions;
  final VoidCallback onLabelChanged;

  @override
  Widget build(BuildContext context) {
    final String floatingSummary = floatingEnabled
        ? (_optionLabel(floatingType) ?? '已啟用')
        : '已關閉';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E8EC)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                '前台快捷按鈕',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              const Text(
                '統一設定首頁右上角與懸浮按鈕，左側即時預覽。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '右上角快捷鍵',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '目前：${_shortcutSummary()}。通知鈴鐺固定顯示。',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              HomeQuickActionSettingsPanel(
                setting: quickActions,
                gate: gate,
                onChanged: onQuickActions,
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '懸浮聯絡按鈕',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text(
                    '啟用',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  Switch(value: floatingEnabled, onChanged: onFloatingEnabled),
                ],
              ),
              Text(
                '目前：$floatingSummary。關閉後仍保留功能、大小與文字。',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              IgnorePointer(
                ignoring: !floatingEnabled,
                child: Opacity(
                  opacity: floatingEnabled ? 1 : 0.45,
                  child: _floatingBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortcutSummary() {
    return '${_slotName(quickActions.slotOne)}、${_slotName(quickActions.slotTwo)}';
  }

  String _slotName(String id) {
    if (id.isEmpty) {
      return '不顯示';
    }
    return _optionLabel(id) ?? id;
  }

  String? _optionLabel(String id) {
    return HomeShortcutCatalog.find(id)?.label;
  }

  Widget _floatingBody() {
    final String size =
        const <String>{'small', 'medium', 'large'}.contains(floatingSize)
        ? floatingSize
        : 'medium';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ShortcutMenu(
          label: '按鈕功能',
          value: floatingType,
          options: HomeShortcutCatalog.options
              .where(
                (HomeShortcutOption option) =>
                    option.id == HomeQuickActionIds.chat ||
                    option.id == HomeQuickActionIds.phone ||
                    option.id == HomeQuickActionIds.line ||
                    option.id == HomeQuickActionIds.facebook ||
                    option.id == HomeQuickActionIds.instagram,
              )
              .toList(growable: false),
          reasonFor: (String id) {
            final bool usedByOtherSlot =
                (quickActions.slotOne == id || quickActions.slotTwo == id) &&
                id != floatingType;
            if (usedByOtherSlot) {
              return '已用於右上角快捷鍵';
            }
            if (id == HomeQuickActionIds.chat) {
              return null;
            }
            final String? reason = gate.blockReason(id);
            return reason == '已由懸浮按鈕使用' ? null : reason;
          },
          onChanged: onFloatingType,
        ),
        const SizedBox(height: 12),
        const Text('按鈕大小', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            for (final (String id, String label) in const <(String, String)>[
              ('small', '小'),
              ('medium', '中'),
              ('large', '大'),
            ])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: id == 'large' ? 0 : 8),
                  child: _SizeChoice(
                    label: label,
                    selected: size == id,
                    onTap: floatingEnabled ? () => onFloatingSize(id) : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: labelController,
          enabled: floatingEnabled,
          onChanged: (_) => onLabelChanged(),
          decoration: InputDecoration(
            labelText: '按鈕文字',
            hintText: ShopChatService.defaultLabelForType(floatingType),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '可直接在左側前台預覽拖曳位置。',
          style: TextStyle(fontSize: 12, height: 1.35, color: Colors.black54),
        ),
      ],
    );
  }
}

class HomeQuickActionSettingsPanel extends StatelessWidget {
  const HomeQuickActionSettingsPanel({
    super.key,
    required this.setting,
    required this.gate,
    required this.onChanged,
  });

  final HomeQuickActionSetting setting;
  final HomeShortcutGate gate;
  final ValueChanged<HomeQuickActionSetting> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool sideBySide = constraints.maxWidth >= 560;
        final Widget first = _ShortcutMenu(
          label: '快捷鍵一',
          value: setting.slotOne,
          includeNone: true,
          options: HomeShortcutCatalog.options,
          reasonFor: (String id) =>
              gate.selectionReason(id, otherSlot: setting.slotTwo),
          onChanged: (String id) => onChanged(setting.assignSlot(0, id)),
        );
        final Widget second = _ShortcutMenu(
          label: '快捷鍵二',
          value: setting.slotTwo,
          includeNone: true,
          options: HomeShortcutCatalog.options,
          reasonFor: (String id) =>
              gate.selectionReason(id, otherSlot: setting.slotOne),
          onChanged: (String id) => onChanged(setting.assignSlot(1, id)),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: first),
                  const SizedBox(width: 12),
                  Expanded(child: second),
                ],
              )
            else ...<Widget>[first, const SizedBox(height: 12), second],
            const SizedBox(height: 12),
            const Row(
              children: <Widget>[
                Icon(Icons.notifications_none_rounded, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '通知鈴鐺（固定顯示）',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _QuickActionColorSection(setting: setting, onChanged: onChanged),
          ],
        );
      },
    );
  }
}

class _ShortcutMenu extends StatelessWidget {
  const _ShortcutMenu({
    required this.label,
    required this.value,
    required this.options,
    required this.reasonFor,
    required this.onChanged,
    this.includeNone = false,
  });

  final String label;
  final String value;
  final List<HomeShortcutOption> options;
  final String? Function(String id) reasonFor;
  final ValueChanged<String> onChanged;
  final bool includeNone;

  @override
  Widget build(BuildContext context) {
    final bool listed =
        value.isEmpty ||
        options.any((HomeShortcutOption option) => option.id == value);
    final String? currentReason = value.isEmpty ? null : reasonFor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          key: ValueKey<String>('$label-$value'),
          initialValue: value,
          isExpanded: true,
          menuMaxHeight: 280,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          selectedItemBuilder: (BuildContext context) {
            return <Widget>[
              if (includeNone)
                const Text('不顯示', overflow: TextOverflow.ellipsis),
              for (final HomeShortcutOption option in options)
                _closedLabel(option.icon, option.label),
              if (!listed && value.isNotEmpty)
                Text(value, overflow: TextOverflow.ellipsis),
            ];
          },
          items: <DropdownMenuItem<String>>[
            if (includeNone)
              const DropdownMenuItem<String>(
                value: HomeQuickActionIds.none,
                child: Text('不顯示'),
              ),
            for (final HomeShortcutOption option in options)
              DropdownMenuItem<String>(
                value: option.id,
                enabled: reasonFor(option.id) == null,
                child: _menuLabel(
                  option.icon,
                  option.label,
                  reasonFor(option.id),
                ),
              ),
            if (!listed && value.isNotEmpty)
              DropdownMenuItem<String>(
                value: value,
                enabled: false,
                child: Text('$value（此功能目前無法使用）'),
              ),
          ],
          onChanged: (String? next) {
            if (next == null) {
              return;
            }
            if (next.isNotEmpty && reasonFor(next) != null) {
              return;
            }
            onChanged(next);
          },
        ),
        if (currentReason != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            currentReason,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Color(0xFF9A5B12),
            ),
          ),
        ],
      ],
    );
  }
}

class _SizeChoice extends StatelessWidget {
  const _SizeChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.12)
          : const Color(0xFFF7F4EF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? accent : const Color(0xFFE6E8EC)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: onTap == null
                  ? Colors.black38
                  : selected
                  ? accent
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _closedLabel(IconData icon, String label) {
  return Row(
    children: <Widget>[
      Icon(icon, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

Widget _menuLabel(IconData icon, String label, String? reason) {
  final String text = reason == null ? label : '$label（$reason）';
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 18),
      const SizedBox(width: 8),
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    ],
  );
}

class _QuickActionColorSection extends StatelessWidget {
  const _QuickActionColorSection({
    required this.setting,
    required this.onChanged,
  });

  final HomeQuickActionSetting setting;
  final ValueChanged<HomeQuickActionSetting> onChanged;

  bool get _paintsBackground =>
      setting.containerStyle != HomeQuickActionSetting.containerPlain;

  @override
  Widget build(BuildContext context) {
    final bool customIcon =
        setting.iconColorMode == HomeQuickActionSetting.iconCustom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('按鈕區配色', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          '通知鈴鐺與兩個快捷鍵共用。不會改變整頁背景、其他卡片或懸浮按鈕。',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _backgroundNote,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _modeChip('跟隨主題卡片色', HomeQuickActionSetting.backgroundTheme),
            _modeChip('半透明主題卡片色', HomeQuickActionSetting.backgroundTranslucent),
            _modeChip('自訂背景色', HomeQuickActionSetting.backgroundCustom),
          ],
        ),
        if (_paintsBackground &&
            setting.backgroundMode == HomeQuickActionSetting.backgroundCustom)
          _QuickColorField(
            label: '按鈕區背景色',
            value: Color(setting.backgroundColorValue),
            onPick: (Color color) {
              onChanged(
                setting.copyWith(backgroundColorValue: color.toARGB32()),
              );
            },
          ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                '自訂按鈕圖示顏色',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Switch(
              value: customIcon,
              onChanged: (bool enabled) {
                onChanged(
                  setting.copyWith(
                    iconColorMode: enabled
                        ? HomeQuickActionSetting.iconCustom
                        : HomeQuickActionSetting.iconTheme,
                  ),
                );
              },
            ),
          ],
        ),
        Text(
          customIcon ? '圖示使用下方顏色。' : '關閉時沿用主題文字色。',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        if (customIcon)
          _QuickColorField(
            label: '圖示顏色',
            value: Color(setting.iconColorValue),
            onPick: (Color color) {
              onChanged(setting.copyWith(iconColorValue: color.toARGB32()));
            },
          ),
      ],
    );
  }

  String get _backgroundNote {
    switch (setting.containerStyle) {
      case HomeQuickActionSetting.containerPlain:
        return '目前樣式不繪製按鈕背景，背景色不會顯示。已儲存的背景設定會保留，圖示顏色仍可調整。';
      case HomeQuickActionSetting.containerCircles:
        return '背景色會套在每一顆圓形按鈕上。';
      default:
        return '背景色套在通知鈴鐺與兩個快捷鍵共用的按鈕區。';
    }
  }

  Widget _modeChip(String label, String mode) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      visualDensity: VisualDensity.compact,
      selected: setting.backgroundMode == mode,
      onSelected: _paintsBackground
          ? (_) => onChanged(setting.copyWith(backgroundMode: mode))
          : null,
    );
  }
}

class _QuickColorField extends StatefulWidget {
  const _QuickColorField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final Color value;
  final ValueChanged<Color> onPick;

  @override
  State<_QuickColorField> createState() => _QuickColorFieldState();
}

class _QuickColorFieldState extends State<_QuickColorField> {
  static const List<HomeColorSwatch> _swatches = <HomeColorSwatch>[
    HomeColorSwatch('白色', 0xFFFFFFFF),
    HomeColorSwatch('淺米', 0xFFFFFBF7),
    HomeColorSwatch('深棕', 0xFF3A2A20),
    HomeColorSwatch('黑色', 0xFF111111),
    HomeColorSwatch('橘色', 0xFFFF8A00),
    HomeColorSwatch('藍色', 0xFF3B82C4),
    HomeColorSwatch('綠色', 0xFF4F7D61),
  ];

  @override
  Widget build(BuildContext context) {
    final int current = widget.value.toARGB32();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: widget.value,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 0,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (final HomeColorSwatch swatch in _swatches)
              HomeColorSwatchButton(
                swatch: swatch,
                selected: (current & 0xFFFFFFFF) == (swatch.argb & 0xFFFFFFFF),
                onTap: () => widget.onPick(Color(swatch.argb)),
              ),
            OutlinedButton(
              onPressed: () async {
                final int? next = await showHomeColorPicker(
                  context,
                  initial: widget.value,
                );
                if (next == null || !mounted) {
                  return;
                }
                widget.onPick(Color(next));
              },
              child: const Text('自訂顏色'),
            ),
          ],
        ),
      ],
    );
  }
}
