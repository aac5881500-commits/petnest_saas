import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

/// Naturally sized, detachable service tile for tenant-specific member features.
class MemberLifestyleTile extends StatelessWidget {
  const MemberLifestyleTile({
    super.key,
    required this.width,
    required this.theme,
    required this.tint,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.attribution,
  });
  final Widget? attribution;
  final double width;
  final HomeThemeModel theme;
  final Color tint;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: Color.alphaBlend(tint.withValues(alpha: 0.8), theme.cardColor),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 26, color: theme.textColor),
                  const Spacer(),
                  Icon(
                    Icons.north_east_rounded,
                    size: 18,
                    color: theme.textColor.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (attribution != null) attribution!,
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.65),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
