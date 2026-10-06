// 檔案名稱：lib/features/platform/widgets/recent_shop_section.dart
// 功能說明：探索頁的最近瀏覽。目前沒有既有瀏覽紀錄，只顯示精簡空狀態。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/platform/widgets/explore_section_header.dart';

class RecentShopSection extends StatelessWidget {
  const RecentShopSection({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle? style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    if (compact) {
      return Text('你還沒有瀏覽過店家', style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ExploreSectionHeader(title: '最近瀏覽'),
        Text('你還沒有瀏覽過店家', style: style),
      ],
    );
  }
}
