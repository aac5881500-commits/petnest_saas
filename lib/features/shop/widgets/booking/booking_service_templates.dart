import 'booking_editorial_design.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class BookingServiceTemplates {
  static HomeThemeModel themeFor(String style, HomeThemeModel original) =>
      switch (style) {
        'cream' => original.copyWith(
          backgroundColorValue: 0xFFFFFEFB,
          cardColorValue: 0xFFFFFFFF,
          primaryColorValue: 0xFF429ADA,
          textColorValue: 0xFF60402D,
          cardBorderColorValue: 0xFFB9DFF7,
          appBackgroundMode: ShopAppBackground.modeColor,
        ),
        'editorial' => original.copyWith(
          backgroundColorValue: 0xFFFAF7F1,
          cardColorValue: 0xFFFAF7F1,
          primaryColorValue: 0xFF204528,
          textColorValue: 0xFF204528,
          cardBorderColorValue: 0xFFD3D0C7,
          appBackgroundMode: ShopAppBackground.modeColor,
        ),
        'journal' => original.copyWith(
          backgroundColorValue: 0xFFFFFBF2,
          cardColorValue: 0xFFFFFEFA,
          primaryColorValue: 0xFF679CBA,
          textColorValue: 0xFF674B39,
          cardBorderColorValue: 0xFFE8D8BC,
          appBackgroundMode: ShopAppBackground.modeColor,
        ),
        'premium' => original.copyWith(
          backgroundColorValue: 0xFFFAF8F4,
          cardColorValue: 0xFFFFFFFF,
          primaryColorValue: 0xFF8E6635,
          textColorValue: 0xFF233247,
          cardBorderColorValue: 0xFFD8CBB8,
          appBackgroundMode: ShopAppBackground.modeColor,
        ),
        _ => original,
      };
  static Widget header(
    String style,
    HomeThemeModel theme,
    String title,
    String subtitle,
    String number,
  ) {
    if (style == 'original') return const SizedBox.shrink();
    if (style == 'editorial' || style == 'cream') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: BookingEditorial.heading(
          number == '02' ? '加購服務' : title,
          subtitle: subtitle,
        ),
      );
    }
    if (style == 'premium') {
      return Container(
        width: double.infinity,
        color: const Color(0xFF233247),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (style == 'journal')
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: .15),
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: style == 'editorial' ? 2 : 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: .75),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (style == 'journal' && number == '01')
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/booking_demo_ginger_chibi_v1.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
