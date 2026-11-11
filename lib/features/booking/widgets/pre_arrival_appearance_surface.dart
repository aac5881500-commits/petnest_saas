import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';

class PreArrivalPalette {
  const PreArrivalPalette({
    required this.accent,
    required this.ink,
    required this.paper,
    required this.card,
    required this.fontFamily,
    required this.overridden,
  });
  final Color accent, ink, paper, card;
  final String fontFamily;
  final bool overridden;
  Color get onAccent =>
      accent.computeLuminance() > .43 ? const Color(0xFF20242D) : Colors.white;
  static double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
  }

  static Color readable(Color desired, Color background) =>
      contrast(desired, background) >= 4.5
      ? desired
      : background.computeLuminance() > .4
      ? const Color(0xFF20242D)
      : Colors.white;
  factory PreArrivalPalette.resolve(
    PreArrivalGuideModel guide,
    ShopFrontendTheme theme,
    String? themeFont,
  ) {
    final a = guide.appearance;
    final packing = guide.style == 'packing',
        timeline = guide.style == 'timeline',
        classic = guide.style == 'classic';
    final originalAccent = Color(
      packing
          ? 0xFFC16A3C
          : timeline
          ? 0xFF8061B0
          : classic
          ? 0xFF648F79
          : 0xFFAF7C73,
    );
    final originalInk = Color(
      packing
          ? 0xFF59351F
          : timeline
          ? 0xFF25213F
          : classic
          ? 0xFF354F45
          : 0xFF514033,
    );
    final originalPaper = Color(
      packing
          ? 0xFFFFF8EE
          : timeline
          ? 0xFFFCFAFF
          : classic
          ? theme.background.toARGB32()
          : 0xFFFCF9F4,
    );
    final originalCard = Color(
      packing
          ? 0xFFFFFBF4
          : timeline
          ? 0xFFF4F0FC
          : 0xFFFFFFFF,
    );
    final accent = a.colorMode == 'theme'
        ? theme.primaryColor
        : a.colorMode == 'custom'
        ? a.color('accentColor') ?? originalAccent
        : originalAccent;
    final paper = a.colorMode == 'theme'
        ? theme.background
        : a.colorMode == 'custom'
        ? a.color('backgroundColor') ?? originalPaper
        : originalPaper;
    var card = a.colorMode == 'theme'
        ? theme.cardColor
        : a.colorMode == 'custom'
        ? a.color('cardColor') ?? originalCard
        : originalCard;
    final desired = a.colorMode == 'theme'
        ? theme.bodyTextColor
        : a.colorMode == 'custom'
        ? a.color('textColor') ?? originalInk
        : originalInk;
    final ink = readable(desired, paper);
    // A single page-wide text color must remain legible on both surfaces.
    // Preserve the selected card tone unless it would hide the text.
    if (contrast(ink, card) < 4.5) {
      for (var step = 1; step <= 10; step++) {
        final candidate = Color.lerp(card, paper, step / 10)!;
        if (contrast(ink, candidate) >= 4.5) {
          card = candidate;
          break;
        }
      }
    }
    final font = a.fontFamily == 'theme'
        ? themeFont ?? 'NotoSansTC'
        : a.fontFamily == 'style'
        ? (guide.style == 'minimal' ? 'NotoSerifTC' : 'jfOpenHuninn')
        : a.fontFamily;
    return PreArrivalPalette(
      accent: accent,
      ink: ink,
      paper: paper,
      card: card,
      fontFamily: font,
      overridden: a.colorMode != 'style',
    );
  }
}

class PreArrivalAppearanceScope extends InheritedWidget {
  const PreArrivalAppearanceScope({
    super.key,
    required this.palette,
    required super.child,
  });
  final PreArrivalPalette palette;
  static PreArrivalPalette of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PreArrivalAppearanceScope>()!
      .palette;
  @override
  bool updateShouldNotify(PreArrivalAppearanceScope oldWidget) =>
      oldWidget.palette != palette;
}

class PreArrivalAppearanceSurface extends StatelessWidget {
  const PreArrivalAppearanceSurface({
    super.key,
    required this.guide,
    required this.builder,
  });
  final PreArrivalGuideModel guide;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) {
    final old = Theme.of(context), media = MediaQuery.of(context);
    final palette = PreArrivalPalette.resolve(
      guide,
      ShopFrontendTheme.of(context),
      old.textTheme.bodyMedium?.fontFamily,
    );
    final theme = old.copyWith(
      textTheme: old.textTheme.apply(
        fontFamily: palette.fontFamily,
        bodyColor: palette.ink,
        displayColor: palette.ink,
      ),
      primaryTextTheme: old.primaryTextTheme.apply(
        fontFamily: palette.fontFamily,
      ),
      colorScheme: old.colorScheme.copyWith(
        primary: palette.accent,
        onPrimary: palette.onAccent,
        surface: palette.card,
        onSurface: palette.ink,
      ),
      scaffoldBackgroundColor: palette.paper,
    );
    return PreArrivalAppearanceScope(
      palette: palette,
      child: Theme(
        data: theme,
        child: MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(1) * guide.appearance.fontScale,
            ),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: palette.fontFamily,
              color: palette.ink,
            ),
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
  }
}
