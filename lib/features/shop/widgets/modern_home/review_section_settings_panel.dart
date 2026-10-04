import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_layout_option_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/review_section_layout_preview.dart';

/// 顧客評價右側設定。只改草稿，不直接寫入 Firestore。
class ReviewSectionSettingsPanel extends StatefulWidget {
  const ReviewSectionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.onChanged,
  });

  final HomeInformationSectionsSetting setting;
  final HomeThemeModel theme;
  final ValueChanged<HomeInformationSectionsSetting> onChanged;

  @override
  State<ReviewSectionSettingsPanel> createState() =>
      _ReviewSectionSettingsPanelState();
}

class _ReviewSectionSettingsPanelState
    extends State<ReviewSectionSettingsPanel> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;

  HomeReviewSectionSetting get _reviews => widget.setting.reviews;

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
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
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
        if (layout == HomeReviewLayouts.carousel)
          HomeDraftCountChips(
            label: '滑動則數',
            values: const <int>[2, 3, 4, 5],
            selected: HomeReviewSectionSetting.migrateCarouselCount(
              setting.carouselCount,
            ),
            onChanged: (int value) {
              _update(setting.copyWith(carouselCount: value));
            },
          ),
        HomeDraftSwitch(
          title: '顯示顧客名稱',
          value: setting.showCustomerName,
          onChanged: (bool value) {
            _update(setting.copyWith(showCustomerName: value));
          },
        ),
        HomeDraftSwitch(
          title: '顯示日期',
          value: setting.showDate,
          onChanged: (bool value) {
            _update(setting.copyWith(showDate: value));
          },
        ),
        HomeDraftSwitch(
          title: '顯示評價圖片',
          value: setting.showImages,
          onChanged: (bool value) {
            _update(setting.copyWith(showImages: value));
          },
        ),
        HomeDraftSwitch(
          title: '顯示店家已回覆',
          value: setting.showReplyBadge,
          onChanged: (bool value) {
            _update(setting.copyWith(showReplyBadge: value));
          },
        ),
        HomeDraftSwitch(
          title: '顯示全部評價入口',
          value: setting.showViewAll,
          onChanged: (bool value) {
            _update(setting.copyWith(showViewAll: value));
          },
        ),
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
    );
  }
}
