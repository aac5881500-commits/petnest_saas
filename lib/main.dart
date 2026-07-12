//lib/main.dart 入口

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/features/auth/pages/home_page.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/firebase_options.dart';
import 'package:petnest_saas/features/member/pages/member_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_code_redirect_page.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/services/fcm_token_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📱 只在手機 App 鎖直向；Web 後台不鎖方向
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FcmTokenService.instance.listenTokenRefresh();

  runApp(const PetNestApp());
}

class PetNestApp extends StatelessWidget {
  const PetNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetNest SaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),

      /// 🔥 一定要有這段
      routes: {
        '/member': (context) => const MemberPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),

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

      home: const SplashPage(),
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

class AppEntryPage extends StatelessWidget {
  const AppEntryPage({super.key});

  Future<void> _enableNotifications(BuildContext context) async {
    try {
      await FcmTokenService.instance.saveCurrentUserToken();

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('通知設定完成')));
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('通知開啟失敗：$error')));
    }
  }

  Future<Widget> _decideEntryPage() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginPage();
    }

    // Future.microtask(() {
    //  FcmTokenService.instance.saveCurrentUserToken();
    //});

    // 有店家身分：店主 / 員工照原本進 HomePage
    final myShops = await ShopService.instance.getMyShops();
    if (myShops.isNotEmpty) {
      return const HomePage();
    }

    // 一般客戶：回到最後掃過 / 逛過的店
    final prefs = await SharedPreferences.getInstance();
    final lastShopId = prefs.getString('last_customer_shop_id');

    if (lastShopId != null && lastShopId.isNotEmpty) {
      return ShopPublicPage(shopId: lastShopId);
    }

    // 沒有最後店家，就照原本首頁
    return const HomePage();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return FutureBuilder<Widget>(
          future: _decideEntryPage(),
          builder: (context, pageSnapshot) {
            if (pageSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final page = pageSnapshot.data ?? const LoginPage();

            if (authSnapshot.data == null) {
              return page;
            }

            return Stack(
              children: [
                page,
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: SafeArea(
                    child: FloatingActionButton.extended(
                      onPressed: () => _enableNotifications(context),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('開啟通知'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
