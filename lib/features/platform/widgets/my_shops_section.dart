// 檔案名稱：lib/features/platform/widgets/my_shops_section.dart
// 功能說明：會員曾經預約過的店家。資料由外層用既有訂單清單整理後傳入。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/platform/widgets/explore_section_header.dart';

class ExploreStayShop {
  const ExploreStayShop({
    required this.shopId,
    required this.name,
    required this.imageUrl,
    required this.count,
    required this.latest,
  });

  final String shopId;
  final String name;
  final String imageUrl;
  final int count;
  final DateTime? latest;
}

class MyShopsSection extends StatelessWidget {
  const MyShopsSection({
    super.key,
    required this.shops,
    required this.onOpen,
    required this.onBookAgain,
    this.onViewAll,
    this.maxItems = 3,
  });

  final List<ExploreStayShop> shops;
  final ValueChanged<ExploreStayShop> onOpen;
  final ValueChanged<ExploreStayShop> onBookAgain;
  final VoidCallback? onViewAll;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<ExploreStayShop> shown = shops.take(maxItems).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExploreSectionHeader(
          title: '我的旅店',
          actionLabel: onViewAll == null ? null : '查看全部 >',
          onAction: onViewAll,
        ),
        for (final ExploreStayShop shop in shown) ...<Widget>[
          _StayRow(shop: shop, onOpen: onOpen, onBookAgain: onBookAgain),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class MyStayShopsPage extends StatelessWidget {
  const MyStayShopsPage({
    super.key,
    required this.shops,
    required this.onOpen,
    required this.onBookAgain,
  });

  final List<ExploreStayShop> shops;
  final ValueChanged<ExploreStayShop> onOpen;
  final ValueChanged<ExploreStayShop> onBookAgain;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的旅店')),
      body: shops.isEmpty
          ? const Center(child: Text('你還沒有預約過的旅店'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: shops.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final ExploreStayShop shop = shops[index];
                return _StayRow(
                  shop: shop,
                  onOpen: onOpen,
                  onBookAgain: onBookAgain,
                );
              },
            ),
    );
  }
}

class _StayRow extends StatelessWidget {
  const _StayRow({
    required this.shop,
    required this.onOpen,
    required this.onBookAgain,
  });

  final ExploreStayShop shop;
  final ValueChanged<ExploreStayShop> onOpen;
  final ValueChanged<ExploreStayShop> onBookAgain;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String when = shop.latest == null
        ? '最近一次日期尚未記錄'
        : '最近一次 ${_formatDate(shop.latest!)}';
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onOpen(shop),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: shop.imageUrl.trim().isEmpty
                      ? ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: Icon(
                            Icons.storefront_outlined,
                            color: colors.onSurfaceVariant,
                          ),
                        )
                      : Image.network(
                          shop.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: colors.surfaceContainerHighest,
                            child: Icon(
                              Icons.storefront_outlined,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '已預約 ${shop.count} 次',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                    Text(
                      when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => onBookAgain(shop),
                child: const Text('再次預約'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}/$month/$day';
}
