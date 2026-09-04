// lib/features/platform/pages/platform_user_policy_page.dart
// 📜 平台會員條款頁
// 功能：平台會員需閱讀並同意平台使用條款，內容由平台後台管理

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/platform_policy_manage_service.dart';

class PlatformUserPolicyPage extends StatefulWidget {
  const PlatformUserPolicyPage({super.key, required this.onAgree});

  static const String policyKey = 'platform_user_policy';

  final VoidCallback onAgree;

  @override
  State<PlatformUserPolicyPage> createState() => _PlatformUserPolicyPageState();
}

class _PlatformUserPolicyPageState extends State<PlatformUserPolicyPage> {
  bool hasReadToBottom = false;
  bool agreed = false;
  bool loading = true;

  String title = '平台會員條款';
  String content = '';
  int version = 1;

  final controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPolicy();

    controller.addListener(() {
      if (controller.position.pixels >=
          controller.position.maxScrollExtent - 20) {
        if (!hasReadToBottom) {
          setState(() {
            hasReadToBottom = true;
          });
        }
      }
    });
  }

  Future<void> _loadPolicy() async {
    final data = await PlatformPolicyManageService.instance.getPolicy(
      PlatformUserPolicyPage.policyKey,
    );

    if (!mounted) return;

    setState(() {
      title = data?['title']?.toString() ?? '平台會員條款';
      content = data?['content']?.toString() ?? '目前尚未設定平台會員條款。';
      version = data?['version'] is int ? data!['version'] : 1;
      loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;

      if (controller.position.maxScrollExtent <= 0) {
        setState(() {
          hasReadToBottom = true;
        });
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('平台會員條款')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFFFF7ED),
            child: Text(
              '目前版本：v$version，請閱讀至最下方後勾選同意。',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              child: Text(
                content,
                style: const TextStyle(fontSize: 15, height: 1.8),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                CheckboxListTile(
                  value: agreed,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('我已閱讀並同意平台會員條款'),
                  onChanged: hasReadToBottom
                      ? (value) {
                          setState(() {
                            agreed = value ?? false;
                          });
                        }
                      : null,
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: agreed ? widget.onAgree : null,
                    child: const Text('同意並繼續'),
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
