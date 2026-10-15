// 檔案名稱：lib/main.dart
// 功能說明：Flutter 應用程式入口，初始化 Firebase、路由與全域錯誤處理

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/features/auth/pages/home_page.dart';
import 'package:petnest_saas/features/platform/widgets/platform_policy_gate.dart';
import 'package:petnest_saas/core/services/auth_service.dart';
import 'package:petnest_saas/features/auth/pages/email_verification_page.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/firebase_options.dart';
import 'package:petnest_saas/features/shop/pages/shop_code_redirect_page.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/services/fcm_token_service.dart';
import 'package:petnest_saas/core/services/fcm_message_service.dart';
import 'package:petnest_saas/core/navigation/app_navigator.dart';
import 'package:petnest_saas/core/web/petnest_startup_screen.dart';
import 'package:petnest_saas/core/web/web_update_controller.dart';
import 'package:petnest_saas/core/web/web_update_prompt.dart';

const Duration _startupSlowHint = Duration(seconds: 12);
const Duration _authReloadLimit = Duration(seconds: 12);
const Duration _entryQueryLimit = Duration(seconds: 20);

void _startupLog(
  String stage,
  String status, {
  int? elapsedMs,
  String? reason,
}) {
  final StringBuffer line = StringBuffer('[PetNestStartup] $stage $status');
  if (elapsedMs != null) {
    line.write(' elapsedMs=$elapsedMs');
  }
  if (reason != null && reason.isNotEmpty) {
    line.write(' reason=$reason');
  }
  debugPrint(line.toString());
}

String _startupReason(Object error) {
  if (error is FirebaseException) {
    return error.code;
  }
  if (error is TimeoutException) {
    return 'timeout';
  }
  return error.runtimeType.toString();
}

void _dismissWebStartupShell() {
  if (!kIsWeb) return;
  html.document.getElementById('petnest-startup')?.remove();
}

void _reloadWebPage() {
  html.window.location.reload();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    FlutterError.onError = (FlutterErrorDetails details) {
      try {
        FlutterError.presentError(details);
      } catch (_) {}
      try {
        print('[GLOBAL FlutterError]');
        print(ChatErrorProbe.describe(details.exception));
        print(details.exceptionAsString());
        print(details.stack);
        ChatErrorProbe.dump(
          'GLOBAL FlutterError',
          details.exception,
          details.stack ?? StackTrace.empty,
        );
      } catch (error, stack) {
        print('[GLOBAL FlutterError] probe failed');
        print(error);
        print(stack);
      }
    };
    WidgetsBinding.instance.platformDispatcher.onError =
        (Object error, StackTrace stack) {
          try {
            print('[GLOBAL PlatformError]');
            print('type=${error.runtimeType}');
            print(ChatErrorProbe.describe(error));
            print(error);
            print(stack);
            ChatErrorProbe.dump('GLOBAL PlatformError', error, stack);
          } catch (probeError, probeStack) {
            print('[GLOBAL PlatformError] probe failed');
            print(probeError);
            print(probeStack);
          }
          return false;
        };
  }

  // 手機維持先完成 Firebase 再進入 App。
  // Web 先畫出啟動畫面，避免 initializeApp 卡住 IndexedDB 時整頁空白。
  if (kIsWeb) {
    runApp(const PetNestWebBootstrap());
    return;
  }

  // 📱 只在手機 App 鎖直向；Web 後台不鎖方向
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FcmTokenService.instance.listenTokenRefresh();

  runApp(const PetNestApp());
}

class PetNestApp extends StatefulWidget {
  const PetNestApp({super.key});

  @override
  State<PetNestApp> createState() => _PetNestAppState();
}

class _PetNestAppState extends State<PetNestApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WebUpdateController.instance.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WebUpdateController.instance.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (BuildContext context, Widget? child) {
        return WebUpdateOverlay(child: child ?? const SizedBox.shrink());
      },
      navigatorKey: AppNavigator.key,
      title: 'PetNest SaaS',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'TW'),
      supportedLocales: const <Locale>[Locale('zh', 'TW'), Locale('en', 'US')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: PetNestAppTheme.build(),

      /// 🔥 一定要有這段
      routes: {
        '/member': (context) {
          throw UnimplementedError('MemberPage 必須傳入 shopId，請由 Drawer 或首頁進入。');
        },
        '/login': (context) => const LoginPage(),
        '/home': (context) =>
            const _VerifiedEntry(child: PlatformPolicyGate(child: HomePage())),
        '/entry': (context) => const AppEntryPage(),

        // 🖥️ 店家 Web 後台入口
        '/admin': (context) => const AppEntryPage(),
      },

      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');

        if (uri.pathSegments.length == 2 && uri.pathSegments.first == 's') {
          final shopCode = uri.pathSegments[1];

          return MaterialPageRoute(
            builder: (_) => ShopCodeRedirectPage(shopCode: shopCode),
          );
        }

        return null;
      },

      home: kIsWeb ? const AppEntryPage() : const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _showEntry = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _showEntry = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showEntry) {
      return const AppEntryPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/app_logo.png',
                width: 350,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),

              const Text(
                '全台寵物旅宿管理平台',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),

              const SizedBox(height: 32),

              const CircularProgressIndicator(),

              const SizedBox(height: 16),

              const Text(
                '載入中...',
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PetNestWebBootstrap extends StatefulWidget {
  const PetNestWebBootstrap({super.key});

  @override
  State<PetNestWebBootstrap> createState() => _PetNestWebBootstrapState();
}

class _PetNestWebBootstrapState extends State<PetNestWebBootstrap> {
  Timer? _slowTimer;
  bool _ready = false;
  bool _slow = false;
  bool _failed = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final Stopwatch bootstrap = Stopwatch()..start();
    _startupLog(
      'Flutter bootstrap',
      'done',
      elapsedMs: bootstrap.elapsedMilliseconds,
    );
    _startupLog('App Check initialize', 'skipped', reason: 'not-configured');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dismissWebStartupShell();
    });
    _slowTimer = Timer(_startupSlowHint, () {
      if (!mounted || _ready || _failed) return;
      _startupLog('Firebase initialize', 'timeout');
      setState(() => _slow = true);
    });
    _startFirebase();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _startFirebase() async {
    if (_starting) return;
    _starting = true;
    final Stopwatch watch = Stopwatch()..start();
    _startupLog('Firebase initialize', 'start');
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FcmTokenService.instance.listenTokenRefresh();
      _startupLog(
        'Firebase initialize',
        'done',
        elapsedMs: watch.elapsedMilliseconds,
      );
      if (!mounted) return;
      setState(() {
        _ready = true;
        _failed = false;
        _slow = false;
      });
    } catch (error) {
      if (Firebase.apps.isNotEmpty) {
        FcmTokenService.instance.listenTokenRefresh();
        _startupLog(
          'Firebase initialize',
          'done',
          elapsedMs: watch.elapsedMilliseconds,
          reason: 'already-initialized',
        );
        if (!mounted) return;
        setState(() {
          _ready = true;
          _failed = false;
        });
        return;
      }
      _startupLog(
        'Firebase initialize',
        'fail',
        elapsedMs: watch.elapsedMilliseconds,
        reason: _startupReason(error),
      );
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      _starting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const PetNestApp();
    }
    // 此時尚未進入 PetNestApp。這層畫面只存在於等待或失敗狀態，
    // 初始化完成後會整棵換掉，不會包在正式 App 外面。
    return PetNestStartupFrame(
      child: PetNestStartupStatus(
        title: _failed ? 'PetNest 暫時無法啟動' : 'PetNest',
        message: _failed
            ? '連線準備沒有完成。可以再試一次，不會清除登入資料。'
            : _slow
            ? '啟動時間較長，仍在等待。重新整理不會清除登入資料。'
            : '正在準備連線',
        busy: !_failed,
        showRetry: _failed || _slow,
        retryLabel: _failed ? '再試一次' : '重新整理',
        onRetry: _failed ? _startFirebase : _reloadWebPage,
      ),
    );
  }
}

class AppEntryPage extends StatefulWidget {
  const AppEntryPage({super.key});

  @override
  State<AppEntryPage> createState() => _AppEntryPageState();
}

class _AppEntryPageState extends State<AppEntryPage> {
  StreamSubscription<User?>? _authSub;
  Timer? _authSlowTimer;
  Stopwatch? _authWatch;
  Future<Widget>? _pageFuture;
  int _generation = 0;
  bool _authReady = false;
  bool _authSlow = false;
  bool _entryFailed = false;
  bool _loggedFirstScreen = false;
  bool _loggedAuthDone = false;
  String? _pendingUid;
  User? _knownUser;

  @override
  void initState() {
    super.initState();
    _listenAuth();
  }

  @override
  void dispose() {
    _authSlowTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _listenAuth() {
    _authSub?.cancel();
    _authSlowTimer?.cancel();
    _authWatch = Stopwatch()..start();
    _loggedAuthDone = false;
    _startupLog('Auth state restore', 'start');
    _authSlowTimer = Timer(_startupSlowHint, () {
      if (!mounted || _authReady) return;
      _startupLog(
        'Auth state restore',
        'timeout',
        elapsedMs: _authWatch?.elapsedMilliseconds,
      );
      setState(() => _authSlow = true);
    });
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) {
        final String uid = user?.uid ?? '';
        if (!_entryFailed && uid == _pendingUid) {
          return;
        }
        _pendingUid = uid;
        _authSlowTimer?.cancel();
        if (!_loggedAuthDone) {
          _loggedAuthDone = true;
          _startupLog(
            'Auth state restore',
            'done',
            elapsedMs: _authWatch?.elapsedMilliseconds,
          );
        }
        _startDecision(user);
      },
      onError: (Object error) {
        _startupLog(
          'Auth state restore',
          'fail',
          elapsedMs: _authWatch?.elapsedMilliseconds,
          reason: _startupReason(error),
        );
        if (!mounted) return;
        setState(() => _authSlow = true);
      },
    );
  }

  void _startDecision(User? user) {
    final int generation = ++_generation;
    _knownUser = user;
    _startupLog('Entry page decision', 'start');
    final Future<Widget> future = _decideEntryPage(user, generation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _authReady = true;
        _authSlow = false;
        _entryFailed = false;
        _loggedFirstScreen = false;
        _pageFuture = future;
      });
    });
  }

  Future<Widget> _decideEntryPage(User? user, int generation) async {
    final Stopwatch watch = Stopwatch()..start();
    try {
      if (user == null) {
        _startupLog(
          'Entry page decision',
          'done',
          elapsedMs: watch.elapsedMilliseconds,
        );
        return const LoginPage();
      }

      User resolved = user;
      try {
        final User? reloaded = await AuthService.instance
            .reloadCurrentUser()
            .timeout(_authReloadLimit);
        resolved = reloaded ?? FirebaseAuth.instance.currentUser ?? user;
      } on TimeoutException {
        _startupLog('Auth state restore', 'timeout', reason: 'reload');
        resolved = FirebaseAuth.instance.currentUser ?? user;
      } catch (error) {
        _startupLog(
          'Auth state restore',
          'fail',
          reason: _startupReason(error),
        );
        resolved = FirebaseAuth.instance.currentUser ?? user;
      }

      if (AuthService.instance.mustVerifyEmail(resolved)) {
        _startupLog(
          'Entry page decision',
          'done',
          elapsedMs: watch.elapsedMilliseconds,
        );
        return const EmailVerificationPage();
      }

      // 🔔 手機使用者登入後，自動同步 FCM Token
      // Web 會由 FcmTokenService 自動略過
      Future<void>.microtask(() async {
        try {
          print('[AppEntry] FCM microtask start');
          await FcmTokenService.instance.saveCurrentUserToken();
          await FcmMessageService.instance.initialize();
          print('[AppEntry] FCM microtask success');
        } catch (e, st) {
          print('[AppEntry] FCM microtask failed');
          ChatErrorProbe.dump('AppEntry FCM', e, st);
        }
      });

      final List<Map<String, dynamic>> myShops = await ShopService.instance
          .getMyShops()
          .timeout(_entryQueryLimit);
      if (generation != _generation) {
        return const SizedBox.shrink();
      }
      if (myShops.isNotEmpty) {
        _startupLog(
          'Entry page decision',
          'done',
          elapsedMs: watch.elapsedMilliseconds,
        );
        return const PlatformPolicyGate(child: HomePage());
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance()
          .timeout(_entryQueryLimit);
      if (generation != _generation) {
        return const SizedBox.shrink();
      }
      final String? lastShopId = prefs.getString('last_customer_shop_id');
      _startupLog(
        'Entry page decision',
        'done',
        elapsedMs: watch.elapsedMilliseconds,
      );
      if (lastShopId != null && lastShopId.isNotEmpty) {
        return PlatformPolicyGate(child: ShopPublicPage(shopId: lastShopId));
      }
      return const PlatformPolicyGate(child: HomePage());
    } on TimeoutException {
      _startupLog(
        'Entry page decision',
        'timeout',
        elapsedMs: watch.elapsedMilliseconds,
      );
      if (mounted && generation == _generation) {
        setState(() => _entryFailed = true);
      }
      rethrow;
    } catch (error) {
      _startupLog(
        'Entry page decision',
        'fail',
        elapsedMs: watch.elapsedMilliseconds,
        reason: _startupReason(error),
      );
      if (mounted && generation == _generation) {
        setState(() => _entryFailed = true);
      }
      rethrow;
    }
  }

  void _markFirstScreen() {
    if (_loggedFirstScreen) return;
    _loggedFirstScreen = true;
    _startupLog('First screen ready', 'done');
  }

  @override
  Widget build(BuildContext context) {
    if (!_authReady) {
      return PetNestStartupStatus(
        title: 'PetNest',
        message: _authSlow
            ? '登入狀態確認時間較長。可以再試一次，不會清除登入資料，也不會進入內頁。'
            : '正在確認登入狀態',
        busy: true,
        showRetry: _authSlow,
        retryLabel: kIsWeb ? '重新整理' : '再試一次',
        onRetry: kIsWeb ? _reloadWebPage : _listenAuth,
      );
    }

    if (_entryFailed) {
      return PetNestStartupStatus(
        title: 'PetNest',
        message: '暫時無法確認要進入的頁面。請再試一次，不會變更登入狀態。',
        busy: false,
        showRetry: true,
        retryLabel: '再試一次',
        onRetry: () =>
            _startDecision(_knownUser ?? FirebaseAuth.instance.currentUser),
      );
    }

    return FutureBuilder<Widget>(
      future: _pageFuture,
      builder: (BuildContext context, AsyncSnapshot<Widget> pageSnapshot) {
        if (pageSnapshot.connectionState != ConnectionState.done) {
          return const PetNestStartupStatus(
            title: 'PetNest',
            message: '正在準備首頁',
          );
        }
        if (pageSnapshot.hasError || pageSnapshot.data == null) {
          return PetNestStartupStatus(
            title: 'PetNest',
            message: '暫時無法確認要進入的頁面。請再試一次，不會變更登入狀態。',
            busy: false,
            showRetry: true,
            retryLabel: '再試一次',
            onRetry: () => _startDecision(
              _knownUser ?? FirebaseAuth.instance.currentUser,
            ),
          );
        }
        _markFirstScreen();
        return pageSnapshot.data!;
      },
    );
  }
}

class _VerifiedEntry extends StatefulWidget {
  const _VerifiedEntry({required this.child});

  final Widget child;

  @override
  State<_VerifiedEntry> createState() => _VerifiedEntryState();
}

class _VerifiedEntryState extends State<_VerifiedEntry> {
  late final Future<bool> _allowed = _check();

  Future<bool> _check() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return true;
    }
    try {
      final User? fresh = await AuthService.instance.reloadCurrentUser();
      if (fresh == null) {
        return true;
      }
      return !AuthService.instance.mustVerifyEmail(fresh);
    } catch (error) {
      debugPrint('首頁驗證狀態讀取失敗');
      return !AuthService.instance.mustVerifyEmail(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _allowed,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == false) {
          return const EmailVerificationPage();
        }
        return widget.child;
      },
    );
  }
}
