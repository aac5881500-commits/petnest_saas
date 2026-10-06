// 檔案名稱：lib/features/platform/widgets/explore_section_header.dart
// 功能說明：探索頁區塊標題，右側可放「查看全部」。

import 'package:flutter/material.dart';

class ExploreSectionHeader extends StatelessWidget {
  const ExploreSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// 依螢幕寬度決定探索店家欄數。左側會員欄以浮層展開，不改變這個欄數。
int exploreShopColumns(double screenWidth) {
  if (screenWidth >= 1600) {
    return 5;
  }
  if (screenWidth >= 1200) {
    return 4;
  }
  if (screenWidth >= 900) {
    return 3;
  }
  return 2;
}

/// 卡片格子的寬高比。依封面比例與文字行數估算，避免固定高度溢出。
double compactShopCardAspectRatio({
  required double gridWidth,
  required int columns,
  required double textScale,
  double imageAspect = 1.65,
  bool roomy = false,
  double horizontalPadding = 16,
  double gap = 10,
}) {
  final double safeScale = textScale < 1 ? 1 : textScale;
  final double cardWidth =
      (gridWidth - horizontalPadding * 2 - gap * (columns - 1)) / columns;
  final double imageHeight = cardWidth / imageAspect;
  final double name = roomy ? 22 : 20;
  final double meta = roomy ? 20 : 18;
  final double services = roomy ? 36 : 32;
  final double hours = roomy ? 18 : 16;
  final double textHeight = 20 + (name + meta + services + hours) * safeScale;
  final double height = imageHeight + textHeight;
  if (cardWidth <= 0 || height <= 0) {
    return 0.72;
  }
  return cardWidth / height;
}
