import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_editorial_design.dart';

class BookingFormPresentation {
  static bool enabled(BookingPageAppearance? a) =>
      a != null && const ['cream', 'editorial'].contains(a.style);
  static HomeThemeModel resolve(
    BookingPageAppearance? a,
    HomeThemeModel fallback,
    HomeThemeModel? frontend,
  ) {
    if (!enabled(a)) return fallback;
    final base = a!.style == 'cream'
        ? const HomeThemeModel(
            backgroundColorValue: 0xFFFFFEFB,
            cardColorValue: 0xFFFFFFFF,
            cardBorderColorValue: 0xFFB9DFF7,
            primaryColorValue: 0xFF429ADA,
            textColorValue: 0xFF60402D,
          )
        : const HomeThemeModel(
            backgroundColorValue: 0xFFFAF7F1,
            cardColorValue: 0xFFFAF7F1,
            cardBorderColorValue: 0xFFD3D0C7,
            primaryColorValue: 0xFF204528,
            textColorValue: 0xFF204528,
          );
    return a.applyLook(base, frontendTheme: frontend ?? fallback);
  }

  static String font(BookingPageAppearance a) => a.look.font.isNotEmpty
      ? a.look.font
      : a.style == 'cream'
      ? 'jfOpenHuninn'
      : 'NotoSerifTC';
  static InputDecoration field(
    BookingPageAppearance a,
    HomeThemeModel t,
    String label, {
    String? hint,
  }) {
    final radius = BorderRadius.circular(a.style == 'cream' ? 18 : 8);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: t.cardColor,
      labelStyle: TextStyle(
        fontFamily: font(a),
        color: t.textColor.withValues(alpha: .8),
        fontSize: 14,
      ),
      hintStyle: TextStyle(
        fontFamily: font(a),
        color: t.textColor.withValues(alpha: .5),
        fontSize: 14,
      ),
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: t.cardBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: t.cardBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: t.primaryColor, width: 1.6),
      ),
    );
  }
}

class BookingFormSurface extends StatelessWidget {
  const BookingFormSurface({
    super.key,
    required this.appearance,
    required this.theme,
    required this.child,
    this.frontendTheme,
  });
  final BookingPageAppearance appearance;
  final HomeThemeModel theme;
  final HomeThemeModel? frontendTheme;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final weight = appearance.look.fontWeight;
    var text = base.textTheme.apply(
      fontFamily: BookingFormPresentation.font(appearance),
      bodyColor: theme.textColor,
      displayColor: theme.textColor,
    );
    if (weight != null) {
      final w = FontWeight.values[weight ~/ 100 - 1];
      text = text.copyWith(
        bodyLarge: text.bodyLarge?.copyWith(fontWeight: w),
        bodyMedium: text.bodyMedium?.copyWith(fontWeight: w),
        bodySmall: text.bodySmall?.copyWith(fontWeight: w),
      );
    }
    return BookingAppearanceScope(
      appearance: appearance,
      frontendTheme: frontendTheme,
      child: Theme(
        data: base.copyWith(
          scaffoldBackgroundColor: theme.backgroundColor,
          textTheme: text,
          colorScheme: base.colorScheme.copyWith(
            primary: theme.primaryColor,
            surface: theme.cardColor,
            onSurface: theme.textColor,
            onSurfaceVariant: theme.textColor.withValues(alpha: .75),
          ),
          dividerColor: theme.cardBorderColor,
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith(
              (s) =>
                  s.contains(WidgetState.selected) ? theme.primaryColor : null,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

class BookingFormIntro extends StatelessWidget {
  const BookingFormIntro({super.key, required this.shopName});
  final String shopName;
  @override
  Widget build(BuildContext context) {
    final cream = BookingAppearanceScope.of(context).style == 'cream';
    final t = BookingEditorial.theme(context);
    return Container(
      key: const ValueKey('booking-form-intro'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      padding: EdgeInsets.all(cream ? 20 : 4),
      decoration: BoxDecoration(
        color: cream ? BookingEditorial.tint(context) : null,
        borderRadius: cream ? BorderRadius.circular(26) : null,
        border: cream
            ? null
            : Border(bottom: BorderSide(color: t.cardBorderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shopName.isNotEmpty)
            Text(shopName, style: BookingEditorial.body(13, context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                cream ? Icons.pets_outlined : Icons.edit_note_outlined,
                color: t.primaryColor,
                size: 26,
              ),
              Text('填寫住宿資料', style: BookingEditorial.title(25, context)),
            ],
          ),
          const SizedBox(height: 8),
          Text('留下聯絡資訊，讓貓咪的旅程更安心。', style: BookingEditorial.body(14, context)),
          const SizedBox(height: 6),
          Text(
            '＊為必填欄位，送出前請確認付款方式與服務條款。',
            style: BookingEditorial.body(12, context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class BookingFormSection extends StatelessWidget {
  const BookingFormSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final cream = BookingAppearanceScope.of(context).style == 'cream';
    final t = BookingEditorial.theme(context);
    final icon = switch (title) {
      '聯絡資料' => Icons.person_outline,
      '地址' => Icons.location_on_outlined,
      '緊急聯絡人' => Icons.contact_phone_outlined,
      '訂單備註' => Icons.notes_outlined,
      '費用與付款' => Icons.account_balance_wallet_outlined,
      _ => Icons.assignment_outlined,
    };
    return Container(
      key: ValueKey('booking-form-section-$title'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: cream
          ? const EdgeInsets.all(18)
          : const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: cream ? t.cardColor : null,
        borderRadius: cream ? BorderRadius.circular(24) : null,
        border: cream
            ? Border.all(color: t.cardBorderColor)
            : Border(bottom: BorderSide(color: t.cardBorderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cream)
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(bottom: 14),
              child: Wrap(
                spacing: 9,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.primaryColor.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: t.primaryColor, size: 21),
                  ),
                  Text(title, style: BookingEditorial.title(19, context)),
                ],
              ),
            )
          else
            BookingEditorial.heading(title),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(subtitle!, style: BookingEditorial.body(13, context)),
            ),
          ...children,
        ],
      ),
    );
  }
}
