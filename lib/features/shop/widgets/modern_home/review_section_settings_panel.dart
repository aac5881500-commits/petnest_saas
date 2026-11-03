import 'home_section_settings_group.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_editor.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_layout_option_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/review_section_layout_preview.dart';

/// 顧客評價右側設定。只改草稿，不直接寫入 Firestore。
class ReviewSectionSettingsPanel extends StatefulWidget {
  const ReviewSectionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.onChanged,
    this.bannerAvailable = false,
    this.displayStyles,
    this.onDisplayStyles,
  });

  final HomeInformationSectionsSetting setting;
  final HomeThemeModel theme;
  final ValueChanged<HomeInformationSectionsSetting> onChanged;
  final bool bannerAvailable;
  final HomeDisplayStyleSetting? displayStyles;
  final ValueChanged<HomeDisplayStyleSetting>? onDisplayStyles;

  @override
  State<ReviewSectionSettingsPanel> createState() =>
      _ReviewSectionSettingsPanelState();
}

class _ReviewSectionSettingsPanelState
    extends State<ReviewSectionSettingsPanel> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;

  HomeReviewSectionSetting get _reviews => widget.setting.reviews;

  Widget _styleEditor() {
    final HomeDisplayStyleSetting display =
        widget.displayStyles ?? HomeDisplayStyleSetting.unset;
    final String mode = display.effectiveMode(
      sectionId: HomeDisplaySections.reviews,
      legacy: HomeDisplayStyle.classic,
      baseline: HomeDisplayStyle.classic,
    );
    final HomeDisplayStyle effective = display.resolve(
      sectionId: HomeDisplaySections.reviews,
      legacy: HomeDisplayStyle.classic,
      baseline: HomeDisplayStyle.classic,
    );
    return HomeDisplaySectionOverride(
      basicAppearanceOnly: true,
      label: '顧客評價',
      shared: display.style,
      mode: mode,
      effective: effective,
      onInherit: () {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.reviews,
            mode: HomeDisplayStyleModes.inherit,
            clearOverride: true,
          ),
        );
      },
      onCustom: () {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.reviews,
            mode: HomeDisplayStyleModes.custom,
          ),
        );
      },
      onEdit: (HomeDisplayStyle edited) {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.reviews,
            mode: HomeDisplayStyleModes.custom,
            override: edited.diff(display.style),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _reviews.title);
    _subtitle = TextEditingController(text: _reviews.subtitle);
  }

  @override
  void didUpdateWidget(ReviewSectionSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_title.text != _reviews.title) {
      _title.text = _reviews.title;
    }
    if (_subtitle.text != _reviews.subtitle) {
      _subtitle.text = _reviews.subtitle;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  void _update(HomeReviewSectionSetting next) {
    widget.onChanged(widget.setting.copyWith(reviews: next));
  }

  @override
  Widget build(BuildContext context) {
    final HomeReviewSectionSetting setting = _reviews;
    final String layout = HomeReviewLayouts.migrate(setting.layout);
    return ListView(
      key: const PageStorageKey<String>('review-section-settings'),
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      children: <Widget>[
        if (widget.onDisplayStyles != null) ...<Widget>[
          _styleEditor(),
          const SizedBox(height: 12),
        ],
        const Text('評價保持公開，可選擇獨立區塊或迷你入口。全部評價入口固定保留。'),
        const SizedBox(height: 8),
        const Text('展示版型', style: TextStyle(fontWeight: FontWeight.bold)),
        HomeSectionLayoutPicker(
          theme: widget.theme,
          selectedId: layout,
          onSelected: (String value) {
            _update(
              setting.copyWith(
                layout: value,
                showOnHome: true,
                showViewAll: true,
                showImages:
                    value == HomeReviewLayouts.carousel ||
                    value == HomeReviewLayouts.featured,
              ),
            );
          },
          choices: <HomeSectionLayoutChoice>[
            for (final String item in HomeReviewLayouts.all)
              HomeSectionLayoutChoice(
                id: item,
                title: HomeReviewLayouts.label(item),
                description: HomeReviewLayouts.description(item),
                badge: HomeReviewLayouts.badge(item),
                preview: ReviewSectionLayoutPreview(
                  layout: item,
                  theme: widget.theme,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('目前版型設定', style: TextStyle(fontWeight: FontWeight.bold)),
        if (layout == HomeReviewLayouts.mini) ...[
          DropdownButtonFormField<String>(
            initialValue: HomeReviewSectionSetting.placement(
              setting.miniPlacement,
            ),
            decoration: const InputDecoration(labelText: '迷你評分位置'),
            items: const [
              DropdownMenuItem(value: 'bannerTopRight', child: Text('海報右上角')),
              DropdownMenuItem(
                value: 'bannerBottomRight',
                child: Text('海報右下角'),
              ),
              DropdownMenuItem(value: 'inline', child: Text('獨立單行入口')),
            ],
            onChanged: (value) {
              if (value != null) {
                _update(setting.copyWith(miniPlacement: value));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              widget.bannerAvailable
                  ? '已啟用的海報可顯示角落入口；點擊即可看全部評價。'
                  : '目前沒有啟用的海報，角落模式會自動改為獨立單行入口。',
            ),
          ),
        ],
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
        if (layout != HomeReviewLayouts.mini) ...[
          if (layout != HomeReviewLayouts.scoreCompact &&
              layout != HomeReviewLayouts.featured)
            HomeDraftCountChips(
              label: '顯示評價則數',
              values: const [2, 3, 4, 5],
              selected: HomeReviewSectionSetting.migrateCarouselCount(
                setting.carouselCount,
              ),
              onChanged: (value) =>
                  _update(setting.copyWith(carouselCount: value)),
            ),
          HomeDraftCountChips(
            label: '每則文字行數',
            values: const [2, 3, 6, 12],
            selected: setting.contentLines,
            onChanged: (value) =>
                _update(setting.copyWith(contentLines: value)),
          ),
          HomeDraftCountChips(
            label: '評價字體大小',
            values: const [12, 14, 16, 18],
            selected: setting.textSize,
            onChanged: (value) => _update(setting.copyWith(textSize: value)),
          ),
          HomeDraftSwitch(
            title: '顯示顧客名稱',
            value: setting.showCustomerName,
            onChanged: (value) =>
                _update(setting.copyWith(showCustomerName: value)),
          ),
          HomeDraftSwitch(
            title: '顯示日期',
            value: setting.showDate,
            onChanged: (value) => _update(setting.copyWith(showDate: value)),
          ),
          if (layout == HomeReviewLayouts.carousel ||
              layout == HomeReviewLayouts.featured)
            HomeDraftSwitch(
              title: '顯示顧客上傳照片',
              value: setting.showImages,
              onChanged: (value) =>
                  _update(setting.copyWith(showImages: value)),
            ),
          HomeDraftSwitch(
            title: layout == HomeReviewLayouts.scoreAndLatest
                ? '顯示店家回覆內容'
                : '顯示店家已回覆',
            value: setting.showReplyBadge,
            onChanged: (value) =>
                _update(setting.copyWith(showReplyBadge: value)),
          ),
        ],
        if (widget.onDisplayStyles != null)
          HomeSectionSettingsGroup(
            title: '進階外觀',
            storageId: 'review-section-advanced-appearance',
            children: [_styleEditor()],
          ),
      ],
    );
  }
}
