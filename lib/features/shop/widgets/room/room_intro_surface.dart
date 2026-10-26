import 'room_intro_typography.dart';
// 功能：局部外觀背景重用既有素材解析與快取，不改店家全站主題。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/room_intro_look.dart';
import '../shop_app_backdrop.dart';

class RoomIntroSurface extends StatelessWidget {
  const RoomIntroSurface({
    super.key,
    required this.look,
    required this.theme,
    required this.child,
  });
  final RoomIntroLook look;
  final HomeThemeModel theme;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final local = look.background == 'theme'
        ? theme
        : theme.copyWith(
            backgroundColorValue: look.backgroundColor,
            appBackgroundMode: look.background == 'library' ? 'image' : 'color',
            appBackgroundAssetId: look.backgroundAssetId,
          );
    return RoomIntroTypography(
      look: look,
      child: ShopAppBackdrop.behind(theme: local, child: child),
    );
  }
}
