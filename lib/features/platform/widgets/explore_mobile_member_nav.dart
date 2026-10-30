import 'package:flutter/material.dart';

/// Persistent shortcuts reuse the existing member/login actions; no fake tab state.
class ExploreMobileMemberNav extends StatelessWidget {
  const ExploreMobileMemberNav({
    super.key,
    required this.onMyStays,
    required this.onBookings,
    required this.onFavorites,
    required this.onRecent,
  });
  final VoidCallback onMyStays, onBookings, onFavorites, onRecent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actions = <({String label, IconData icon, VoidCallback onTap})>[
      (label: '我的旅店', icon: Icons.pets_outlined, onTap: onMyStays),
      (label: '預約', icon: Icons.event_outlined, onTap: onBookings),
      (label: '收藏', icon: Icons.favorite_border, onTap: onFavorites),
      (label: '最近瀏覽', icon: Icons.history, onTap: onRecent),
    ];
    return Material(
      color: colors.surface,
      elevation: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.outlineVariant.withValues(alpha: .6)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final action in actions)
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: action.label,
                      child: InkWell(
                        key: ValueKey<String>('explore-nav-${action.label}'),
                        onTap: action.onTap,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                action.icon,
                                size: 24,
                                color: colors.primary,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                action.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
