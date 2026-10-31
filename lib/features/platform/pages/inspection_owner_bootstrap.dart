import 'package:petnest_saas/core/services/inspection_browser_bridge.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Deliberate delegation only in a fresh, separate inspection window.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'package:petnest_saas/firebase_options.dart';
import 'package:petnest_saas/core/services/inspection_owner_context.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';

class InspectionFirebaseAlias extends FirebasePlatform {
  InspectionFirebaseAlias(this.delegate, this.name) {
    if (delegate.apps.any((app) => app.name == defaultFirebaseAppName)) {
      throw StateError('查核必須在獨立視窗啟動');
    }
  }
  final FirebasePlatform delegate;
  final String name;
  @override
  List<FirebaseAppPlatform> get apps => delegate.apps;
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      delegate.app(name == defaultFirebaseAppName ? this.name : name);
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) => name == null || name == defaultFirebaseAppName
      ? Future.value(app())
      : delegate.initializeApp(name: name, options: options);
}

class InspectionOwnerBootstrap extends StatefulWidget {
  const InspectionOwnerBootstrap({super.key, required this.nonce});
  final String nonce;
  @override
  State<InspectionOwnerBootstrap> createState() => _BootstrapState();
}

class _InspectionRouteAudit extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    InspectionOwnerContext.onView?.call(route.settings.name ?? '開啟後台頁面');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    InspectionOwnerContext.onView?.call(
      previousRoute?.settings.name ?? '返回後台頁面',
    );
  }
}

class _BootstrapState extends State<InspectionOwnerBootstrap> {
  String? error;
  DateTime lastParentAlive = DateTime.now();
  String viewPath = '店家後台';
  bool ready = false, busy = false, receiving = false, isolated = false;
  StreamSubscription<InspectionBrowserMessage>? messages;
  Timer? watchdog;
  StreamSubscription<User?>? identityChanges;
  DateTime lastInteraction = DateTime.now(),
      lastCheck = DateTime.fromMillisecondsSinceEpoch(0);
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _post(String type, [Map<String, dynamic> data = const {}]) =>
      inspectionPostToOpener({
        'type': type,
        'nonce': widget.nonce,
        ...data,
      }, Uri.base.origin);
  Future<void> _start() async {
    try {
      if (!inspectionHasOpener() ||
          !RegExp(r'^[a-f0-9]{48}$').hasMatch(widget.nonce)) {
        throw StateError('請從平台店家查核開啟');
      }
      final name = 'readonly_${widget.nonce}';
      await Firebase.initializeApp(
        name: name,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebasePlatform.instance = InspectionFirebaseAlias(
        FirebasePlatform.instance,
        name,
      );
      isolated = true;
      await FirebaseAuth.instance.setPersistence(Persistence.NONE);
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      final credential = await FirebaseAuth.instance.signInAnonymously();
      messages = inspectionBrowserMessages().listen((event) async {
        if (event.origin != Uri.base.origin ||
            !inspectionFromOpener(event) ||
            event.data is! Map) {
          return;
        }
        final data = Map<String, dynamic>.from(event.data as Map);
        if (data['nonce'] == widget.nonce &&
            data['type'] == 'inspection-alive') {
          lastParentAlive = DateTime.now();
          return;
        }
        if (data['nonce'] != widget.nonce ||
            data['type'] != 'inspection-grant' ||
            data['viewerUid'] != credential.user!.uid ||
            receiving) {
          return;
        }
        receiving = true;
        try {
          final token = await credential.user!.getIdTokenResult(true);
          if (token.claims?['petnestInspection'] != true ||
              token.claims?['inspectionGrant'] != data['grantId']) {
            throw StateError('唯讀身分驗證失敗');
          }
          final scope = await _validate();
          if (scope['shopId'] != data['shopId'] ||
              scope['ownerUid'] != data['ownerUid']) {
            throw StateError('查核店家驗證失敗');
          }
          InspectionOwnerContext.shopId = scope['shopId'] as String;
          InspectionOwnerContext.ownerUid = scope['ownerUid'] as String;
          identityChanges = FirebaseAuth.instance.idTokenChanges().listen((
            user,
          ) async {
            if (!ready) return;
            try {
              if (user?.uid != credential.user!.uid) {
                _fail(StateError('查核登入身分已改變'));
                return;
              }
              final latest = await user!.getIdTokenResult();
              if (latest.claims?['petnestInspection'] != true ||
                  latest.claims?['inspectionGrant'] != data['grantId']) {
                _fail(StateError('唯讀授權已失效'));
              }
            } catch (e) {
              _fail(e);
            }
          });
          lastParentAlive = DateTime.now();
          InspectionOwnerContext.active = true;
          InspectionOwnerContext.onView = (path) {
            viewPath = path;
            lastInteraction = DateTime.now();
            _post('inspection-touch', {'route': path});
          };
          InspectionOwnerContext.onExit = () {
            _fail(StateError('查核已關閉'));
            html.window.close();
          };
          if (mounted) setState(() => ready = true);
          _post('inspection-ready');
        } catch (e) {
          _fail(e);
        }
      });
      _post('inspection-request', {
        'idToken': await credential.user!.getIdToken(),
      });
      watchdog = Timer.periodic(const Duration(seconds: 10), (_) async {
        if (!ready || busy) return;
        _post('inspection-ping');
        if (DateTime.now().difference(lastParentAlive) >
                const Duration(seconds: 45) ||
            DateTime.now().difference(lastInteraction) >=
                const Duration(minutes: 30) ||
            !inspectionHasOpener()) {
          _fail(StateError('查核已鎖定，請回平台重新開啟'));
          return;
        }
        busy = true;
        try {
          if (lastInteraction.isAfter(lastCheck)) {
            _post('inspection-touch', {'route': viewPath});
          }
          await _validate();
          lastCheck = DateTime.now();
        } catch (e) {
          _fail(e);
        } finally {
          busy = false;
        }
      });
    } catch (e) {
      _fail(e);
    }
  }

  Future<Map<String, dynamic>> _validate() async {
    final result = await FirebaseFunctions.instanceFor(
      region: 'asia-east1',
    ).httpsCallable('inspectionPreviewHeartbeat').call({});
    return Map<String, dynamic>.from(result.data as Map);
  }

  void _fail(Object e) {
    InspectionOwnerContext.clear();
    final message = e is FirebaseException
        ? (e.message?.contains(RegExp(r'[\u4e00-\u9fff]')) == true
              ? e.message!
              : '查核連線失敗，請回平台重新開啟（${e.code}）')
        : '查核已停止，請回平台重新驗證後開啟。';
    _post('inspection-error', {'message': message});
    try {
      if (!isolated) throw StateError('查核尚未隔離');
      unawaited(
        FirebaseFunctions.instanceFor(region: 'asia-east1')
            .httpsCallable('inspectionPreviewHeartbeat')
            .call({'end': true})
            .then<void>((_) {}, onError: (Object _) {}),
      );
      unawaited(FirebaseAuth.instance.signOut().catchError((Object _) {}));
    } catch (_) {}
    if (mounted) {
      setState(() {
        ready = false;
        error = message;
      });
    }
  }

  @override
  void dispose() {
    messages?.cancel();
    identityChanges?.cancel();
    watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    key: ValueKey(ready),
    title: 'PetNest 店家唯讀查核',
    debugShowCheckedModeBanner: false,
    navigatorObservers: [_InspectionRouteAudit()],
    theme: PetNestAppTheme.build(),
    onGenerateRoute: (settings) {
      if (const {'/home', '/entry', '/admin'}.contains(settings.name)) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              ShopDashboardPage(shopId: InspectionOwnerContext.shopId),
        );
      }
      if (settings.name == '/login') {
        InspectionOwnerContext.onExit?.call();
        return MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink());
      }
      return null;
    },
    locale: const Locale('zh', 'TW'),
    supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The guard wraps the Navigator, so locking hides every nested detail page.
    builder: (context, child) => !ready
        ? Scaffold(
            body: Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : SelectableText(error!),
            ),
          )
        : Focus(
            onKeyEvent: (_, _) {
              lastInteraction = DateTime.now();
              return KeyEventResult.ignored;
            },
            child: Listener(
              onPointerDown: (_) => lastInteraction = DateTime.now(),
              onPointerSignal: (_) => lastInteraction = DateTime.now(),
              child: Column(
                children: [
                  Material(
                    color: const Color(0xFFFFF4DA),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '最高權限唯讀查核｜不能修改、刪除、退款、上傳或傳訊',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              tooltip: '鎖定查核',
                              onPressed: () => _fail(StateError('查核已鎖定')),
                              icon: const Icon(Icons.lock_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: child ?? const SizedBox.shrink()),
                ],
              ),
            ),
          ),
    home: ready
        ? ShopDashboardPage(shopId: InspectionOwnerContext.shopId)
        : const SizedBox.shrink(),
  );
}
