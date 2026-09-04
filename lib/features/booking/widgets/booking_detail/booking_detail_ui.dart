// lib/features/booking/widgets/booking_detail/booking_detail_ui.dart
// 客戶端訂單詳細頁共用暖色系樣式，對齊 PetNest 現代首頁。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';

class BookingDetailUi {
  BookingDetailUi._();

  static ShopFrontendTheme of(BuildContext context) =>
      ShopFrontendTheme.of(context);

  static const double radius = 16;
  static const double pagePadding = 16;
  static const double cardGap = 12;
  static const double cardPadding = 16;
  static const double maxContentWidth = 720;

  static const double bodySize = 14.5;
  static const double captionSize = 12.5;
  static const double sectionTitleSize = 16.5;
  static const double statusSize = 23;
  static const double moneySize = 26;

  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? color,
    Color? borderColor,
  }) {
    final ShopFrontendTheme theme = of(context);
    return BoxDecoration(
      color: color ?? theme.cardColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? theme.borderColor),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x0A3A2A20),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    );
  }

  static Widget constrain(Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}

class BookingDetailCard extends StatelessWidget {
  const BookingDetailCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.only(bottom: BookingDetailUi.cardGap),
      padding: padding ?? const EdgeInsets.all(BookingDetailUi.cardPadding),
      decoration: BookingDetailUi.cardDecoration(context),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: BookingDetailUi.cardGap),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BookingDetailUi.radius),
          child: Ink(
            width: double.infinity,
            padding:
                padding ?? const EdgeInsets.all(BookingDetailUi.cardPadding),
            decoration: BookingDetailUi.cardDecoration(context),
            child: child,
          ),
        ),
      ),
    );
  }
}

class BookingDetailSectionTitle extends StatelessWidget {
  const BookingDetailSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: BookingDetailUi.sectionTitleSize,
              fontWeight: FontWeight.w700,
              color: BookingDetailUi.of(context).text,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class BookingDetailEntryRow extends StatelessWidget {
  const BookingDetailEntryRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.done = false,
    this.showChevron = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool done;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BookingDetailCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: done
                  ? ShopFrontendTheme.successSoft
                  : BookingDetailUi.of(context).iconSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: done
                  ? BookingDetailUi.of(context).success
                  : BookingDetailUi.of(context).primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: BookingDetailUi.bodySize,
                    fontWeight: FontWeight.w600,
                    color: BookingDetailUi.of(context).text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: BookingDetailUi.captionSize,
                    color: BookingDetailUi.of(context).muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (done)
            Icon(
              Icons.check_circle,
              color: BookingDetailUi.of(context).success,
              size: 20,
            )
          else if (badge != null && badge!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ShopFrontendTheme.warningSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 11,
                  color: BookingDetailUi.of(context).warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (showChevron && onTap != null) ...<Widget>[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: BookingDetailUi.of(context).muted),
          ],
        ],
      ),
    );
  }
}

class BookingDetailSoftNetworkImage extends StatelessWidget {
  const BookingDetailSoftNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.pets_outlined,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = ColoredBox(
      color: BookingDetailUi.of(context).iconSoft,
      child: Icon(fallbackIcon, color: BookingDetailUi.of(context).primary),
    );

    final Widget image = url.trim().isEmpty
        ? fallback
        : Image.network(
            url,
            fit: fit,
            width: width,
            height: height,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
                  return fallback;
                },
          );

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: SizedBox(width: width, height: height, child: image),
    );
  }
}
