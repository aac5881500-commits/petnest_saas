import 'package:flutter/material.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';

class MemberSignInPrompt extends StatelessWidget {
  const MemberSignInPrompt({super.key, required this.shopId, this.onLogin});
  final String shopId;
  final VoidCallback? onLogin;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('會員中心')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text('登入後開啟會員中心', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                '你目前以訪客身分瀏覽。登入後即可管理個人資料、寵物與訂單。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.7),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      onLogin ??
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LoginPage(redirectShopId: shopId),
                        ),
                      ),
                  icon: const Icon(Icons.login),
                  label: const Text('登入／註冊'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '繼續瀏覽店家不需要登入；平台會員條款會在正式登入後確認。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.7),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
