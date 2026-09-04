// lib/features/platform/pages/platform_policy_manage_page.dart
// 📜 平台條款管理頁
// 功能：平台後台管理「平台會員條款」與「創店主條款」

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/platform/pages/platform_policy_editor_page.dart';

class PlatformPolicyManagePage extends StatelessWidget {
  const PlatformPolicyManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final policyRef = FirebaseFirestore.instance.collection(
      'platform_policies',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('平台條款管理')),
      body: StreamBuilder<QuerySnapshot>(
        stream: policyRef.snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          Map<String, dynamic> policyData(String key) {
            for (final doc in docs) {
              if (doc.id == key) {
                return doc.data() as Map<String, dynamic>;
              }
            }
            return {};
          }

          final userPolicy = policyData('platform_user_policy');
          final ownerPolicy = policyData('shop_owner_policy');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PolicyManageCard(
                icon: Icons.person_outline,
                title: '平台會員條款',
                subtitle: '一般會員登入後需同意的平台使用條款',
                versionText: '目前版本：v${userPolicy['version'] ?? 1}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PlatformPolicyEditorPage(
                        titleText: '平台會員條款',
                        policyKey: 'platform_user_policy',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _PolicyManageCard(
                icon: Icons.storefront_outlined,
                title: '創店主條款',
                subtitle: '店家建立店家前需同意的平台創店條款',
                versionText: '目前版本：v${ownerPolicy['version'] ?? 1}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PlatformPolicyEditorPage(
                        titleText: '創店主條款',
                        policyKey: 'shop_owner_policy',
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PolicyManageCard extends StatelessWidget {
  const _PolicyManageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.versionText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String versionText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF3FF),
                child: Icon(icon, color: const Color(0xFF1565C0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      versionText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
