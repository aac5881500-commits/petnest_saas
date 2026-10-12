// 檔案名稱：lib/features/shop/widgets/modern_home/home_quick_action_settings_panel.dart
// 功能說明：前台外觀設定裡的首頁快捷功能列。只改外觀草稿，不另寫通知或購物車資料。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_quick_action_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_color_field.dart';

class HomeQuickActionSettingsPanel extends StatelessWidget {
  const HomeQuickActionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.storeEnabled,
    required this.chatEnabled,
    required this.onChanged,
  });

  final HomeQuickActionSetting setting;
  final HomeThemeModel theme;
  final bool storeEnabled;
  final bool chatEnabled;
  final ValueChanged<HomeQuickActionSetting> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<HomeQuickActionItem> items = setting.knownItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          '通知鈴鐺固定顯示。購物車與訊息要店家已啟用對應功能，才會出現在首頁。',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        _label('顯示位置'),
        _choices(
          value: setting.placement,
          options: const <_Choice>[
            _Choice(HomeQuickActionSetting.placementEnd, '右上角'),
            _Choice(HomeQuickActionSetting.placementStart, '左上角'),
          ],
          onChanged: (String value) =>
              onChanged(setting.copyWith(placement: value)),
        ),
        _label('容器樣式'),
        _choices(
          value: setting.containerStyle,
          options: const <_Choice>[
            _Choice(HomeQuickActionSetting.containerCapsule, '膠囊'),
            _Choice(HomeQuickActionSetting.containerCircles, '獨立圓形'),
            _Choice(HomeQuickActionSetting.containerPlain, '透明'),
          ],
          onChanged: (String value) =>
              onChanged(setting.copyWith(containerStyle: value)),
        ),
        _label('背景'),
        _choices(
          value: setting.backgroundMode,
          options: const <_Choice>[
            _Choice(HomeQuickActionSetting.backgroundTheme, '跟隨主題'),
            _Choice(HomeQuickActionSetting.backgroundTranslucent, '半透明'),
            _Choice(HomeQuickActionSetting.backgroundCustom, '自訂顏色'),
          ],
          onChanged: (String value) =>
              onChanged(setting.copyWith(backgroundMode: value)),
        ),
        if (setting.backgroundMode == HomeQuickActionSetting.backgroundCustom)
          StoreBannerColorField(
            label: '背景顏色',
            argb: setting.backgroundColorValue,
            brandColor: theme.primaryColor,
            onChanged: (int value) =>
                onChanged(setting.copyWith(backgroundColorValue: value)),
          ),
        _label('圖示大小'),
        _choices(
          value: setting.iconSize,
          options: const <_Choice>[
            _Choice(HomeQuickActionSetting.sizeSmall, '小'),
            _Choice(HomeQuickActionSetting.sizeMedium, '中'),
            _Choice(HomeQuickActionSetting.sizeLarge, '大'),
          ],
          onChanged: (String value) =>
              onChanged(setting.copyWith(iconSize: value)),
        ),
        _label('圖示顏色'),
        _choices(
          value: setting.iconColorMode,
          options: const <_Choice>[
            _Choice(HomeQuickActionSetting.iconTheme, '跟隨主題'),
            _Choice(HomeQuickActionSetting.iconCustom, '自訂顏色'),
          ],
          onChanged: (String value) =>
              onChanged(setting.copyWith(iconColorMode: value)),
        ),
        if (setting.iconColorMode == HomeQuickActionSetting.iconCustom)
          StoreBannerColorField(
            label: '圖示顏色',
            argb: setting.iconColorValue,
            brandColor: theme.primaryColor,
            onChanged: (int value) =>
                onChanged(setting.copyWith(iconColorValue: value)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('未讀角標'),
          subtitle: const Text('只影響是否顯示數字，不會更改未讀通知或訊息。'),
          value: setting.showBadges,
          onChanged: (bool value) =>
              onChanged(setting.copyWith(showBadges: value)),
        ),
        const SizedBox(height: 4),
        _label('功能與順序'),
        for (var index = 0; index < items.length; index++)
          _itemRow(items[index], index, items.length),
      ],
    );
  }

  Widget _itemRow(HomeQuickActionItem item, int index, int length) {
    final _ActionMeta meta = _meta(item.id);
    final bool available = _available(item.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: '上移',
            onPressed: index == 0
                ? null
                : () => onChanged(setting.moveKnown(index, -1)),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
          IconButton(
            tooltip: '下移',
            onPressed: index == length - 1
                ? null
                : () => onChanged(setting.moveKnown(index, 1)),
            icon: const Icon(Icons.arrow_downward_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  meta.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  available ? meta.hint : meta.unavailable,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: item.id == HomeQuickActionIds.notifications || item.enabled,
            onChanged: item.id == HomeQuickActionIds.notifications || !available
                ? null
                : (bool value) => onChanged(setting.toggle(item.id, value)),
          ),
        ],
      ),
    );
  }

  bool _available(String id) {
    switch (id) {
      case HomeQuickActionIds.cart:
        return storeEnabled;
      case HomeQuickActionIds.chat:
        return chatEnabled;
      default:
        return true;
    }
  }

  _ActionMeta _meta(String id) {
    switch (id) {
      case HomeQuickActionIds.cart:
        return const _ActionMeta('購物車', '開啟後顯示在首頁。', '請先啟用商城，才可以開啟這個按鈕。');
      case HomeQuickActionIds.chat:
        return const _ActionMeta(
          '聊天訊息',
          '開啟後顯示在首頁。',
          '請先把快速聯絡設為店內聊天，才可以開啟這個按鈕。',
        );
      default:
        return const _ActionMeta('通知鈴鐺', '固定顯示，無法關閉。', '固定顯示，無法關閉。');
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _choices({
    required String value,
    required List<_Choice> options,
    required ValueChanged<String> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final _Choice option in options)
          ChoiceChip(
            label: Text(option.label),
            selected: value == option.value,
            onSelected: (bool selected) {
              if (selected && value != option.value) {
                onChanged(option.value);
              }
            },
          ),
      ],
    );
  }
}

class _Choice {
  const _Choice(this.value, this.label);

  final String value;
  final String label;
}

class _ActionMeta {
  const _ActionMeta(this.label, this.hint, this.unavailable);

  final String label;
  final String hint;
  final String unavailable;
}
