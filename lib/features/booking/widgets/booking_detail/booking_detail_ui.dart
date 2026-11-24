// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_ui.dart
// 功能說明：客戶端訂單詳細頁共用暖色系樣式，對齊 PetNest 現代首頁。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';

class BookingDetailUi {
  BookingDetailUi._();

  static ShopFrontendTheme of(BuildContext context) =>
      ShopFrontendTheme.of(context);

  static ShopFrontendTheme milkTea(ShopFrontendTheme source) =>
      ShopFrontendTheme(
        home: source.home.copyWith(
          backgroundColorValue: 0xFFF7F2EB,
          cardColorValue: 0xFFFFFCF8,
          cardBorderColorValue: 0xFFE4D9CB,
          primaryColorValue: 0xFF7B8050,
          textColorValue: 0xFF493B2F,
          secondaryTextColorValue: 0xFF817465,
          buttonBackgroundColorValue: 0xFF7B8050,
          buttonTextColorValue: 0xFFFFFFFF,
        ),
        primaryColor: const Color(0xFF7B8050),
        secondaryColor: const Color(0xFF746348),
        pageBackgroundColor: const Color(0xFFF7F2EB),
        cardColor: const Color(0xFFFFFCF8),
        titleColor: const Color(0xFF493B2F),
        bodyTextColor: const Color(0xFF493B2F),
        subtitleColor: const Color(0xFF817465),
        borderColor: const Color(0xFFE4D9CB),
        buttonColor: const Color(0xFF7B8050),
        onPrimaryColor: Colors.white,
        primarySoft: const Color(0xFFEEEEDC),
        disabledColor: const Color(0xFFB9B2A5),
      );

  static bool isMilkTea(BuildContext context) =>
      context.findAncestorWidgetOfExactType<BookingDetailMilkTeaScope>() !=
      null;
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
    final milk = isMilkTea(context);
    return BoxDecoration(
      color: color ?? Color.lerp(theme.cardColor, theme.background, 0.15),
      borderRadius: BorderRadius.circular(milk ? 18 : radius),
      border: Border.all(
        color:
            borderColor ?? theme.borderColor.withValues(alpha: milk ? .8 : .38),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Color(milk ? 0x043A2A20 : 0x073A2A20),
          blurRadius: milk ? 12 : 24,
          offset: Offset(0, milk ? 3 : 6),
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
    final milk = BookingDetailUi.isMilkTea(context);
    final gap = milk ? 14.0 : BookingDetailUi.cardGap;
    final inset = milk ? 18.0 : BookingDetailUi.cardPadding;
    final Widget content = Container(
      width: double.infinity,
      margin: margin ?? EdgeInsets.only(bottom: gap),
      padding: padding ?? EdgeInsets.all(inset),
      decoration: BookingDetailUi.cardDecoration(context),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return Padding(
      padding: margin ?? EdgeInsets.only(bottom: gap),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            milk ? 18 : BookingDetailUi.radius,
          ),
          child: Ink(
            width: double.infinity,
            padding: padding ?? EdgeInsets.all(inset),
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
        if (BookingDetailUi.isMilkTea(context))
          Padding(
            padding: const EdgeInsets.only(right: 9),
            child: Icon(
              text.contains('寵物')
                  ? Icons.pets_outlined
                  : text.contains('費用')
                  ? Icons.receipt_long_outlined
                  : text.contains('聯絡')
                  ? Icons.call_outlined
                  : text.contains('飼主')
                  ? Icons.person_outline
                  : Icons.notes_rounded,
              color: BookingDetailUi.of(context).secondaryColor,
              size: 22,
            ),
          )
        else
          Container(
            width: 4,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: BookingDetailUi.of(
                context,
              ).primary.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: BookingDetailUi.sectionTitleSize,
              fontFamily: BookingDetailUi.isMilkTea(context)
                  ? 'NotoSerifTC'
                  : null,
              fontWeight: FontWeight.w800,
              fontVariations: BookingDetailUi.isMilkTea(context)
                  ? const [FontVariation('wght', 800)]
                  : null,
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

/// Customer order detail appearance; business state and shop configuration stay intact.
class BookingDetailMilkTeaScope extends StatelessWidget {
  const BookingDetailMilkTeaScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final palette = BookingDetailUi.milkTea(ShopFrontendTheme.of(context));
    final base = Theme.of(context);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          primary: palette.primary,
          onPrimary: Colors.white,
          surface: palette.card,
          onSurface: palette.text,
          error: const Color(0xFFB65045),
        ).copyWith(
          primaryContainer: palette.primary,
          onPrimaryContainer: Colors.white,
          surfaceContainerLow: const Color(0xFFF0E9DF),
          onSurfaceVariant: palette.muted,
          outline: palette.border,
        );
    final readable = base.textTheme.apply(
      fontFamily: 'NotoSansTC',
      bodyColor: palette.text,
      displayColor: palette.text,
    );
    return ShopFrontendThemeInherited(
      theme: palette,
      child: Theme(
        data: base.copyWith(
          colorScheme: scheme,
          scaffoldBackgroundColor: palette.background,
          textTheme: readable.copyWith(
            bodyLarge: readable.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontVariations: const [FontVariation('wght', 600)],
              height: 1.5,
            ),
            bodyMedium: readable.bodyMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontVariations: const [FontVariation('wght', 600)],
              height: 1.5,
            ),
            bodySmall: readable.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontVariations: const [FontVariation('wght', 550)],
              height: 1.45,
            ),
            labelLarge: readable.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
            ),
            labelMedium: readable.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontVariations: const [FontVariation('wght', 600)],
            ),
            titleLarge: readable.titleLarge?.copyWith(
              fontFamily: 'NotoSerifTC',
              fontWeight: FontWeight.w800,
              fontVariations: const [FontVariation('wght', 800)],
            ),
            titleMedium: readable.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: palette.background,
            foregroundColor: palette.text,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: palette.card,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: palette.border),
            ),
          ),
          chipTheme: base.chipTheme.copyWith(
            backgroundColor: palette.card,
            selectedColor: palette.iconSoft,
            side: BorderSide(color: palette.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
