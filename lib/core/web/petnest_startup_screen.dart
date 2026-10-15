import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';

const Color _startupBackground = Color(0xFFFFF8F0);

/// 正式 App 內部的啟動狀態。呼叫端必須已經在 MaterialApp 之下。
class PetNestStartupStatus extends StatelessWidget {
  const PetNestStartupStatus({
    super.key,
    required this.title,
    required this.message,
    this.busy = true,
    this.showRetry = false,
    this.retryLabel = '再試一次',
    this.onRetry,
  });

  final String title;
  final String message;
  final bool busy;
  final bool showRetry;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _startupBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3D342C),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (busy) ...<Widget>[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF6B5E55),
                    ),
                  ),
                  if (showRetry) ...<Widget>[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onRetry,
                      child: Text(retryLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web 在 PetNestApp 建立前使用。初始化完成後由呼叫端整棵替換，不包住正式 App。
class PetNestStartupFrame extends StatelessWidget {
  const PetNestStartupFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'TW'),
      supportedLocales: const <Locale>[
        Locale('zh', 'TW'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: PetNestAppTheme.build(),
      home: child,
    );
  }
}
