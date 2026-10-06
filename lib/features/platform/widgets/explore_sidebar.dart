// 檔案名稱：lib/features/platform/widgets/explore_sidebar.dart
// 功能說明：探索頁半隱藏會員欄。收合時只留把手或窄軌道，展開時以浮層蓋上內容。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/platform/widgets/my_shops_section.dart';
import 'package:petnest_saas/features/platform/widgets/recent_shop_section.dart';

class ExplorePawHandle extends StatelessWidget {
  const ExplorePawHandle({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 2,
      shadowColor: colors.shadow.withValues(alpha: 0.2),
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(Icons.pets, size: 20, color: colors.primary),
        ),
      ),
    );
  }
}

class ExploreMemberRail extends StatelessWidget {
  const ExploreMemberRail({
    super.key,
    required this.onToggle,
    required this.onMyStays,
    required this.onBookings,
    required this.onFavorites,
    required this.onRecent,
  });

  final VoidCallback onToggle;
  final VoidCallback onMyStays;
  final VoidCallback onBookings;
  final VoidCallback onFavorites;
  final VoidCallback onRecent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            IconButton(
              tooltip: '我的 PetNest',
              onPressed: onToggle,
              icon: Icon(Icons.pets, color: colors.primary),
            ),
            _RailButton(
              tooltip: '我的旅店',
              icon: Icons.pets_outlined,
              onTap: onMyStays,
            ),
            _RailButton(
              tooltip: '我的預約',
              icon: Icons.event_outlined,
              onTap: onBookings,
            ),
            _RailButton(
              tooltip: '我的收藏',
              icon: Icons.favorite_border,
              onTap: onFavorites,
            ),
            _RailButton(tooltip: '最近瀏覽', icon: Icons.history, onTap: onRecent),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
    );
  }
}

class ExploreMemberPanel extends StatelessWidget {
  const ExploreMemberPanel({
    super.key,
    required this.onClose,
    required this.onMyStays,
    required this.onBookings,
    required this.onFavorites,
    required this.onRecent,
    required this.stays,
    required this.loggedIn,
    required this.onOpenStay,
    this.stayError = false,
    this.showRecentEmpty = false,
  });

  final VoidCallback onClose;
  final VoidCallback onMyStays;
  final VoidCallback onBookings;
  final VoidCallback onFavorites;
  final VoidCallback onRecent;
  final List<ExploreStayShop> stays;
  final bool loggedIn;
  final ValueChanged<ExploreStayShop> onOpenStay;
  final bool stayError;
  final bool showRecentEmpty;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final List<ExploreStayShop> shown = stays.take(3).toList();
    return Material(
      color: colors.surface,
      elevation: 3,
      shadowColor: colors.shadow.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: <Widget>[
                Icon(Icons.pets, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '我的 PetNest',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '收起',
                  onPressed: onClose,
                  icon: const Icon(Icons.pets, size: 18),
                ),
              ],
            ),
          ),
          _PanelTile(
            icon: Icons.pets_outlined,
            label: '我的旅店',
            onTap: onMyStays,
          ),
          _PanelTile(
            icon: Icons.event_outlined,
            label: '我的預約',
            onTap: onBookings,
          ),
          _PanelTile(
            icon: Icons.favorite_border,
            label: '我的收藏',
            onTap: onFavorites,
          ),
          _PanelTile(icon: Icons.history, label: '最近瀏覽', onTap: onRecent),
          if (showRecentEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: RecentShopSection(compact: true),
            ),
          Divider(
            height: 20,
            color: colors.outlineVariant.withValues(alpha: 0.6),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: <Widget>[
                Text(
                  '最近使用',
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (stayError)
                  Text(
                    '暫時讀不到預約紀錄',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  )
                else if (!loggedIn)
                  Text(
                    '登入後可以看預約過的旅店',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  )
                else if (shown.isEmpty)
                  Text(
                    '你還沒有預約過的旅店',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  )
                else
                  for (final ExploreStayShop shop in shown)
                    _RecentStayTile(shop: shop, onTap: () => onOpenStay(shop)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.chevron_left),
              label: const Text('收起'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTile extends StatelessWidget {
  const _PanelTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, size: 20),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }
}

class _RecentStayTile extends StatelessWidget {
  const _RecentStayTile({required this.shop, required this.onTap});

  final ExploreStayShop shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              shop.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '已預約 ${shop.count} 次',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
