// 檔案名稱：lib/features/shop/widgets/modern_home/appearance_category_bar.dart
// 功能說明：外觀設定內部的分類切換。不進入最上方的主要功能導航。

import 'package:flutter/material.dart';

class AppearanceCategoryItem {
  const AppearanceCategoryItem({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.icon,
  });

  final int id;
  final String label;
  final String shortLabel;
  final String description;
  final IconData icon;
}

abstract final class AppearanceCategories {
  static const int presets = 0;
  static const int brand = 1;
  static const int cards = 2;
  static const int banners = 3;
  static const int background = 4;
  static const int other = 5;
  static const int length = 6;

  static const List<AppearanceCategoryItem> all = <AppearanceCategoryItem>[
    AppearanceCategoryItem(
      id: presets,
      label: '快速套用前台風格',
      shortLabel: '快速風格',
      description: '選擇喜歡的首頁風格，快速套用配色與版面配置。',
      icon: Icons.auto_awesome_outlined,
    ),
    AppearanceCategoryItem(
      id: brand,
      label: '品牌與標題',
      shortLabel: '品牌標題',
      description: '設定店家名稱、Logo 與文字外觀。',
      icon: Icons.storefront_outlined,
    ),
    AppearanceCategoryItem(
      id: cards,
      label: '首頁小卡',
      shortLabel: '首頁小卡',
      description: '調整首頁共用小卡的排列、尺寸與外觀。',
      icon: Icons.grid_view_rounded,
    ),
    AppearanceCategoryItem(
      id: banners,
      label: '活動海報',
      shortLabel: '活動海報',
      description: '調整首頁活動海報的展示方式與尺寸。',
      icon: Icons.view_carousel_outlined,
    ),
    AppearanceCategoryItem(
      id: background,
      label: '背景與色彩',
      shortLabel: '背景色彩',
      description: '調整首頁配色、顧客端背景、卡片與文字顏色。',
      icon: Icons.palette_outlined,
    ),
    AppearanceCategoryItem(
      id: other,
      label: '其他外觀',
      shortLabel: '其他外觀',
      description: '快捷按鈕、側邊選單與其他首頁外觀。',
      icon: Icons.tune,
    ),
  ];

  static AppearanceCategoryItem of(int id) {
    for (final AppearanceCategoryItem item in all) {
      if (item.id == id) {
        return item;
      }
    }
    return all.first;
  }

  static int forSection(String sectionId) {
    return switch (sectionId) {
      'header' => brand,
      'sharedEntries' => cards,
      'banners' => banners,
      _ => other,
    };
  }
}

class AppearanceCategoryRail extends StatelessWidget {
  const AppearanceCategoryRail({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final AppearanceCategoryItem item
            in AppearanceCategories.all) ...<Widget>[
          _AppearanceCategoryTile(
            item: item,
            selected: item.id == selected,
            vertical: true,
            onTap: () => onSelected(item.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class AppearanceCategoryPicker extends StatelessWidget {
  const AppearanceCategoryPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 520 ? 3 : 2;
        final double width =
            (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final AppearanceCategoryItem item in AppearanceCategories.all)
              SizedBox(
                width: width,
                child: _AppearanceCategoryTile(
                  item: item,
                  selected: item.id == selected,
                  vertical: false,
                  onTap: () => onSelected(item.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AppearanceCategoryTile extends StatelessWidget {
  const _AppearanceCategoryTile({
    required this.item,
    required this.selected,
    required this.vertical,
    required this.onTap,
  });

  final AppearanceCategoryItem item;
  final bool selected;
  final bool vertical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    final String label = vertical ? item.shortLabel : item.label;
    return Material(
      color: selected ? const Color(0xFFFFF6EE) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey<String>('appearance-category-${item.id}'),
        borderRadius: BorderRadius.circular(12),
        hoverColor: accent.withValues(alpha: 0.06),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: vertical ? 72 : 64),
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: vertical ? 4 : 8,
            vertical: 8,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : const Color(0xFFE6E8EC),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                item.icon,
                size: 20,
                color: selected ? accent : Colors.black87,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
