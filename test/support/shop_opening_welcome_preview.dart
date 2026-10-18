// 檔案名稱：test/support/shop_opening_welcome_preview.dart
// 功能說明：本機歡迎頁視覺驗證入口，不初始化 Firebase 或改動正式 main.dart。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/features/auth/pages/shop_opening_welcome_page.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: PetNestAppTheme.build(),
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/welcome',
      routes: {
        '/': (_) => const Scaffold(body: Center(child: Text('本機畫面驗證入口'))),
        '/welcome': (_) =>
            const ShopOpeningWelcomePage(activationCode: 'LOCAL-PREVIEW-ONLY'),
      },
    ),
  );
}
