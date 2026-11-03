import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_desktop_layout_setting.dart';

class HomeDesktopLayoutScope extends InheritedWidget {
  const HomeDesktopLayoutScope({
    super.key,
    required this.setting,
    required this.desktop,
    required super.child,
  });
  final HomeDesktopLayoutSetting setting;
  final bool desktop;
  static HomeDesktopLayoutSetting? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<HomeDesktopLayoutScope>();
    return scope?.desktop == true ? scope!.setting : null;
  }

  @override
  bool updateShouldNotify(HomeDesktopLayoutScope oldWidget) =>
      desktop != oldWidget.desktop ||
      setting.preset != oldWidget.setting.preset;
}

/// Actual home and editor previews use the same bounded desktop container.
class HomeDesktopLayoutFrame extends StatelessWidget {
  const HomeDesktopLayoutFrame({
    super.key,
    required this.setting,
    required this.background,
    required this.child,
  });
  final HomeDesktopLayoutSetting setting;
  final Color background;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final desktop = c.maxWidth >= HomeDesktopLayoutSetting.breakpoint;
      return HomeDesktopLayoutScope(
        setting: setting,
        desktop: desktop,
        child: ColoredBox(
          color: background,
          child: desktop
              ? Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: setting.maxWidth),
                    child: SizedBox(
                      width: double.infinity,
                      height: c.maxHeight.isFinite ? c.maxHeight : null,
                      child: child,
                    ),
                  ),
                )
              : child,
        ),
      );
    },
  );
}
