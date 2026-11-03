// 檔案名稱：lib/features/shop/widgets/environment/environment_bottom_note.dart
// 功能說明：環境介紹底部提醒卡
// 顯示住宿安排提醒文字

import 'package:flutter/material.dart';
import 'environment_appearance_surface.dart';
import 'package:petnest_saas/core/models/environment_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class EnvironmentBottomNote extends StatelessWidget {
  const EnvironmentBottomNote({
    super.key,
    required this.text,
    this.theme = HomeThemeModel.classicDefault,
    this.fontSize = 14,
    this.padding = 18,
    this.horizontalMargin = 16,
    this.title = '',
  });

  final String text, title;
  final HomeThemeModel theme;
  final double fontSize;
  final double padding;
  final double horizontalMargin;

  @override
  Widget build(BuildContext context) {
    var theme = EnvironmentAppearanceScope.cardTheme(context, this.theme);
    final scope = EnvironmentAppearanceScope.of(context);
    final customFill = scope?.appearance.color('cardColor');
    final fill = customFill ?? theme.primaryColor.withValues(alpha: 0.10);
    if (scope?.appearance.hasColors == true) {
      final appearance = scope!.appearance;
      final background = appearance.resolve(scope.baseTheme).backgroundColor;
      final surface = Color.alphaBlend(fill, background);
      theme = theme.copyWith(
        textColorValue: EnvironmentPageAppearance.readable(
          appearance.color('textColor') ?? scope.baseTheme.textColor,
          surface,
        ).toARGB32(),
        secondaryTextColorValue: EnvironmentPageAppearance.readable(
          appearance.color('secondaryTextColor') ??
              scope.baseTheme.secondaryTextColor,
          surface,
        ).toARGB32(),
        primaryColorValue: EnvironmentPageAppearance.readable(
          appearance.color('accentColor') ?? scope.baseTheme.primaryColor,
          surface,
        ).toARGB32(),
      );
    }
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            title.isEmpty
                ? Icons.favorite_rounded
                : Icons.notifications_none_rounded,
            color: theme.primaryColor,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: fontSize + 1,
                      color: theme.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: EnvironmentAppearanceScope.secondary(
                      context,
                      theme,
                      0.72,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
