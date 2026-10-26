import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/room_intro_look.dart';

/// One font for the entire page, including Material controls and the app bar.
class RoomIntroTypography extends StatelessWidget {
  const RoomIntroTypography({
    super.key,
    required this.look,
    required this.child,
  });
  final RoomIntroLook look;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final font = look.appliedFontFamily;
    if (font == null) return child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: font),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: font),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle:
              (theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)
                  ?.copyWith(fontFamily: font),
          toolbarTextStyle:
              (theme.appBarTheme.toolbarTextStyle ?? theme.textTheme.bodyMedium)
                  ?.copyWith(fontFamily: font),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontFamily: font),
        child: child,
      ),
    );
  }
}
