// lib/features/platform/pages/platform_admin_page.dart
// 🛠️ 平台後台主頁
// 功能：平台管理入口，包含店家管理、方案付款、平台操作紀錄

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/platform/pages/platform_member_manage_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_manage_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_policy_manage_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_activation_code_manage_page.dart';

class PlatformAdminPage extends StatelessWidget {
  const PlatformAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('平台後台'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminEntryCard(
            icon: Icons.storefront,
            title: '店家管理',
            subtitle: '管理公開狀態、停權、方案與付款到期日',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PlatformShopManagePage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

_AdminEntryCard(
  icon: Icons.people_alt_outlined,
  title: '平台會員管理',
  subtitle: '管理平台會員、封鎖狀態與平台備註',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlatformMemberManagePage(),
      ),
    );
  },
),
          const SizedBox(height: 12),
          _AdminEntryCard(
            icon: Icons.payments,
            title: '方案 / 付款管理',
            subtitle: '之後管理月費方案、付款期限與功能開關',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),

const SizedBox(height: 12),

_AdminEntryCard(
  icon: Icons.key_outlined,
  title: '激活碼管理',
  subtitle: '建立創店激活碼、查看使用次數與啟用狀態',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const PlatformActivationCodeManagePage(),
      ),
    );
  },
),

_AdminEntryCard(
  icon: Icons.article_outlined,
  title: '平台條款管理',
  subtitle: '管理平台會員條款與創店主條款版本',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlatformPolicyManagePage(),
      ),
    );
  },
),
          _AdminEntryCard(
            icon: Icons.history,
            title: '平台操作紀錄',
            subtitle: '之後查看誰修改店家、方案、停權狀態',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _AdminEntryCard extends StatelessWidget {
  const _AdminEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF3FF),
          child: Icon(icon, color: const Color(0xFF1565C0)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}