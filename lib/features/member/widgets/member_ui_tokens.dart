// 會員中心排版規格；品牌色一律從 ShopFrontendTheme 讀取。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';

class MemberUi {
  MemberUi._();

  static ShopFrontendTheme of(BuildContext context) =>
      ShopFrontendTheme.of(context);

  static const double radius = 16;
  static const double pagePadding = 16;
  static const double cardGap = 12;
  static const double cardPadding = 15;
  static const double maxContentWidth = 720;
  static const double titleSize = 20;
  static const double sectionSize = 17.5;
  static const double cardTitleSize = 15.5;
  static const double bodySize = 14;
  static const double captionSize = 12.5;
  static const double heroNumberSize = 30;

  static BoxDecoration cardDecoration(BuildContext context, {Color? color}) {
    final ShopFrontendTheme theme = of(context);
    return BoxDecoration(
      color: color ?? theme.cardColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: theme.borderColor),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x0A3A2A20),
          blurRadius: 8,
          offset: Offset(0, 2),
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

  static String friendlyError(Object error) {
    final String raw = error.toString().toLowerCase();
    if (raw.contains('permission-denied') ||
        raw.contains('permission_denied')) {
      return '目前沒有權限查看此內容，請重新登入後再試。';
    }
    return '目前無法載入資料，請稍後再試。';
  }

  static void logError(Object error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('MEMBER_UI_ERROR: $error');
      if (stackTrace != null) {
        debugPrint('$stackTrace');
      }
    }
  }
}
