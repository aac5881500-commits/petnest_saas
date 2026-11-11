// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_ui.dart
// 功能說明：客戶端訂單詳細頁共用暖色系樣式，對齊 PetNest 現代首頁。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';

class BookingDetailUi {
  BookingDetailUi._();

  static ShopFrontendTheme of(BuildContext context) =>
      ShopFrontendTheme.of(context);

  static const double radius = 20;
  static const double pagePadding = 16;
  static const double cardGap = 18;
  static const double cardPadding = 22;
  static const double maxContentWidth = 1160;

  static const double bodySize = 15;
  static const double captionSize = 13;
  static const double sectionTitleSize = 17;
  static const double statusSize = 23;
  static const double moneySize = 26;

  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? color,
    Color? borderColor,
  }) {
    final ShopFrontendTheme theme = of(context);
    return BoxDecoration(
      color: color ?? Color.lerp(theme.cardColor, theme.background, 0.15),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? theme.borderColor.withValues(alpha: 0.38),
      ),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x073A2A20),
          blurRadius: 24,
          offset: Offset(0, 6),
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
        Container(
          width: 4,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: BookingDetailUi.of(context).primary.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
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

/// One scroll surface keeps payment/message anchors reachable in both layouts.
class BookingDetailResponsiveLayout extends StatelessWidget {
  const BookingDetailResponsiveLayout({
    super.key,
    required this.children,
    required this.paymentIndex,
    this.controller,
  });

  final List<Widget> children;
  final int paymentIndex;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= 960;
        final double inset = constraints.maxWidth < 600 ? 16 : 32;
        Widget column(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        );
        return SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(inset, wide ? 28 : 16, inset, 40),
          child: BookingDetailUi.constrain(
            wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: column([
                          ...children.take(paymentIndex),
                          ...children.skip(paymentIndex + 2),
                        ]),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: column(
                          children.sublist(paymentIndex, paymentIndex + 2),
                        ),
                      ),
                    ],
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: column(children),
                  ),
          ),
        );
      },
    );
  }
}
